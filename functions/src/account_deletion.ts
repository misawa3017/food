import {createHash, randomUUID} from "node:crypto";

import {getAuth} from "firebase-admin/auth";
import {
  DocumentReference,
  FieldValue,
  Query,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {logger} from "firebase-functions";
import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {initializeFirebaseAdmin} from "./firebase_admin";

interface DeleteAccountData {
  confirmation?: unknown;
  source?: unknown;
}

initializeFirebaseAdmin();

const db = getFirestore();
const deletionLeaseMilliseconds = 10 * 60 * 1000;
const recentAuthenticationSeconds = 5 * 60;
const enforceAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

export const deleteAccount = onCall<DeleteAccountData>(
  {
    region: "asia-east1",
    enforceAppCheck,
    consumeAppCheckToken: enforceAppCheck,
    memory: "512MiB",
    timeoutSeconds: 180,
  },
  handleDeleteAccount,
);

export async function handleDeleteAccount(
  request: CallableRequest<DeleteAccountData>,
) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "請先登入後再刪除帳號。");
    }
    if (enforceAppCheck && (!request.app || request.app.alreadyConsumed)) {
      throw new HttpsError("permission-denied", "App Check 驗證失敗。");
    }
    if (request.data.confirmation !== "DELETE") {
      throw new HttpsError("invalid-argument", "刪除確認內容不正確。");
    }

    const authTime = request.auth.token.auth_time;
    const currentSeconds = Math.floor(Date.now() / 1000);
    if (
      typeof authTime !== "number" ||
      currentSeconds - authTime > recentAuthenticationSeconds
    ) {
      throw new HttpsError(
        "failed-precondition",
        "請重新驗證登入後再刪除帳號。",
      );
    }

    const uid = request.auth.uid;
    const uidHash = createHash("sha256").update(uid).digest("hex");
    const requestReference = db
      .collection("accountDeletionRequests")
      .doc(uidHash);
    const invocationId = randomUUID();
    const source = request.data.source === "web" ? "web" : "app";
    const shouldProcess = await acquireDeletionLease(
      requestReference,
      uid,
      uidHash,
      invocationId,
      source,
    );

    if (!shouldProcess) {
      return {status: "completed"};
    }

    try {
      await removeReviews(uid);
      await removePhotos(uid);
      await removeUploadReservations(uid);
      await anonymizeOwnedData(uid);
      await db.recursiveDelete(db.collection("users").doc(uid));
      await db.collection("contributionUsage").doc(uid).delete();
      await getAuth().deleteUser(uid);

      await requestReference.set(
        {
          uid: FieldValue.delete(),
          uidHash,
          status: "completed",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          leaseExpiresAt: FieldValue.delete(),
          invocationId: FieldValue.delete(),
          errorCode: FieldValue.delete(),
        },
        {merge: true},
      );

      return {status: "completed"};
    } catch (error) {
      const errorCode = safeErrorCode(error);
      logger.error("Account deletion failed", {
        uidHash,
        invocationId,
        errorCode,
        error,
      });
      await requestReference.set(
        {
          status: "failed",
          errorCode,
          updatedAt: FieldValue.serverTimestamp(),
          leaseExpiresAt: FieldValue.delete(),
          invocationId: FieldValue.delete(),
        },
        {merge: true},
      );

      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError(
        "internal",
        "帳號刪除未完成，請稍後重試。",
      );
    }
}

async function acquireDeletionLease(
  requestReference: DocumentReference,
  uid: string,
  uidHash: string,
  invocationId: string,
  source: "app" | "web",
): Promise<boolean> {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestReference);
    const data = snapshot.data();
    if (data?.status === "completed") {
      return false;
    }

    const leaseExpiresAt = data?.leaseExpiresAt;
    if (
      data?.status === "processing" &&
      leaseExpiresAt instanceof Timestamp &&
      leaseExpiresAt.toMillis() > Date.now()
    ) {
      throw new HttpsError(
        "already-exists",
        "帳號刪除正在處理中，請稍後再試。",
      );
    }

    transaction.set(
      requestReference,
      {
        uid,
        uidHash,
        source,
        status: "processing",
        requestedAt: data?.requestedAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        leaseExpiresAt: Timestamp.fromMillis(
          Date.now() + deletionLeaseMilliseconds,
        ),
        invocationId,
        attemptCount: FieldValue.increment(1),
        errorCode: FieldValue.delete(),
      },
      {merge: true},
    );
    return true;
  });
}

