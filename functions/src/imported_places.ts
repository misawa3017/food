import {createHash} from "node:crypto";

import {FieldValue, GeoPoint, getFirestore} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {initializeFirebaseAdmin} from "./firebase_admin";

initializeFirebaseAdmin();

const db = getFirestore();
const geoapifyApiKey = defineSecret("GEOAPIFY_API_KEY");
const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";
const callableOptions = {
  region: "asia-east1",
  enforceAppCheck,
  consumeAppCheckToken: enforceAppCheck,
  timeoutSeconds: 120,
  secrets: [geoapifyApiKey],
};
const attribution = "Powered by Geoapify © OpenStreetMap contributors";

interface SourcePlaceData {
  title?: unknown;
  note?: unknown;
  googleMapsUrl?: unknown;
}

interface PreviewImportedPlacesData {
  places?: unknown;
}

interface SaveImportedPlacesData {
  places?: unknown;
}

interface RemoveImportedPlaceData {
  placeId?: unknown;
}

interface SourcePlace {
  title: string;
  note: string | null;
  googleMapsUrl: string | null;
}

interface Candidate {
  placeId: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  confidence: number | null;
  isRecommended: boolean;
}

export const previewImportedPlaces = onCall<PreviewImportedPlacesData>(
  callableOptions,
  handlePreviewImportedPlaces,
);

export const saveImportedPlaces = onCall<SaveImportedPlacesData>(
  callableOptions,
  handleSaveImportedPlaces,
);

export const clearImportedPlaces = onCall(
  callableOptions,
  handleClearImportedPlaces,
);

export const removeImportedPlace = onCall<RemoveImportedPlaceData>(
  callableOptions,
  handleRemoveImportedPlace,
);

export const importOriginalPlaces = onCall<SaveImportedPlacesData>(
  callableOptions,
  handleImportOriginalPlaces,
);

export async function handlePreviewImportedPlaces(
  request: CallableRequest<PreviewImportedPlacesData>,
) {
  await requireAdmin(request);
  const places = sourcePlaces(request.data.places);
  const apiKey = geoapifyApiKey.value();
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "尚未設定 Geoapify API Key，請完成後端 Secret 設定。",
    );
  }

  const results = await Promise.all(
    places.map(async (place) => {
      const candidates = await searchGeoapify(place.title, apiKey);
      return {
        source: place,
        candidates: candidates.map((candidate) => ({
          ...candidate,
          isRecommended: isLikelyRestaurantMatch(place.title, candidate.name),
        })),
      };
    }),
  );
  return {results, attribution};
}

export async function handleSaveImportedPlaces(
  request: CallableRequest<SaveImportedPlacesData>,
) {
  const uid = await requireAdmin(request);
  if (!Array.isArray(request.data.places) || request.data.places.length < 1 ||
      request.data.places.length > 100) {
    throw new HttpsError("invalid-argument", "每次請選擇 1 到 100 筆店家匯入。");
  }

  const batch = db.batch();
  let savedCount = 0;
  for (const item of request.data.places) {
    const imported = importedPlace(item);
    const documentId = createHash("sha256")
      .update(`${uid}|${imported.candidate.placeId}`)
      .digest("hex");
    batch.set(
      db.collection("users").doc(uid).collection("importedPlaces").doc(documentId),
      {
        sourceTitle: imported.source.title,
        sourceNote: imported.source.note,
        sourceGoogleMapsUrl: imported.source.googleMapsUrl,
        name: imported.candidate.name,
        address: imported.candidate.address,
        geo: new GeoPoint(imported.candidate.latitude, imported.candidate.longitude),
        providerPlaceId: imported.candidate.placeId,
        confidence: imported.candidate.confidence,
        attribution,
        source: "geoapify",
        updatedAt: FieldValue.serverTimestamp(),
        importedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    savedCount += 1;
  }
  await batch.commit();
  return {savedCount};
}

export async function handleClearImportedPlaces(
  request: CallableRequest<unknown>,
) {
  const uid = await requireAdmin(request);
  const importedPlaces = db.collection("users").doc(uid)
    .collection("importedPlaces");
  let deletedCount = 0;

  // Firestore 每個 batch 最多 500 個操作，因此分批處理所有匯入資料。
  while (true) {
    const snapshot = await importedPlaces.limit(400).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    for (const document of snapshot.docs) {
      batch.delete(document.ref);
    }
    await batch.commit();
    deletedCount += snapshot.size;
  }
  return {deletedCount};
}

/** Removes one private imported place owned by the current administrator. */
export async function handleRemoveImportedPlace(
  request: CallableRequest<RemoveImportedPlaceData>,
) {
  const uid = await requireAdmin(request);
  const placeId = typeof request.data.placeId === "string" ?
    request.data.placeId.trim() : "";
  if (!/^[a-f0-9]{64}$/.test(placeId)) {
    throw new HttpsError("invalid-argument", "匯入收藏識別碼不正確。");
  }
  const reference = db.collection("users").doc(uid)
    .collection("importedPlaces").doc(placeId);
  const snapshot = await reference.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "找不到這筆匯入收藏。");
  }
  await reference.delete();
  return {placeId};
}

