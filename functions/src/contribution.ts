import {createHash, randomUUID} from "node:crypto";

import {
  FieldValue,
  GeoPoint,
  Timestamp,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {CallableRequest, HttpsError, onCall} from "firebase-functions/v2/https";
import {initializeFirebaseAdmin} from "./firebase_admin";

initializeFirebaseAdmin();

const db = getFirestore();
const bucket = getStorage().bucket();
const region = "asia-east1";
const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";
const callableOptions = {
  region,
  enforceAppCheck,
  consumeAppCheckToken: enforceAppCheck,
};
const dayMilliseconds = 24 * 60 * 60 * 1000;
const reservationMilliseconds = 15 * 60 * 1000;
const defaultRestaurantDailyLimit = 3;
const maximumRestaurantDailyLimit = 100;
const defaultPhotoDailyLimit = 20;
const maximumPhotoDailyLimit = 100;
const contributionLimitsReference = db
  .collection("systemSettings")
  .doc("contributionLimits");
const categoryValues = new Set([
  "小吃",
  "日式",
  "韓式",
  "中式",
  "西式",
  "東南亞料理",
  "火鍋",
  "燒烤",
  "甜點",
  "飲料",
]);

const amenityValues = new Set([
  "停車場",
  "可刷卡",
  "行動支付",
  "Wi-Fi",
  "可訂位",
  "外帶",
  "外送",
  "親子友善",
  "無障礙設施",
  "寵物友善",
]);

interface CreateRestaurantData {
  name?: unknown;
  address?: unknown;
  googleMapsUrl?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  categories?: unknown;
  recommendedDishes?: unknown;
  amenities?: unknown;
  duplicateAcknowledged?: unknown;
  idempotencyKey?: unknown;
}

interface UpdatePublicProfileData {
  recommenderName?: unknown;
}

interface RequestPhotoUploadData {
  restaurantId?: unknown;
  count?: unknown;
  idempotencyKey?: unknown;
}

interface FinalizePhotoUploadData {
  reservationId?: unknown;
}

interface SetRestaurantCoverPhotoData {
  restaurantId?: unknown;
  photoId?: unknown;
}

interface RemoveRestaurantPhotoData {
  restaurantId?: unknown;
  photoId?: unknown;
}

interface SubmitDuplicateData {
  sourceRestaurantId?: unknown;
  targetRestaurantId?: unknown;
  reason?: unknown;
  idempotencyKey?: unknown;
}

interface MergeRestaurantsData {
  requestId?: unknown;
}

interface SubmitReviewData {
  restaurantId?: unknown;
  rating?: unknown;
  text?: unknown;
  idempotencyKey?: unknown;
}

interface DeleteReviewData {
  restaurantId?: unknown;
  idempotencyKey?: unknown;
}

interface SubmitEditRequestData {
  restaurantId?: unknown;
  changes?: unknown;
  reason?: unknown;
  idempotencyKey?: unknown;
}

interface SubmitReportData {
  targetType?: unknown;
  restaurantId?: unknown;
  contentId?: unknown;
  reason?: unknown;
  idempotencyKey?: unknown;
}

interface ReviewRequestData {
  requestId?: unknown;
  decision?: unknown;
}

interface UpdateRestaurantContributionLimitData {
  restaurantDailyLimit?: unknown;
  photoDailyLimit?: unknown;
}

interface AdminUpdateRestaurantData {
  restaurantId?: unknown;
  changes?: unknown;
}

interface AdminRemoveRestaurantData {
  restaurantId?: unknown;
}

export const createRestaurant = onCall<CreateRestaurantData>(
  callableOptions,
  handleCreateRestaurant,
);

export const getPublicProfile = onCall(callableOptions, handleGetPublicProfile);

export const updatePublicProfile = onCall<UpdatePublicProfileData>(
  callableOptions,
  handleUpdatePublicProfile,
);

export const requestPhotoUpload = onCall<RequestPhotoUploadData>(
  callableOptions,
  handleRequestPhotoUpload,
);

export const finalizePhotoUpload = onCall<FinalizePhotoUploadData>(
  callableOptions,
  handleFinalizePhotoUpload,
);

export const setRestaurantCoverPhoto = onCall<SetRestaurantCoverPhotoData>(
  callableOptions,
  handleSetRestaurantCoverPhoto,
);

export const removeRestaurantPhoto = onCall<RemoveRestaurantPhotoData>(
  callableOptions,
  handleRemoveRestaurantPhoto,
);

export const submitDuplicateRestaurant = onCall<SubmitDuplicateData>(
  callableOptions,
  handleSubmitDuplicateRestaurant,
);

export const mergeRestaurants = onCall<MergeRestaurantsData>(
  callableOptions,
  handleMergeRestaurants,
);

export const submitReview = onCall<SubmitReviewData>(
  callableOptions,
  handleSubmitReview,
);

export const deleteReview = onCall<DeleteReviewData>(
  callableOptions,
  handleDeleteReview,
);

export const submitRestaurantEdit = onCall<SubmitEditRequestData>(
  callableOptions,
  handleSubmitRestaurantEdit,
);

export const submitReport = onCall<SubmitReportData>(
  callableOptions,
  handleSubmitReport,
);

export const reviewRestaurantEdit = onCall<ReviewRequestData>(
  callableOptions,
  handleReviewRestaurantEdit,
);

export const reviewReport = onCall<ReviewRequestData>(
  callableOptions,
  handleReviewReport,
);

export const getRestaurantContributionLimit = onCall<Record<string, never>>(
  callableOptions,
  handleGetRestaurantContributionLimit,
);

export const updateRestaurantContributionLimit =
  onCall<UpdateRestaurantContributionLimitData>(
    callableOptions,
    handleUpdateRestaurantContributionLimit,
  );

export const adminUpdateRestaurant = onCall<AdminUpdateRestaurantData>(
  callableOptions,
  handleAdminUpdateRestaurant,
);

export const adminRemoveRestaurant = onCall<AdminRemoveRestaurantData>(
  callableOptions,
  handleAdminRemoveRestaurant,
);

export async function handleCreateRestaurant(
  request: CallableRequest<CreateRestaurantData>,
) {
  const uid = validateCallable(request);
  const recommenderName = await getRecommenderName(uid);
  const name = requiredString(request.data.name, "店家名稱", 2, 80);
  const address = requiredString(request.data.address, "地址", 3, 200);
  const googleMapsUrl = optionalHttpsUrl(request.data.googleMapsUrl);
  const coordinates = optionalCoordinates(
    request.data.latitude,
    request.data.longitude,
  );
  const categories = validCategories(request.data.categories);
  const recommendedDishes = stringList(
    request.data.recommendedDishes,
    "推薦菜色",
    10,
    40,
  );
  const amenities = validAmenities(request.data.amenities);
  const idempotencyKey = validIdempotencyKey(request.data.idempotencyKey);
  const nameNormalized = normalizeName(name);
  const candidates = await findDuplicateCandidates(
    nameNormalized,
    address,
    coordinates,
  );
  if (candidates.length > 0 && request.data.duplicateAcknowledged !== true) {
    throw new HttpsError(
      "failed-precondition",
      "附近可能已有相同店家，請先確認。",
      {reason: "duplicate-candidates", candidates},
    );
  }

  const operationReference = idempotencyReference(uid, idempotencyKey);
  const result = await db.runTransaction(async (transaction) => {
    const [previous, limitSettings] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(contributionLimitsReference),
    ]);
    if (previous.exists) {
      return {restaurantId: previous.get("restaurantId") as string};
    }
    await consumeContribution(
      transaction,
      uid,
      "restaurants",
      1,
      restaurantDailyLimitFromSettings(limitSettings.get("restaurantDailyLimit")),
    );
    const restaurantReference = db.collection("restaurants").doc();
    transaction.create(restaurantReference, {
      name,
      nameLower: name.toLowerCase(),
      nameNormalized,
      address,
      googleMapsUrl,
      ...(coordinates == null
        ? {}
        : {
            geo: new GeoPoint(coordinates.latitude, coordinates.longitude),
            geohash: encodeGeohash(coordinates.latitude, coordinates.longitude),
          }),
      categories,
      recommendedDishes,
      amenities,
      coverPhotoUrl: null,
      photoCount: 0,
      ratingSum: 0,
      ratingCount: 0,
      reportCount: 0,
      favoriteCount: 0,
      status: "active",
      createdBy: uid,
      recommenderName,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "createRestaurant",
      restaurantId: restaurantReference.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {restaurantId: restaurantReference.id};
  });
  return result;
}

/** Returns the caller's optional public nickname without exposing account data. */
export async function handleGetPublicProfile(request: CallableRequest<unknown>) {
  const uid = validateCallable(request);
  const recommenderName = await getRecommenderName(uid);
  return {
    recommenderName: recommenderName === anonymousRecommenderName
      ? null
      : recommenderName,
  };
}

/** Saves the nickname shown beside restaurants created by the caller in future. */
export async function handleUpdatePublicProfile(
  request: CallableRequest<UpdatePublicProfileData>,
) {
  const uid = validateCallable(request);
  const recommenderName = optionalRecommenderName(request.data.recommenderName);
  await db.collection("users").doc(uid).set(
    {
      publicRecommenderName: recommenderName ?? FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  return {recommenderName};
}

function optionalHttpsUrl(value: unknown): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string" || value.length > 2048) {
    throw new HttpsError("invalid-argument", "Google Maps 連結格式不正確。");
  }
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") throw new Error("protocol");
    return url.toString();
  } catch {
    throw new HttpsError("invalid-argument", "Google Maps 連結格式不正確。");
  }
}

