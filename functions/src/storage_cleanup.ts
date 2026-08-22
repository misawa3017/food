import {Timestamp, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {initializeFirebaseAdmin} from "./firebase_admin";

initializeFirebaseAdmin();

const db = getFirestore();
const bucket = getStorage().bucket();
const orphanGraceMilliseconds = 24 * 60 * 60 * 1000;

export const cleanupOrphanedPhotos = onSchedule(
  {
    schedule: "every day 03:30",
    timeZone: "Asia/Taipei",
    region: "asia-east1",
    memory: "256MiB",
    timeoutSeconds: 300,
  },
  async () => {
    const result = await handleCleanupOrphanedPhotos();
    logger.info("Orphaned photo cleanup completed", result);
  },
);

export async function handleCleanupOrphanedPhotos(
  nowMilliseconds = Date.now(),
  graceMilliseconds = orphanGraceMilliseconds,
) {
  const now = Timestamp.fromMillis(nowMilliseconds);
  const expiredReservations = await db
    .collection("uploadReservations")
    .where("expiresAt", "<=", now)
    .limit(500)
    .get();
  let expiredReservationCount = 0;
  for (const reservation of expiredReservations.docs) {
    if (reservation.get("status") !== "pending") continue;
    const storagePath = reservation.get("storagePath");
    if (isAllowedPhotoPath(storagePath)) {
      await bucket.file(storagePath).delete({ignoreNotFound: true});
    }
    await reservation.ref.update({
      status: "expired",
      expiredAt: Timestamp.fromMillis(nowMilliseconds),
    });
    expiredReservationCount += 1;
  }

  const [files] = await bucket.getFiles({
    prefix: "restaurant_photos/",
    maxResults: 500,
  });
  const candidates = files.filter((file) => {
    const createdAt = Date.parse(file.metadata.timeCreated ?? "");
    return Number.isFinite(createdAt) &&
      createdAt + graceMilliseconds <= nowMilliseconds;
  });
  const references = candidates.map((file) =>
    db.collection("uploadReservations").doc(file.name.split("/").at(-1) ?? ""),
  );
  const reservations = references.length === 0
    ? []
    : await db.getAll(...references);
  let orphanFileCount = 0;
  for (let index = 0; index < candidates.length; index += 1) {
    if (reservations[index]?.exists) continue;
    await candidates[index].delete({ignoreNotFound: true});
    orphanFileCount += 1;
  }

  return {
    expiredReservationCount,
    orphanFileCount,
    scannedFileCount: files.length,
  };
}

function isAllowedPhotoPath(value: unknown): value is string {
  return typeof value === "string" &&
    value.startsWith("restaurant_photos/") &&
    !value.includes("..");
}