export async function handleImportOriginalPlaces(
  request: CallableRequest<SaveImportedPlacesData>,
) {
  const uid = await requireAdmin(request);
  if (!Array.isArray(request.data.places) || request.data.places.length < 1 ||
      request.data.places.length > 100) {
    throw new HttpsError("invalid-argument", "每次可匯入 1 到 100 筆收藏。");
  }
  const batch = db.batch();
  for (const rawPlace of request.data.places) {
    const source = sourcePlace(rawPlace);
    const stableSource = source.googleMapsUrl ?? source.title;
    const documentId = createHash("sha256").update(`${uid}|${stableSource}`).digest("hex");
    batch.set(
      db.collection("users").doc(uid).collection("importedPlaces").doc(documentId),
      {
        sourceTitle: source.title,
        sourceNote: source.note,
        sourceGoogleMapsUrl: source.googleMapsUrl,
        name: source.title,
        address: null,
        source: "google-takeout",
        updatedAt: FieldValue.serverTimestamp(),
        importedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }
  await batch.commit();
  return {savedCount: request.data.places.length};
}

async function requireAdmin(request: CallableRequest<unknown>): Promise<string> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入後再使用匯入功能。");
  }
  if (enforceAppCheck && (!request.app || request.app.alreadyConsumed)) {
    throw new HttpsError("permission-denied", "App Check 驗證失敗，請重新開啟 App 後再試。 ");
  }
  const uid = request.auth.uid;
  if (!(await db.collection("admins").doc(uid).get()).exists) {
    throw new HttpsError("permission-denied", "只有管理者可以匯入收藏。");
  }
  return uid;
}

function sourcePlaces(value: unknown): SourcePlace[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20) {
    throw new HttpsError("invalid-argument", "每次比對 1 到 20 筆店家。");
  }
  return value.map(sourcePlace);
}

function sourcePlace(value: unknown): SourcePlace {
  if (!value || typeof value !== "object") {
    throw new HttpsError("invalid-argument", "匯入資料格式不正確。");
  }
  const data = value as SourcePlaceData;
  const title = validString(data.title, "店家名稱", 1, 120);
  const note = optionalString(data.note, 1000);
  const googleMapsUrl = optionalUrl(data.googleMapsUrl);
  return {title, note, googleMapsUrl};
}

function importedPlace(value: unknown): {source: SourcePlace; candidate: Candidate} {
  if (!value || typeof value !== "object") {
    throw new HttpsError("invalid-argument", "選取的店家資料不正確。");
  }
  const data = value as {source?: unknown; candidate?: unknown};
  const source = sourcePlace(data.source);
  if (!data.candidate || typeof data.candidate !== "object") {
    throw new HttpsError("invalid-argument", "請先選擇店家比對結果。");
  }
  const candidateData = data.candidate as Record<string, unknown>;
  const latitude = coordinate(candidateData.latitude, -90, 90);
  const longitude = coordinate(candidateData.longitude, -180, 180);
  const rawPlaceId = typeof candidateData.placeId === "string" ?
    candidateData.placeId.trim() : "";
  // Geoapify place IDs may be considerably longer than an ordinary database ID.
  // Keep the provider value when usable; derive a stable fallback for unexpected
  // empty or oversized values so a valid restaurant match never blocks import.
  const placeId = rawPlaceId.length > 0 && rawPlaceId.length <= 1_500 ?
    rawPlaceId : `geoapify-${createHash("sha256")
      .update(`${source.title}|${latitude.toFixed(6)}|${longitude.toFixed(6)}`)
      .digest("hex")}`;
  const candidate = {
    placeId,
    name: validString(candidateData.name, "店家名稱", 1, 160),
    address: validString(candidateData.address, "地址", 1, 300),
    latitude,
    longitude,
    confidence: optionalNumber(candidateData.confidence),
    isRecommended: false,
  };
  return {source, candidate};
}

