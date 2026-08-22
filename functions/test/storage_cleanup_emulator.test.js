const assert = require("node:assert/strict");
const test = require("node:test");

const {Timestamp, getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {handleCleanupOrphanedPhotos} = require("../lib/storage_cleanup");

test("orphan cleanup expires reservations without deleting consumed photos", async (context) => {
  const suffix = Date.now().toString();
  const db = getFirestore();
  const bucket = getStorage().bucket();
  const expiredId = `expired-${suffix}.jpg`;
  const consumedId = `consumed-${suffix}.jpg`;
  const orphanId = `orphan-${suffix}.jpg`;
  const expiredPath = `restaurant_photos/cleanup/${expiredId}`;
  const consumedPath = `restaurant_photos/cleanup/${consumedId}`;
  const orphanPath = `restaurant_photos/cleanup/${orphanId}`;
  const start = Date.now();

  context.after(async () => {
    await Promise.allSettled([
      db.collection("uploadReservations").doc(expiredId).delete(),
      db.collection("uploadReservations").doc(consumedId).delete(),
      bucket.file(expiredPath).delete({ignoreNotFound: true}),
      bucket.file(consumedPath).delete({ignoreNotFound: true}),
      bucket.file(orphanPath).delete({ignoreNotFound: true}),
    ]);
  });

  await Promise.all([
    db.collection("uploadReservations").doc(expiredId).set({
      uid: "cleanup-user",
      restaurantId: "cleanup",
      storagePath: expiredPath,
      status: "pending",
      expiresAt: Timestamp.fromMillis(start - 1),
    }),
    db.collection("uploadReservations").doc(consumedId).set({
      uid: "cleanup-user",
      restaurantId: "cleanup",
      storagePath: consumedPath,
      status: "consumed",
      expiresAt: Timestamp.fromMillis(start - 1),
    }),
    bucket.file(expiredPath).save(Buffer.from("expired"), {
      contentType: "image/jpeg",
    }),
    bucket.file(consumedPath).save(Buffer.from("consumed"), {
      contentType: "image/jpeg",
    }),
    bucket.file(orphanPath).save(Buffer.from("orphan"), {
      contentType: "image/jpeg",
    }),
  ]);

  const result = await handleCleanupOrphanedPhotos(
    start + 25 * 60 * 60 * 1000,
    24 * 60 * 60 * 1000,
  );
  assert.ok(result.expiredReservationCount >= 1);
  assert.ok(result.orphanFileCount >= 1);
  assert.equal(
    (await db.collection("uploadReservations").doc(expiredId).get()).get(
      "status",
    ),
    "expired",
  );
  assert.equal((await bucket.file(expiredPath).exists())[0], false);
  assert.equal((await bucket.file(orphanPath).exists())[0], false);
  assert.equal((await bucket.file(consumedPath).exists())[0], true);
});
