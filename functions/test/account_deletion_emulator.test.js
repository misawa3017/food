const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const test = require("node:test");

const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {handleDeleteAccount} = require("../lib/account_deletion");

test("deleteAccount validates requests and removes user data", async (context) => {
  const uid = `delete-test-${Date.now()}`;
  const restaurantId = `restaurant-${Date.now()}`;
  const photoPath = `restaurant_photos/${restaurantId}/${uid}/photo.jpg`;
  const reservationPath =
    `restaurant_photos/${restaurantId}/${uid}/reserved.jpg`;
  const requestId = createHash("sha256").update(uid).digest("hex");
  const auth = getAuth();
  const db = getFirestore();
  const bucket = getStorage().bucket();

  context.after(async () => {
    await Promise.allSettled([
      auth.deleteUser(uid),
      db.recursiveDelete(db.collection("users").doc(uid)),
      db.recursiveDelete(db.collection("restaurants").doc(restaurantId)),
      db.collection("reports").doc(uid).delete(),
      db.collection("contributionUsage").doc(uid).delete(),
      db.collection("uploadReservations").doc(uid).delete(),
      db.collection("accountDeletionRequests").doc(requestId).delete(),
      bucket.file(photoPath).delete({ignoreNotFound: true}),
      bucket.file(reservationPath).delete({ignoreNotFound: true}),
    ]);
  });

  const baseRequest = {
    data: {confirmation: "DELETE", source: "app"},
    rawRequest: {},
    acceptsStreaming: false,
  };

  await assert.rejects(
    handleDeleteAccount(baseRequest),
    (error) => error.code === "unauthenticated",
  );

  const authData = {
    uid,
    token: {auth_time: Math.floor(Date.now() / 1000)},
    rawToken: "emulator-test-token",
  };
  await assert.rejects(
    handleDeleteAccount({...baseRequest, auth: authData}),
    (error) => error.code === "permission-denied",
  );

  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.collection("users").doc(uid).set({displayName: "Delete Test"});
  await db
    .collection("users")
    .doc(uid)
    .collection("favorites")
    .doc(restaurantId)
    .set({createdAt: new Date()});
  await db.collection("restaurants").doc(restaurantId).set({
    createdBy: uid,
    ratingSum: 10,
    ratingCount: 2,
  });
  await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("reviews")
    .doc(uid)
    .set({authorUid: uid, rating: 4, status: "active"});
  await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("photos")
    .doc("photo-1")
    .set({
      uploadedBy: uid,
      storagePath: photoPath,
      status: "active",
      url: "https://example.test/photo.jpg",
    });
  await db.collection("reports").doc(uid).set({reportedBy: uid});
  await db.collection("contributionUsage").doc(uid).set({count: 1});
  await db.collection("uploadReservations").doc(uid).set({
    uid,
    storagePath: reservationPath,
    status: "reserved",
  });
  await bucket.file(photoPath).save(Buffer.from("test-photo"));
  await bucket.file(reservationPath).save(Buffer.from("reserved-photo"));

  const result = await handleDeleteAccount({
    ...baseRequest,
    auth: authData,
    app: {
      appId: "1:267091699106:android:e2d87ebe40382e9d9d3efb",
      token: {},
      alreadyConsumed: false,
    },
  });

  assert.equal(result.status, "completed");
  await assert.rejects(
    auth.getUser(uid),
    (error) => error.code === "auth/user-not-found",
  );
  assert.equal((await db.collection("users").doc(uid).get()).exists, false);

  const restaurant = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(restaurant.get("createdBy"), "deleted");
  assert.equal(restaurant.get("ratingSum"), 6);
  assert.equal(restaurant.get("ratingCount"), 1);

  const review = await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("reviews")
    .doc(uid)
    .get();
  assert.equal(review.exists, false);

  const photo = await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("photos")
    .doc("photo-1")
    .get();
  assert.equal(photo.get("uploadedBy"), "deleted");
  assert.equal(photo.get("status"), "removed");
  assert.equal(photo.get("storagePath"), undefined);
  assert.equal((await bucket.file(photoPath).exists())[0], false);

  const reservation = await db
    .collection("uploadReservations")
    .doc(uid)
    .get();
  assert.equal(reservation.get("uid"), "deleted");
  assert.equal(reservation.get("status"), "expired");
  assert.equal(reservation.get("storagePath"), undefined);
  assert.equal((await bucket.file(reservationPath).exists())[0], false);

  assert.equal(
    (await db.collection("reports").doc(uid).get()).get("reportedBy"),
    "deleted",
  );
  assert.equal(
    (await db.collection("contributionUsage").doc(uid).get()).exists,
    false,
  );

  const deletionRequest = await db
    .collection("accountDeletionRequests")
    .doc(requestId)
    .get();
  assert.equal(deletionRequest.get("status"), "completed");
  assert.equal(deletionRequest.get("uid"), undefined);
});