const anonymousRecommenderName = "匿名美食家";

async function getRecommenderName(uid: string): Promise<string> {
  const snapshot = await db.collection("users").doc(uid).get();
  const value = snapshot.get("publicRecommenderName");
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : anonymousRecommenderName;
}

function optionalRecommenderName(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "公開暱稱格式不正確。");
  }
  const name = value.trim();
  if (name.length === 0) return null;
  if (name.length < 2 || name.length > 24) {
    throw new HttpsError("invalid-argument", "公開暱稱需為 2 到 24 個字元。");
  }
  return name;
}

export async function handleRequestPhotoUpload(
  request: CallableRequest<RequestPhotoUploadData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const count = finiteInteger(request.data.count, "照片數量", 1, 5);
  const idempotencyKey = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, idempotencyKey);

  return db.runTransaction(async (transaction) => {
    const previous = await transaction.get(operationReference);
    if (previous.exists) {
      return {reservations: previous.get("reservations")};
    }
    const restaurantReference = db.collection("restaurants").doc(restaurantId);
    const restaurant = await transaction.get(restaurantReference);
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可上傳照片的店家。");
    }
    const photoCount = numericValue(restaurant.get("photoCount"));
    if (photoCount + count > 30) {
      throw new HttpsError("resource-exhausted", "每家店最多只能有 30 張照片。");
    }
    const expiresAt = Timestamp.fromMillis(Date.now() + reservationMilliseconds);
    const reservations = Array.from({length: count}, () => {
      const reservationReference = db
        .collection("uploadReservations")
        .doc(`${randomUUID()}.jpg`);
      const storagePath =
        `restaurant_photos/${restaurantId}/${reservationReference.id}`;
      transaction.create(reservationReference, {
        uid,
        restaurantId,
        storagePath,
        status: "pending",
        expiresAt,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {
        reservationId: reservationReference.id,
        storagePath,
      };
    });
    transaction.create(operationReference, {
      uid,
      type: "requestPhotoUpload",
      reservations,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {reservations};
  });
}

export async function handleFinalizePhotoUpload(
  request: CallableRequest<FinalizePhotoUploadData>,
) {
  const uid = validateCallable(request);
  const reservationId = documentId(request.data.reservationId, "上傳預約");
  const reservationReference = db
    .collection("uploadReservations")
    .doc(reservationId);
  const reservation = await reservationReference.get();
  if (!reservation.exists || reservation.get("uid") !== uid) {
    throw new HttpsError("not-found", "找不到照片上傳預約。");
  }
  if (reservation.get("status") === "consumed") {
    return {
      photoId: reservation.get("photoId"),
      url: reservation.get("url"),
    };
  }
  const storagePath = reservation.get("storagePath");
  if (typeof storagePath !== "string") {
    throw new HttpsError("failed-precondition", "照片上傳路徑無效。");
  }
  const file = bucket.file(storagePath);
  const [exists] = await file.exists();
  if (!exists) {
    throw new HttpsError("failed-precondition", "請先完成照片上傳。");
  }
  const [metadata] = await file.getMetadata();
  if (metadata.contentType !== "image/jpeg" || Number(metadata.size) > 5_000_000) {
    throw new HttpsError("invalid-argument", "照片格式或大小不符合限制。");
  }
  const downloadToken = randomUUID();
  await file.setMetadata({metadata: {firebaseStorageDownloadTokens: downloadToken}});
  const url = storageDownloadUrl(storagePath, downloadToken);

  return db.runTransaction(async (transaction) => {
    const currentReservation = await transaction.get(reservationReference);
    if (currentReservation.get("status") === "consumed") {
      return {
        photoId: currentReservation.get("photoId") as string,
        url: currentReservation.get("url") as string,
      };
    }
    const expiresAt = currentReservation.get("expiresAt");
    if (!(expiresAt instanceof Timestamp) || expiresAt.toMillis() < Date.now()) {
      throw new HttpsError("deadline-exceeded", "照片上傳預約已過期。");
    }
    const restaurantId = currentReservation.get("restaurantId") as string;
    const restaurantReference = db.collection("restaurants").doc(restaurantId);
    const restaurant = await transaction.get(restaurantReference);
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "店家已不存在。");
    }
    if (numericValue(restaurant.get("photoCount")) >= 30) {
      throw new HttpsError("resource-exhausted", "每家店最多只能有 30 張照片。");
    }
    const limitSettings = await transaction.get(contributionLimitsReference);
    await consumeContribution(
      transaction,
      uid,
      "photos",
      1,
      photoDailyLimitFromSettings(limitSettings.get("photoDailyLimit")),
    );
    const photoReference = restaurantReference.collection("photos").doc();
    transaction.create(photoReference, {
      url,
      storagePath,
      uploadedBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      status: "active",
      reportCount: 0,
    });
    const restaurantUpdate: Record<string, unknown> = {
      photoCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!restaurant.get("coverPhotoUrl")) {
      restaurantUpdate.coverPhotoUrl = url;
    }
    transaction.update(restaurantReference, restaurantUpdate);
    transaction.update(reservationReference, {
      status: "consumed",
      photoId: photoReference.id,
      url,
      consumedAt: FieldValue.serverTimestamp(),
    });
    return {photoId: photoReference.id, url};
  });
}