async function removeReviews(uid: string): Promise<void> {
  const reviews = await db
    .collectionGroup("reviews")
    .where("authorUid", "==", uid)
    .get();

  for (const review of reviews.docs) {
    await db.runTransaction(async (transaction) => {
      const currentReview = await transaction.get(review.ref);
      if (!currentReview.exists) {
        return;
      }

      const restaurantReference = review.ref.parent.parent;
      const reviewData = currentReview.data();
      if (!restaurantReference || reviewData?.authorUid !== uid) {
        return;
      }

      if (reviewData.status === "active" && Number.isInteger(reviewData.rating)) {
        const restaurant = await transaction.get(restaurantReference);
        if (restaurant.exists) {
          const restaurantData = restaurant.data();
          const ratingSum = numericValue(restaurantData?.ratingSum);
          const ratingCount = numericValue(restaurantData?.ratingCount);
          transaction.update(restaurantReference, {
            ratingSum: Math.max(0, ratingSum - reviewData.rating),
            ratingCount: Math.max(0, ratingCount - 1),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      transaction.delete(review.ref);
    });
  }
}

async function removePhotos(uid: string): Promise<void> {
  const photos = await db
    .collectionGroup("photos")
    .where("uploadedBy", "==", uid)
    .get();
  const bucket = getStorage().bucket();

  for (const photo of photos.docs) {
    const storagePath = photo.get("storagePath");
    if (isAllowedPhotoPath(storagePath)) {
      await bucket.file(storagePath).delete({ignoreNotFound: true});
    }
    await photo.ref.update({
      uploadedBy: "deleted",
      status: "removed",
      url: FieldValue.delete(),
      storagePath: FieldValue.delete(),
      removedAt: FieldValue.serverTimestamp(),
    });
  }
}

async function removeUploadReservations(uid: string): Promise<void> {
  const reservations = await db
    .collection("uploadReservations")
    .where("uid", "==", uid)
    .get();
  const bucket = getStorage().bucket();

  for (const reservation of reservations.docs) {
    const storagePath = reservation.get("storagePath");
    if (isAllowedPhotoPath(storagePath)) {
      await bucket.file(storagePath).delete({ignoreNotFound: true});
    }
    await reservation.ref.update({
      uid: "deleted",
      status: "expired",
      storagePath: FieldValue.delete(),
      anonymizedAt: FieldValue.serverTimestamp(),
    });
  }
}

async function anonymizeOwnedData(uid: string): Promise<void> {
  await Promise.all([
    anonymizeQuery(
      db.collection("restaurants").where("createdBy", "==", uid),
      {
        createdBy: "deleted",
        recommenderName: "匿名美食家",
      },
    ),
    anonymizeQuery(db.collection("reports").where("reportedBy", "==", uid), {
      reportedBy: "deleted",
    }),
    anonymizeQuery(
      db.collection("restaurantEditRequests").where("submittedBy", "==", uid),
      {submittedBy: "deleted"},
    ),
    anonymizeQuery(
      db
        .collection("restaurantMergeRequests")
        .where("submittedBy", "==", uid),
      {submittedBy: "deleted"},
    ),
  ]);
}

async function anonymizeQuery(
  query: Query,
  values: Record<string, unknown>,
): Promise<void> {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return;
  }

  const writer = db.bulkWriter();
  for (const document of snapshot.docs) {
    writer.update(document.ref, {
      ...values,
      anonymizedAt: FieldValue.serverTimestamp(),
    });
  }
  await writer.close();
}

function isAllowedPhotoPath(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.startsWith("restaurant_photos/") &&
    !value.includes("..")
  );
}

function numericValue(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

function safeErrorCode(error: unknown): string {
  if (error instanceof HttpsError) {
    return error.code;
  }
  if (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    typeof error.code === "string"
  ) {
    return error.code.slice(0, 80);
  }
  return "unknown";
}