async function searchGeoapify(title: string, apiKey: string): Promise<Candidate[]> {
  const url = new URL("https://api.geoapify.com/v1/geocode/search");
  url.searchParams.set("text", `${title}, Taiwan`);
  url.searchParams.set("filter", "countrycode:tw");
  url.searchParams.set("type", "amenity");
  url.searchParams.set("lang", "zh");
  url.searchParams.set("limit", "3");
  url.searchParams.set("apiKey", apiKey);
  let response: Response;
  try {
    response = await fetch(url);
  } catch {
    throw new HttpsError("unavailable", "無法連線到 Geoapify，請稍後再試。");
  }
  if (!response.ok) {
    throw new HttpsError("unavailable", "Geoapify 暫時無法比對店家，請稍後再試。");
  }
  const body = await response.json() as {features?: unknown};
  if (!Array.isArray(body.features)) return [];
  return body.features
    .map(candidateFromFeature)
    .filter((candidate): candidate is Candidate => candidate !== null);
}

function candidateFromFeature(feature: unknown): Candidate | null {
  if (!feature || typeof feature !== "object") return null;
  const data = feature as {properties?: unknown; geometry?: unknown};
  if (!data.properties || typeof data.properties !== "object") return null;
  const properties = data.properties as Record<string, unknown>;
  const coordinates = getCoordinates(data.geometry);
  const longitude = getCoordinate(properties.lon, coordinates, 0);
  const latitude = getCoordinate(properties.lat, coordinates, 1);
  if (typeof latitude !== "number" || typeof longitude !== "number" ||
      !Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (nonEmptyString(properties.result_type) !== "amenity") return null;
  const name = nonEmptyString(properties.name);
  const address = nonEmptyString(properties.formatted) ??
    nonEmptyString(properties.address_line2) ?? name;
  const placeId = nonEmptyString(properties.place_id) ?? null;
  if (!name || !address || !placeId) return null;
  const rank = properties.rank;
  const confidence = getRankConfidence(rank);
  return {
    placeId,
    name,
    address,
    latitude,
    longitude,
    confidence,
    isRecommended: false,
  };
}

function getCoordinates(geometry: unknown): unknown[] | null {
  if (!geometry || typeof geometry !== "object") return null;
  const coordinates = (geometry as {coordinates?: unknown}).coordinates;
  return Array.isArray(coordinates) ? coordinates : null;
}

function getCoordinate(
  value: unknown,
  coordinates: unknown[] | null,
  index: number,
): number | null {
  if (typeof value === "number") return value;
  const coordinate = coordinates?.[index];
  return typeof coordinate === "number" ? coordinate : null;
}

function getRankConfidence(rank: unknown): number | null {
  if (!rank || typeof rank !== "object" || !("confidence" in rank)) {
    return null;
  }
  return optionalNumber((rank as {confidence?: unknown}).confidence);
}

function isLikelyRestaurantMatch(sourceTitle: string, candidateName: string): boolean {
  const source = normalizeName(sourceTitle);
  const candidate = normalizeName(candidateName);
  if (source.length < 2 || candidate.length < 2) return false;
  if (source.includes(candidate) || candidate.includes(source)) return true;

  const sourceCharacters = new Set(source);
  const candidateCharacters = new Set(candidate);
  const matchingCharacters = [...candidateCharacters]
    .filter((character) => sourceCharacters.has(character)).length;
  return matchingCharacters / Math.min(sourceCharacters.size, candidateCharacters.size) >= 0.8;
}

function normalizeName(value: string): string {
  return value.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
}

function validString(value: unknown, label: string, min: number, max: number): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label}格式不正確。`);
  }
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) {
    throw new HttpsError("invalid-argument", `${label}長度不正確。`);
  }
  return normalized;
}

function optionalString(value: unknown, max: number): string | null {
  if (value == null || value === "") return null;
  return validString(value, "備註", 1, max);
}

function optionalUrl(value: unknown): string | null {
  if (value == null || value === "") return null;
  const raw = validString(value, "Google Maps 連結", 1, 2048);
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:") throw new Error("protocol");
    return url.toString();
  } catch {
    throw new HttpsError("invalid-argument", "Google Maps 連結格式不正確。");
  }
}

function coordinate(value: unknown, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", "店家座標格式不正確。");
  }
  return value;
}

function optionalNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function nonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}