/** Allows a photo owner or an administrator to choose the restaurant cover. */
export async function handleSetRestaurantCoverPhoto(
  request: CallableRequest<SetRestaurantCoverPhotoData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const photoId = documentId(request.data.photoId, "照片");
  const isAdmin = (await db.collection("admins").doc(uid).get()).exists;
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  const photoReference = restaurantReference.collection("photos").doc(photoId);

  return db.runTransaction(async (transaction) => {
    const [restaurant, photo] = await Promise.all([
      transaction.get(restaurantReference),
      transaction.get(photoReference),
    ]);
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可設定封面的店家。");
    }
    if (!photo.exists || photo.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可設定為封面的照片。");
    }
    const url = photo.get("url");
    if (typeof url !== "string" || url.length === 0) {
      throw new HttpsError("failed-precondition", "照片資料不完整，無法設為封面。");
    }
    if (!isAdmin && photo.get("uploadedBy") !== uid) {
      throw new HttpsError("permission-denied", "只能將自己上傳的照片設為封面。");
    }
    transaction.update(restaurantReference, {
      coverPhotoUrl: url,
      coverPhotoUpdatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {restaurantId, photoId};
  });
}

/** Allows a photo owner or an administrator to permanently remove a photo. */
export async function handleRemoveRestaurantPhoto(
  request: CallableRequest<RemoveRestaurantPhotoData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const photoId = documentId(request.data.photoId, "照片");
  const isAdmin = (await db.collection("admins").doc(uid).get()).exists;
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  const photoReference = restaurantReference.collection("photos").doc(photoId);
  const activePhotosQuery = restaurantReference
    .collection("photos")
    .where("status", "==", "active")
    .orderBy("createdAt", "desc")
    .limit(30);
  let storagePath: string | null = null;

  const result = await db.runTransaction(async (transaction) => {
    const [restaurant, photo, activePhotos] = await Promise.all([
      transaction.get(restaurantReference),
      transaction.get(photoReference),
      transaction.get(activePhotosQuery),
    ]);
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可刪除照片的店家。");
    }
    if (!photo.exists) {
      throw new HttpsError("not-found", "找不到要刪除的照片。");
    }
    if (!isAdmin && photo.get("uploadedBy") !== uid) {
      throw new HttpsError("permission-denied", "只能刪除自己上傳的照片。");
    }
    if (photo.get("status") === "removed") {
      return {restaurantId, photoId, status: "removed"};
    }
    if (photo.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "這張照片目前無法刪除。");
    }

    const url = photo.get("url");
    const photoStoragePath = photo.get("storagePath");
    storagePath = isRestaurantPhotoPath(photoStoragePath, restaurantId)
      ? photoStoragePath
      : null;
    const isCover = typeof url === "string" &&
      restaurant.get("coverPhotoUrl") === url;
    const restaurantUpdate: Record<string, unknown> = {
      photoCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (isCover) {
      const replacementUrl = activePhotos.docs
        .filter((candidate) => candidate.id !== photoId)
        .map((candidate) => candidate.get("url"))
        .find((candidate): candidate is string => typeof candidate === "string" && candidate.length > 0);
      // 優先改用其餘照片，避免保留已刪除的封面網址。
      restaurantUpdate.coverPhotoUrl = replacementUrl ?? FieldValue.delete();
      restaurantUpdate.coverPhotoUpdatedBy = uid;
    }
    transaction.update(photoReference, {
      status: "removed",
      url: FieldValue.delete(),
      storagePath: FieldValue.delete(),
      removedBy: uid,
      removedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(restaurantReference, restaurantUpdate);
    return {restaurantId, photoId, status: "removed"};
  });

  if (storagePath !== null) {
    await bucket.file(storagePath).delete({ignoreNotFound: true});
  }
  return result;
}

export async function handleSubmitDuplicateRestaurant(
  request: CallableRequest<SubmitDuplicateData>,
) {
  const uid = validateCallable(request);
  const sourceRestaurantId = documentId(
    request.data.sourceRestaurantId,
    "來源店家",
  );
  const targetRestaurantId = documentId(
    request.data.targetRestaurantId,
    "保留店家",
  );
  if (sourceRestaurantId === targetRestaurantId) {
    throw new HttpsError("invalid-argument", "來源與保留店家不能相同。");
  }
  const reason = requiredString(request.data.reason, "原因", 5, 500);
  const idempotencyKey = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, idempotencyKey);
  const pair = [sourceRestaurantId, targetRestaurantId]
    .sort((first, second) => first.localeCompare(second))
    .join(":");
  const requestReference = db
    .collection("restaurantMergeRequests")
    .doc(createHash("sha256").update(pair).digest("hex"));

  return db.runTransaction(async (transaction) => {
    const [operation, existing, source, target] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(requestReference),
      transaction.get(db.collection("restaurants").doc(sourceRestaurantId)),
      transaction.get(db.collection("restaurants").doc(targetRestaurantId)),
    ]);
    if (operation.exists) {
      return {requestId: operation.get("requestId")};
    }
    if (existing.exists && existing.get("status") === "pending") {
      throw new HttpsError("already-exists", "這兩家店已有待處理的重複申請。");
    }
    if (
      !source.exists ||
      !target.exists ||
      source.get("status") !== "active" ||
      target.get("status") !== "active"
    ) {
      throw new HttpsError("not-found", "找不到可合併的店家。");
    }
    await consumeContribution(transaction, uid, "duplicates", 1, 10);
    transaction.set(requestReference, {
      sourceRestaurantId,
      targetRestaurantId,
      reason,
      status: "pending",
      submittedBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "submitDuplicateRestaurant",
      requestId: requestReference.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {requestId: requestReference.id};
  });
}

export async function handleMergeRestaurants(
  request: CallableRequest<MergeRestaurantsData>,
) {
  const uid = validateCallable(request);
  const requestId = documentId(request.data.requestId, "合併申請");
  if (!(await db.collection("admins").doc(uid).get()).exists) {
    throw new HttpsError("permission-denied", "只有管理員可以合併店家。");
  }
  const mergeReference = db.collection("restaurantMergeRequests").doc(requestId);
  const mergeRequest = await mergeReference.get();
  if (!mergeRequest.exists) {
    throw new HttpsError("not-found", "合併申請不存在。");
  }
  if (mergeRequest.get("status") === "approved") {
    return {
      sourceRestaurantId: mergeRequest.get("sourceRestaurantId"),
      targetRestaurantId: mergeRequest.get("targetRestaurantId"),
    };
  }
  const sourceId = mergeRequest.get("sourceRestaurantId") as string;
  const targetId = mergeRequest.get("targetRestaurantId") as string;
  if (mergeRequest.get("status") === "pending") {
    await db.runTransaction(async (transaction) => {
    const mergeRequest = await transaction.get(mergeReference);
    if (!mergeRequest.exists || mergeRequest.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "合併申請已處理或不存在。");
    }
    const sourceReference = db.collection("restaurants").doc(sourceId);
    const targetReference = db.collection("restaurants").doc(targetId);
    const [source, target] = await Promise.all([
      transaction.get(sourceReference),
      transaction.get(targetReference),
    ]);
    if (
      !source.exists ||
      !target.exists ||
      source.get("status") !== "active" ||
      target.get("status") !== "active"
    ) {
      throw new HttpsError("failed-precondition", "店家狀態已改變，無法合併。");
    }
    const dishes = new Set<string>([
      ...stringValues(target.get("recommendedDishes")),
      ...stringValues(source.get("recommendedDishes")),
    ]);
    transaction.update(targetReference, {
      recommendedDishes: [...dishes].slice(0, 20),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(sourceReference, {
      status: "merged",
      mergedIntoRestaurantId: targetId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(mergeReference, {
      status: "processing",
      reviewedBy: uid,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    });
  }

  await moveMergedPhotos(sourceId, targetId);
  await moveMergedReviews(sourceId, targetId);
  await mergeReference.update({
    status: "approved",
    completedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {sourceRestaurantId: sourceId, targetRestaurantId: targetId};
}

export async function handleSubmitReview(
  request: CallableRequest<SubmitReviewData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const rating = finiteInteger(request.data.rating, "評分", 1, 5);
  const text = typeof request.data.text === "string"
    ? request.data.text.trim().slice(0, 1000)
    : "";
  const key = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, key);
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  const reviewReference = restaurantReference.collection("reviews").doc(uid);
  return db.runTransaction(async (transaction) => {
    const [operation, restaurant, previousReview] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(restaurantReference),
      transaction.get(reviewReference),
    ]);
    if (operation.exists) {
      return {status: "completed"};
    }
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可評論的店家。");
    }
    await consumeContribution(transaction, uid, "reviews", 1, 10);
    const previousActive = previousReview.get("status") === "active";
    const previousRating = previousActive
      ? numericValue(previousReview.get("rating"))
      : 0;
    const token = (request.auth?.token ?? {}) as Record<string, unknown>;
    transaction.set(reviewReference, {
      rating,
      text,
      authorUid: uid,
      authorName: typeof token.name === "string" ? token.name : "美食通使用者",
      authorPhotoUrl: typeof token.picture === "string" ? token.picture : null,
      status: "active",
      reportCount: previousReview.get("reportCount") ?? 0,
      createdAt: previousReview.get("createdAt") ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(restaurantReference, {
      ratingSum: FieldValue.increment(rating - previousRating),
      ratingCount: FieldValue.increment(previousActive ? 0 : 1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "submitReview",
      restaurantId,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {status: "completed"};
  });
}

export async function handleDeleteReview(
  request: CallableRequest<DeleteReviewData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const key = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, key);
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  const reviewReference = restaurantReference.collection("reviews").doc(uid);
  return db.runTransaction(async (transaction) => {
    const [operation, restaurant, review] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(restaurantReference),
      transaction.get(reviewReference),
    ]);
    if (operation.exists) {
      return {status: "completed"};
    }
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可操作的店家。");
    }
    if (!review.exists || review.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "評論已刪除或不存在。");
    }
    await consumeContribution(transaction, uid, "reviews", 1, 10);
    transaction.update(reviewReference, {
      status: "removed",
      removedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(restaurantReference, {
      ratingSum: FieldValue.increment(-numericValue(review.get("rating"))),
      ratingCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "deleteReview",
      restaurantId,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {status: "completed"};
  });
}

export async function handleSubmitRestaurantEdit(
  request: CallableRequest<SubmitEditRequestData>,
) {
  const uid = validateCallable(request);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const reason = requiredString(request.data.reason, "修正原因", 5, 500);
  const changes = validEditChanges(request.data.changes);
  const key = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, key);
  return db.runTransaction(async (transaction) => {
    const [operation, restaurant] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(db.collection("restaurants").doc(restaurantId)),
    ]);
    if (operation.exists) {
      return {requestId: operation.get("requestId")};
    }
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可修正的店家。");
    }
    await consumeContribution(transaction, uid, "moderation", 1, 10);
    const editReference = db.collection("restaurantEditRequests").doc();
    transaction.create(editReference, {
      restaurantId,
      changes,
      reason,
      status: "pending",
      submittedBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "submitRestaurantEdit",
      requestId: editReference.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {requestId: editReference.id};
  });
}

export async function handleSubmitReport(
  request: CallableRequest<SubmitReportData>,
) {
  const uid = validateCallable(request);
  const targetType = request.data.targetType;
  if (!["restaurant", "photo", "review"].includes(String(targetType))) {
    throw new HttpsError("invalid-argument", "檢舉目標不正確。");
  }
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const contentId = targetType === "restaurant"
    ? null
    : documentId(request.data.contentId, "內容");
  const reason = requiredString(request.data.reason, "檢舉原因", 5, 500);
  const key = validIdempotencyKey(request.data.idempotencyKey);
  const operationReference = idempotencyReference(uid, key);
  const pendingId = createHash("sha256")
    .update(`${uid}:${targetType}:${restaurantId}:${contentId ?? ""}`)
    .digest("hex");
  const reportReference = db.collection("reports").doc(pendingId);
  return db.runTransaction(async (transaction) => {
    const [operation, existing] = await Promise.all([
      transaction.get(operationReference),
      transaction.get(reportReference),
    ]);
    if (operation.exists) {
      return {reportId: operation.get("reportId")};
    }
    if (existing.exists && existing.get("status") === "pending") {
      throw new HttpsError("already-exists", "這個內容已有待處理檢舉。");
    }
    await consumeContribution(transaction, uid, "reports", 1, 10);
    transaction.set(reportReference, {
      targetType,
      restaurantId,
      contentId,
      reason,
      status: "pending",
      reportedBy: uid,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.create(operationReference, {
      uid,
      type: "submitReport",
      reportId: reportReference.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {reportId: reportReference.id};
  });
}

export async function handleReviewRestaurantEdit(
  request: CallableRequest<ReviewRequestData>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const requestId = documentId(request.data.requestId, "修正申請");
  const decision = decisionValue(request.data.decision);
  const editReference = db.collection("restaurantEditRequests").doc(requestId);
  return db.runTransaction(async (transaction) => {
    const edit = await transaction.get(editReference);
    if (!edit.exists || edit.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "修正申請已處理或不存在。");
    }
    if (decision === "approved") {
      const restaurantReference = db
        .collection("restaurants")
        .doc(edit.get("restaurantId"));
      const restaurant = await transaction.get(restaurantReference);
      const changes = edit.get("changes") as Record<string, unknown>;
      transaction.update(restaurantReference, {
        ...changes,
        auditBefore: restaurant.data(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    transaction.update(editReference, {
      status: decision,
      reviewedBy: uid,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {status: decision};
  });
}

export async function handleReviewReport(
  request: CallableRequest<ReviewRequestData>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const requestId = documentId(request.data.requestId, "檢舉");
  const decision = decisionValue(request.data.decision);
  const reportReference = db.collection("reports").doc(requestId);
  return db.runTransaction(async (transaction) => {
    const report = await transaction.get(reportReference);
    if (!report.exists || report.get("status") !== "pending") {
      throw new HttpsError("failed-precondition", "檢舉已處理或不存在。");
    }
    if (decision === "approved") {
      await removeReportedContent(transaction, report.data()!);
    }
    transaction.update(reportReference, {
      status: decision,
      reviewedBy: uid,
      reviewedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {status: decision};
  });
}

async function moveMergedPhotos(sourceId: string, targetId: string) {
  const sourceReference = db.collection("restaurants").doc(sourceId);
  const targetReference = db.collection("restaurants").doc(targetId);
  const [sourcePhotos, target] = await Promise.all([
    sourceReference.collection("photos").get(),
    targetReference.get(),
  ]);
  const available = Math.max(0, 30 - numericValue(target.get("photoCount")));
  const activePhotos = sourcePhotos.docs
    .filter((photo) => photo.get("status") === "active")
    .slice(0, available);
  const writer = db.bulkWriter();
  for (const photo of activePhotos) {
    writer.set(
      targetReference.collection("photos").doc(`merged_${sourceId}_${photo.id}`),
      photo.data(),
    );
    writer.delete(photo.ref);
  }
  await writer.close();
  if (activePhotos.length > 0) {
    const update: Record<string, unknown> = {
      photoCount: FieldValue.increment(activePhotos.length),
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!target.get("coverPhotoUrl")) {
      update.coverPhotoUrl = activePhotos[0].get("url") ?? null;
    }
    await targetReference.update(update);
  }
  await sourceReference.update({photoCount: 0});
}

async function moveMergedReviews(sourceId: string, targetId: string) {
  const sourceReference = db.collection("restaurants").doc(sourceId);
  const targetReference = db.collection("restaurants").doc(targetId);
  const sourceReviews = await sourceReference.collection("reviews").get();
  for (const sourceReview of sourceReviews.docs) {
    const targetReviewReference = targetReference
      .collection("reviews")
      .doc(sourceReview.id);
    const targetReview = await targetReviewReference.get();
    const sourceTime = timestampMillis(
      sourceReview.get("updatedAt") ?? sourceReview.get("createdAt"),
    );
    const targetTime = timestampMillis(
      targetReview.get("updatedAt") ?? targetReview.get("createdAt"),
    );
    if (!targetReview.exists || sourceTime > targetTime) {
      await targetReviewReference.set(sourceReview.data());
    }
    await sourceReview.ref.delete();
  }
  const targetReviews = await targetReference
    .collection("reviews")
    .where("status", "==", "active")
    .get();
  const ratings = targetReviews.docs
    .map((review) => review.get("rating"))
    .filter((rating): rating is number => Number.isInteger(rating));
  await targetReference.update({
    ratingSum: ratings.reduce((sum, rating) => sum + rating, 0),
    ratingCount: ratings.length,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await sourceReference.update({ratingSum: 0, ratingCount: 0});
}

function validateCallable(request: CallableRequest<unknown>): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "請先登入後再投稿。");
  }
  if (enforceAppCheck && (!request.app || request.app.alreadyConsumed)) {
    throw new HttpsError("permission-denied", "App Check 驗證失敗。");
  }
  return request.auth.uid;
}

async function consumeContribution(
  transaction: Transaction,
  uid: string,
  type:
    | "restaurants"
    | "photos"
    | "duplicates"
    | "reviews"
    | "moderation"
    | "reports",
  amount: number,
  maximum: number,
): Promise<void> {
  const userReference = db.collection("users").doc(uid);
  const usageReference = db.collection("contributionUsage").doc(uid);
  const [user, usage] = await Promise.all([
    transaction.get(userReference),
    transaction.get(usageReference),
  ]);
  const blockedUntil = user.get("blockedUntil");
  if (blockedUntil instanceof Timestamp && blockedUntil.toMillis() > Date.now()) {
    throw new HttpsError("permission-denied", "此帳號目前暫停投稿。");
  }
  const currentWindow = usage.get("windowStartedAt");
  const reset =
    !(currentWindow instanceof Timestamp) ||
    currentWindow.toMillis() + dayMilliseconds <= Date.now();
  const counts = reset ? {} : (usage.get("counts") ?? {});
  const current = numericValue(counts[type]);
  if (current + amount > maximum) {
    const retryAfter = reset
      ? dayMilliseconds
      : currentWindow.toMillis() + dayMilliseconds - Date.now();
    let limitMessage: string;
    if (type === "restaurants") {
      limitMessage = "已達 24 小時店家投稿上限。";
    } else if (type === "photos") {
      limitMessage = "已達 24 小時照片投稿上限。";
    } else {
      limitMessage = "已達 24 小時投稿上限。";
    }
    throw new HttpsError(
      "resource-exhausted",
      limitMessage,
      {retryAfter: Math.max(1, Math.ceil(retryAfter / 1000))},
    );
  }
  transaction.set(
    usageReference,
    {
      windowStartedAt: reset ? FieldValue.serverTimestamp() : currentWindow,
      counts: {...counts, [type]: current + amount},
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function findDuplicateCandidates(
  nameNormalized: string,
  address: string,
  coordinates: {latitude: number; longitude: number} | null,
) {
  const snapshot = await db
    .collection("restaurants")
    .where("status", "==", "active")
    .where("nameNormalized", "==", nameNormalized)
    .limit(10)
    .get();
  return snapshot.docs
    .map((document) => {
      const geo = document.get("geo");
      const sameAddress = normalizeName(document.get("address") ?? "") ===
        normalizeName(address);
      const distanceMeters = coordinates != null && geo instanceof GeoPoint
        ? haversineMeters(
            coordinates.latitude,
            coordinates.longitude,
            geo.latitude,
            geo.longitude,
          )
        : Number.POSITIVE_INFINITY;
      return {
        id: document.id,
        name: document.get("name"),
        address: document.get("address"),
        distanceMeters: Math.round(distanceMeters),
        sameAddress,
      };
    })
    .filter(
      (candidate) => candidate.sameAddress || candidate.distanceMeters <= 200,
    )
    .map(({sameAddress: _, ...candidate}) => candidate);
}

function idempotencyReference(uid: string, key: string) {
  const digest = createHash("sha256").update(`${uid}:${key}`).digest("hex");
  return db.collection("contributionIdempotency").doc(digest);
}

function requiredString(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${label}格式不正確。`);
  }
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new HttpsError("invalid-argument", `${label}長度不正確。`);
  }
  return normalized;
}

function validCategories(value: unknown): string[] {
  const categories = stringList(value, "分類", 5, 20);
  if (categories.length === 0 || categories.some((item) => !categoryValues.has(item))) {
    throw new HttpsError("invalid-argument", "請至少選擇一個有效分類。");
  }
  return [...new Set(categories)];
}

function validAmenities(value: unknown): string[] {
  // 舊版 App 尚未傳送設施欄位，視為未填而非拒絕整筆投稿。
  if (value === undefined) return [];
  const amenities = stringList(value, "店家設施", 10, 30);
  if (amenities.some((item) => !amenityValues.has(item))) {
    throw new HttpsError("invalid-argument", "包含無效的店家設施。");
  }
  return [...new Set(amenities)];
}

function validEditChanges(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "修正內容格式不正確。");
  }
  const raw = value as Record<string, unknown>;
  const changes: Record<string, unknown> = {};
  if (raw.name !== undefined) {
    const name = requiredString(raw.name, "店家名稱", 2, 80);
    changes.name = name;
    changes.nameLower = name.toLowerCase();
    changes.nameNormalized = normalizeName(name);
  }
  if (raw.address !== undefined) {
    changes.address = requiredString(raw.address, "地址", 3, 200);
  }
  if (raw.googleMapsUrl !== undefined) {
    const googleMapsUrl = optionalHttpsUrl(raw.googleMapsUrl);
    changes.googleMapsUrl = googleMapsUrl ?? FieldValue.delete();
  }
  if (raw.categories !== undefined) {
    changes.categories = validCategories(raw.categories);
  }
  if (raw.recommendedDishes !== undefined) {
    changes.recommendedDishes = stringList(raw.recommendedDishes, "推薦菜色", 10, 40);
  }
  if (raw.amenities !== undefined) {
    changes.amenities = validAmenities(raw.amenities);
  }
  if (raw.latitude !== undefined || raw.longitude !== undefined) {
    const coordinates = optionalCoordinates(raw.latitude, raw.longitude);
    if (coordinates == null) {
      changes.geo = FieldValue.delete();
      changes.geohash = FieldValue.delete();
    } else {
      changes.geo = new GeoPoint(coordinates.latitude, coordinates.longitude);
      changes.geohash = encodeGeohash(
        coordinates.latitude,
        coordinates.longitude,
      );
    }
  }
  if (Object.keys(changes).length === 0) {
    throw new HttpsError("invalid-argument", "請至少提供一項修正。");
  }
  return changes;
}

async function requireAdmin(uid: string) {
  if (!(await db.collection("admins").doc(uid).get()).exists) {
    throw new HttpsError("permission-denied", "只有管理員可以執行此操作。");
  }
}

export async function handleGetRestaurantContributionLimit(
  request: CallableRequest<Record<string, never>>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const settings = await contributionLimitsReference.get();
  return {
    restaurantDailyLimit: restaurantDailyLimitFromSettings(
      settings.get("restaurantDailyLimit"),
    ),
    photoDailyLimit: photoDailyLimitFromSettings(settings.get("photoDailyLimit")),
  };
}

export async function handleAdminUpdateRestaurant(
  request: CallableRequest<AdminUpdateRestaurantData>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const changes = validEditChanges(request.data.changes);
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  return db.runTransaction(async (transaction) => {
    const restaurant = await transaction.get(restaurantReference);
    if (!restaurant.exists || restaurant.get("status") !== "active") {
      throw new HttpsError("not-found", "找不到可管理的店家。");
    }
    transaction.update(restaurantReference, {
      ...changes,
      auditBefore: restaurant.data(),
      adminUpdatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {restaurantId};
  });
}

/** Removes a restaurant from public discovery while preserving its records. */
export async function handleAdminRemoveRestaurant(
  request: CallableRequest<AdminRemoveRestaurantData>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const restaurantId = documentId(request.data.restaurantId, "店家");
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  return db.runTransaction(async (transaction) => {
    const restaurant = await transaction.get(restaurantReference);
    if (!restaurant.exists) {
      throw new HttpsError("not-found", "找不到店家。");
    }
    if (restaurant.get("status") === "removed") {
      return {restaurantId, status: "removed"};
    }
    if (restaurant.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "此店家目前無法下架。");
    }
    transaction.update(restaurantReference, {
      status: "removed",
      auditBefore: restaurant.data(),
      removedBy: uid,
      removedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {restaurantId, status: "removed"};
  });
}

export async function handleUpdateRestaurantContributionLimit(
  request: CallableRequest<UpdateRestaurantContributionLimitData>,
) {
  const uid = validateCallable(request);
  await requireAdmin(uid);
  const restaurantDailyLimit = finiteInteger(
    request.data.restaurantDailyLimit,
    "每日新增店家上限",
    1,
    maximumRestaurantDailyLimit,
  );
  const photoDailyLimit = request.data.photoDailyLimit == null
    ? defaultPhotoDailyLimit
    : finiteInteger(
      request.data.photoDailyLimit,
      "每日照片上限",
      1,
      maximumPhotoDailyLimit,
    );
  await contributionLimitsReference.set(
    {
      restaurantDailyLimit,
      photoDailyLimit,
      updatedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  return {restaurantDailyLimit, photoDailyLimit};
}

function restaurantDailyLimitFromSettings(value: unknown): number {
  return typeof value === "number" &&
      Number.isInteger(value) &&
      value >= 1 &&
      value <= maximumRestaurantDailyLimit
    ? value
    : defaultRestaurantDailyLimit;
}

function photoDailyLimitFromSettings(value: unknown): number {
  return typeof value === "number" &&
      Number.isInteger(value) &&
      value >= 1 &&
      value <= maximumPhotoDailyLimit
    ? value
    : defaultPhotoDailyLimit;
}

function isRestaurantPhotoPath(
  value: unknown,
  restaurantId: string,
): value is string {
  return typeof value === "string" &&
    value.startsWith(`restaurant_photos/${restaurantId}/`) &&
    !value.includes("..");
}

function decisionValue(value: unknown): "approved" | "rejected" {
  if (value !== "approved" && value !== "rejected") {
    throw new HttpsError("invalid-argument", "審核決定不正確。");
  }
  return value;
}

async function removeReportedContent(
  transaction: Transaction,
  report: Record<string, unknown>,
) {
  const restaurantReference = db
    .collection("restaurants")
    .doc(report.restaurantId as string);
  if (report.targetType === "restaurant") {
    transaction.update(restaurantReference, {
      status: "removed",
      updatedAt: FieldValue.serverTimestamp(),
    });
    return;
  }
  const collection = report.targetType === "photo" ? "photos" : "reviews";
  const contentReference = restaurantReference
    .collection(collection)
    .doc(report.contentId as string);
  const content = await transaction.get(contentReference);
  if (!content.exists || content.get("status") !== "active") {
    return;
  }
  transaction.update(contentReference, {
    status: "removed",
    removedAt: FieldValue.serverTimestamp(),
  });
  if (collection === "photos") {
    transaction.update(restaurantReference, {
      photoCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } else {
    transaction.update(restaurantReference, {
      ratingSum: FieldValue.increment(-numericValue(content.get("rating"))),
      ratingCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
}

function stringList(
  value: unknown,
  label: string,
  maximumItems: number,
  maximumLength: number,
): string[] {
  if (!Array.isArray(value) || value.length > maximumItems) {
    throw new HttpsError("invalid-argument", `${label}格式不正確。`);
  }
  return value.map((item) => requiredString(item, label, 1, maximumLength));
}

function finiteNumber(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value < minimum || value > maximum) {
    throw new HttpsError("invalid-argument", `${label}格式不正確。`);
  }
  return value;
}

function optionalCoordinates(
  latitudeValue: unknown,
  longitudeValue: unknown,
): {latitude: number; longitude: number} | null {
  const latitudeMissing = latitudeValue === undefined || latitudeValue === null;
  const longitudeMissing = longitudeValue === undefined || longitudeValue === null;
  if (latitudeMissing && longitudeMissing) {
    return null;
  }
  if (latitudeMissing || longitudeMissing) {
    throw new HttpsError("invalid-argument", "緯度與經度必須同時提供。");
  }
  return {
    latitude: finiteNumber(latitudeValue, "緯度", -90, 90),
    longitude: finiteNumber(longitudeValue, "經度", -180, 180),
  };
}

function finiteInteger(
  value: unknown,
  label: string,
  minimum: number,
  maximum: number,
): number {
  const converted = finiteNumber(value, label, minimum, maximum);
  if (!Number.isInteger(converted)) {
    throw new HttpsError("invalid-argument", `${label}格式不正確。`);
  }
  return converted;
}

function documentId(value: unknown, label: string): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9_.-]{1,128}$/.test(value)) {
    throw new HttpsError("invalid-argument", `${label}識別碼不正確。`);
  }
  return value;
}

function validIdempotencyKey(value: unknown): string {
  if (typeof value !== "string" || !/^[A-Za-z0-9-]{16,80}$/.test(value)) {
    throw new HttpsError("invalid-argument", "請求識別碼不正確。");
  }
  return value;
}

function normalizeName(value: string): string {
  return value.normalize("NFKC").toLowerCase().replace(/[\s\p{P}\p{S}]+/gu, "");
}

function numericValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function stringValues(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];
}

function timestampMillis(value: unknown): number {
  return value instanceof Timestamp ? value.toMillis() : 0;
}

function haversineMeters(
  firstLatitude: number,
  firstLongitude: number,
  secondLatitude: number,
  secondLongitude: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const latitudeDelta = radians(secondLatitude - firstLatitude);
  const longitudeDelta = radians(secondLongitude - firstLongitude);
  const value =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(firstLatitude)) *
      Math.cos(radians(secondLatitude)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(value), Math.sqrt(1 - value));
}

function encodeGeohash(latitude: number, longitude: number, precision = 9) {
  const alphabet = "0123456789bcdefghjkmnpqrstuvwxyz";
  const latitudeRange = [-90, 90];
  const longitudeRange = [-180, 180];
  let result = "";
  let bit = 0;
  let character = 0;
  let even = true;
  while (result.length < precision) {
    const range = even ? longitudeRange : latitudeRange;
    const coordinate = even ? longitude : latitude;
    const midpoint = (range[0] + range[1]) / 2;
    if (coordinate >= midpoint) {
      character = character * 2 + 1;
      range[0] = midpoint;
    } else {
      character *= 2;
      range[1] = midpoint;
    }
    even = !even;
    bit += 1;
    if (bit === 5) {
      result += alphabet[character];
      bit = 0;
      character = 0;
    }
  }
  return result;
}

function storageDownloadUrl(storagePath: string, token: string): string {
  const encodedPath = encodeURIComponent(storagePath);
  const emulatorHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  if (emulatorHost) {
    return `http://${emulatorHost}/v0/b/${bucket.name}/o/${encodedPath}` +
      `?alt=media&token=${token}`;
  }
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
    `${encodedPath}?alt=media&token=${token}`;
}
