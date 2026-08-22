const assert = require("node:assert/strict");
const test = require("node:test");

const {getAuth} = require("firebase-admin/auth");
const {GeoPoint, getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {
  handleAdminUpdateRestaurant,
  handleDeleteReview,
  handleCreateRestaurant,
  handleFinalizePhotoUpload,
  handleGetRestaurantContributionLimit,
  handleMergeRestaurants,
  handleRequestPhotoUpload,
  handleReviewReport,
  handleReviewRestaurantEdit,
  handleRemoveRestaurantPhoto,
  handleSetRestaurantCoverPhoto,
  handleSubmitDuplicateRestaurant,
  handleSubmitReport,
  handleSubmitRestaurantEdit,
  handleSubmitReview,
  handleUpdateRestaurantContributionLimit,
} = require("../lib/contribution");

const app = {
  appId: "1:267091699106:android:e2d87ebe40382e9d9d3efb",
  token: {},
  alreadyConsumed: false,
};

test("contribution flow is idempotent and keeps aggregates correct", async (context) => {
  const suffix = Date.now().toString();
  const uid = `contribution-${suffix}`;
  const targetId = `target-${suffix}`;
  const auth = getAuth();
  const db = getFirestore();
  const bucket = getStorage().bucket();
  const authData = {
    uid,
    token: {auth_time: Math.floor(Date.now() / 1000)},
    rawToken: "emulator-test-token",
  };
  const request = (data) => ({
    data,
    auth: authData,
    app,
    rawRequest: {},
    acceptsStreaming: false,
  });
  let restaurantId;
  let addressOnlyRestaurantId;
  let storagePath;

  context.after(async () => {
    const operations = await db
      .collection("contributionIdempotency")
      .where("uid", "==", uid)
      .get();
    const writer = db.bulkWriter();
    operations.docs.forEach((document) => writer.delete(document.ref));
    await writer.close();
    await Promise.allSettled([
      auth.deleteUser(uid),
      db.recursiveDelete(db.collection("users").doc(uid)),
      restaurantId
        ? db.recursiveDelete(db.collection("restaurants").doc(restaurantId))
        : Promise.resolve(),
      addressOnlyRestaurantId
        ? db.recursiveDelete(
            db.collection("restaurants").doc(addressOnlyRestaurantId),
          )
        : Promise.resolve(),
      db.recursiveDelete(db.collection("restaurants").doc(targetId)),
      db.collection("contributionUsage").doc(uid).delete(),
      db.collection("admins").doc(uid).delete(),
      db.collection("systemSettings").doc("contributionLimits").delete(),
      storagePath
        ? bucket.file(storagePath).delete({ignoreNotFound: true})
        : Promise.resolve(),
    ]);
  });

  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.collection("users").doc(uid).set({displayName: "Contributor"});
  await db.collection("restaurants").doc(targetId).set({
    name: "測試分店",
    nameLower: "測試分店",
    nameNormalized: "測試分店",
    address: "台北市測試路 1 號",
    geo: new GeoPoint(25.04, 121.52),
    geohash: "wsqqq",
    categories: ["小吃"],
    recommendedDishes: ["小菜"],
    photoCount: 0,
    ratingSum: 0,
    ratingCount: 0,
    favoriteCount: 0,
    status: "active",
  });

  const createData = {
    name: "測試分店",
    address: "台北市測試路 2 號",
    latitude: 25.0405,
    longitude: 121.5205,
    categories: ["小吃"],
    recommendedDishes: ["招牌麵"],
    amenities: ["可刷卡", "外帶"],
    idempotencyKey: `create-${suffix}-1234567890`,
  };
  await assert.rejects(
    handleCreateRestaurant(request(createData)),
    (error) =>
      error.code === "failed-precondition" &&
      error.details.candidates.length === 1,
  );

  const created = await handleCreateRestaurant(
    request({...createData, duplicateAcknowledged: true}),
  );
  restaurantId = created.restaurantId;
  const repeated = await handleCreateRestaurant(
    request({...createData, duplicateAcknowledged: true}),
  );
  assert.equal(repeated.restaurantId, restaurantId);
  assert.equal(
    (await db.collection("restaurants").doc(restaurantId).get()).get("nameNormalized"),
    "測試分店",
  );
  assert.deepEqual(
    (await db.collection("restaurants").doc(restaurantId).get()).get("amenities"),
    ["可刷卡", "外帶"],
  );

  const addressOnly = await handleCreateRestaurant(
    request({
      name: `Address only ${suffix}`,
      address: `Address only ${suffix}`,
      categories: createData.categories,
      recommendedDishes: createData.recommendedDishes,
      idempotencyKey: `address-only-${suffix}-1234567890`,
    }),
  );
  addressOnlyRestaurantId = addressOnly.restaurantId;
  const addressOnlyRestaurant = await db
    .collection("restaurants")
    .doc(addressOnlyRestaurantId)
    .get();
  assert.equal(addressOnlyRestaurant.get("address"), `Address only ${suffix}`);
  assert.equal(addressOnlyRestaurant.get("geo"), undefined);
  assert.equal(addressOnlyRestaurant.get("geohash"), undefined);

  const reserved = await handleRequestPhotoUpload(
    request({
      restaurantId,
      count: 1,
      idempotencyKey: `photo-${suffix}-1234567890`,
    }),
  );
  const repeatedReservation = await handleRequestPhotoUpload(
    request({
      restaurantId,
      count: 1,
      idempotencyKey: `photo-${suffix}-1234567890`,
    }),
  );
  assert.deepEqual(repeatedReservation.reservations, reserved.reservations);
  const reservation = reserved.reservations[0];
  storagePath = reservation.storagePath;
  const usageBeforeFinalize = await db.collection("contributionUsage").doc(uid).get();
  assert.equal(usageBeforeFinalize.get("counts.photos"), undefined);
  await bucket.file(storagePath).save(Buffer.from("fake-jpeg"), {
    contentType: "image/jpeg",
  });
  const finalized = await handleFinalizePhotoUpload(
    request({reservationId: reservation.reservationId}),
  );
  const finalizedAgain = await handleFinalizePhotoUpload(
    request({reservationId: reservation.reservationId}),
  );
  assert.equal(finalizedAgain.photoId, finalized.photoId);
  const usageAfterFinalize = await db.collection("contributionUsage").doc(uid).get();
  assert.equal(usageAfterFinalize.get("counts.photos"), 1);
  const restaurantAfterPhoto = await db
    .collection("restaurants")
    .doc(restaurantId)
    .get();
  assert.equal(restaurantAfterPhoto.get("photoCount"), 1);
  assert.match(restaurantAfterPhoto.get("coverPhotoUrl"), /alt=media/);
  await handleSetRestaurantCoverPhoto(
    request({restaurantId, photoId: finalized.photoId}),
  );
  assert.equal(
    (await db.collection("restaurants").doc(restaurantId).get()).get("coverPhotoUrl"),
    finalized.url,
  );

  const duplicate = await handleSubmitDuplicateRestaurant(
    request({
      sourceRestaurantId: restaurantId,
      targetRestaurantId: targetId,
      reason: "這兩筆資料是同一家店",
      idempotencyKey: `merge-${suffix}-1234567890`,
    }),
  );
  await db.collection("admins").doc(uid).set({createdAt: new Date()});
  await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("photos")
    .doc("admin-selected-photo")
    .set({
      url: "https://example.test/admin-selected.jpg",
      uploadedBy: "another-user",
      status: "active",
    });
  await handleSetRestaurantCoverPhoto(
    request({restaurantId, photoId: "admin-selected-photo"}),
  );
  assert.equal(
    (await db.collection("restaurants").doc(restaurantId).get()).get("coverPhotoUrl"),
    "https://example.test/admin-selected.jpg",
  );
  await db
    .collection("restaurants")
    .doc(restaurantId)
    .collection("photos")
    .doc("admin-selected-photo")
    .update({status: "removed"});
  await handleAdminUpdateRestaurant(
    request({
      restaurantId,
      changes: {address: "台北市測試路 3 號"},
    }),
  );
  assert.equal(
    (await db.collection("restaurants").doc(restaurantId).get()).get("address"),
    "台北市測試路 3 號",
  );
  await handleAdminUpdateRestaurant(
    request({
      restaurantId,
      changes: {
        googleMapsUrl: "https://maps.app.goo.gl/example",
        latitude: 25.041,
        longitude: 121.521,
      },
    }),
  );
  const restaurantAfterLocationUpdate = await db
    .collection("restaurants")
    .doc(restaurantId)
    .get();
  assert.equal(
    restaurantAfterLocationUpdate.get("googleMapsUrl"),
    "https://maps.app.goo.gl/example",
  );
  assert.equal(restaurantAfterLocationUpdate.get("geo").latitude, 25.041);
  assert.equal(restaurantAfterLocationUpdate.get("geo").longitude, 121.521);
  assert.equal(typeof restaurantAfterLocationUpdate.get("geohash"), "string");

  await handleAdminUpdateRestaurant(
    request({
      restaurantId,
      changes: {googleMapsUrl: null, latitude: null, longitude: null},
    }),
  );
  const restaurantAfterLocationRemoval = await db
    .collection("restaurants")
    .doc(restaurantId)
    .get();
  assert.equal(restaurantAfterLocationRemoval.get("googleMapsUrl"), undefined);
  assert.equal(restaurantAfterLocationRemoval.get("geo"), undefined);
  assert.equal(restaurantAfterLocationRemoval.get("geohash"), undefined);

  const updatedLimit = await handleUpdateRestaurantContributionLimit(
    request({restaurantDailyLimit: 20}),
  );
  assert.equal(updatedLimit.restaurantDailyLimit, 20);
  const currentLimit = await handleGetRestaurantContributionLimit(request({}));
  assert.equal(currentLimit.restaurantDailyLimit, 20);
  const merged = await handleMergeRestaurants(
    request({requestId: duplicate.requestId}),
  );
  assert.equal(merged.targetRestaurantId, targetId);
  const source = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(source.get("status"), "merged");
  assert.equal(source.get("mergedIntoRestaurantId"), targetId);
  assert.equal(source.get("photoCount"), 0);
  const target = await db.collection("restaurants").doc(targetId).get();
  assert.equal(target.get("photoCount"), 1);
  const movedPhotos = await db
    .collection("restaurants")
    .doc(targetId)
    .collection("photos")
    .get();
  assert.equal(movedPhotos.size, 1);
});

test("photo owners can remove their photos and the cover switches safely", async (context) => {
  const suffix = Date.now().toString();
  const uid = `photo-owner-${suffix}`;
  const otherUid = `photo-other-${suffix}`;
  const restaurantId = `photo-restaurant-${suffix}`;
  const db = getFirestore();
  const request = (data, requestUid = uid) => ({
    data,
    auth: {
      uid: requestUid,
      token: {auth_time: Math.floor(Date.now() / 1000)},
      rawToken: "emulator-test-token",
    },
    app,
    rawRequest: {},
    acceptsStreaming: false,
  });

  context.after(async () => {
    await Promise.allSettled([
      db.recursiveDelete(db.collection("restaurants").doc(restaurantId)),
      db.collection("admins").doc(uid).delete(),
      db.collection("admins").doc(otherUid).delete(),
    ]);
  });

  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  await restaurantReference.set({
    name: "Photo Restaurant",
    address: "Test address",
    photoCount: 2,
    coverPhotoUrl: "https://example.test/owner.jpg",
    status: "active",
  });
  await restaurantReference.collection("photos").doc("owner-photo").set({
    url: "https://example.test/owner.jpg",
    uploadedBy: uid,
    status: "active",
    createdAt: new Date(),
  });
  await restaurantReference.collection("photos").doc("replacement-photo").set({
    url: "https://example.test/replacement.jpg",
    uploadedBy: otherUid,
    status: "active",
    createdAt: new Date(Date.now() - 1000),
  });

  await handleRemoveRestaurantPhoto(
    request({restaurantId, photoId: "owner-photo"}),
  );
  const restaurant = await restaurantReference.get();
  const removedPhoto = await restaurantReference
    .collection("photos")
    .doc("owner-photo")
    .get();
  assert.equal(restaurant.get("photoCount"), 1);
  assert.equal(
    restaurant.get("coverPhotoUrl"),
    "https://example.test/replacement.jpg",
  );
  assert.equal(removedPhoto.get("status"), "removed");
  assert.equal(removedPhoto.get("url"), undefined);

  await assert.rejects(
    handleRemoveRestaurantPhoto(
      request({restaurantId, photoId: "replacement-photo"}, uid),
    ),
    (error) => error.code === "permission-denied",
  );
});

test("review and moderation flow keeps restaurant aggregates correct", async (context) => {
  const suffix = Date.now().toString();
  const uid = `moderation-${suffix}`;
  const restaurantId = `moderation-restaurant-${suffix}`;
  const auth = getAuth();
  const db = getFirestore();
  const authData = {
    uid,
    token: {
      auth_time: Math.floor(Date.now() / 1000),
      name: "Test Reviewer",
    },
    rawToken: "emulator-test-token",
  };
  const request = (data) => ({
    data,
    auth: authData,
    app,
    rawRequest: {},
    acceptsStreaming: false,
  });

  context.after(async () => {
    const operations = await db
      .collection("contributionIdempotency")
      .where("uid", "==", uid)
      .get();
    const writer = db.bulkWriter();
    operations.docs.forEach((document) => writer.delete(document.ref));
    await writer.close();
    await Promise.allSettled([
      auth.deleteUser(uid),
      db.recursiveDelete(db.collection("users").doc(uid)),
      db.recursiveDelete(db.collection("restaurants").doc(restaurantId)),
      db.collection("contributionUsage").doc(uid).delete(),
      db.collection("admins").doc(uid).delete(),
    ]);
  });

  await auth.createUser({uid, email: `${uid}@example.test`});
  await db.collection("admins").doc(uid).set({createdAt: new Date()});
  await db.collection("restaurants").doc(restaurantId).set({
    name: "Original Restaurant",
    nameLower: "original restaurant",
    nameNormalized: "originalrestaurant",
    address: "Original address",
    geo: new GeoPoint(25.04, 121.52),
    geohash: "wsqqq",
    categories: ["其他"],
    recommendedDishes: [],
    photoCount: 0,
    ratingSum: 0,
    ratingCount: 0,
    favoriteCount: 0,
    status: "active",
  });

  await handleSubmitReview(
    request({
      restaurantId,
      rating: 4,
      text: "First review",
      idempotencyKey: `review-first-${suffix}`,
    }),
  );
  await handleSubmitReview(
    request({
      restaurantId,
      rating: 2,
      text: "Updated review",
      idempotencyKey: `review-update-${suffix}`,
    }),
  );
  let restaurant = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(restaurant.get("ratingSum"), 2);
  assert.equal(restaurant.get("ratingCount"), 1);
  const review = await restaurant.ref.collection("reviews").doc(uid).get();
  assert.equal(review.get("rating"), 2);

  const edit = await handleSubmitRestaurantEdit(
    request({
      restaurantId,
      changes: {name: "Updated Restaurant"},
      reason: "The restaurant has changed its name.",
      idempotencyKey: `edit-${suffix}`,
    }),
  );
  await handleReviewRestaurantEdit(
    request({requestId: edit.requestId, decision: "approved"}),
  );
  restaurant = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(restaurant.get("name"), "Updated Restaurant");
  assert.equal(restaurant.get("auditBefore.name"), "Original Restaurant");

  const report = await handleSubmitReport(
    request({
      targetType: "review",
      restaurantId,
      contentId: uid,
      reason: "This review violates the community rules.",
      idempotencyKey: `report-${suffix}`,
    }),
  );
  await handleReviewReport(
    request({requestId: report.reportId, decision: "approved"}),
  );
  restaurant = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(restaurant.get("ratingSum"), 0);
  assert.equal(restaurant.get("ratingCount"), 0);
  const removedReview = await restaurant.ref
    .collection("reviews")
    .doc(uid)
    .get();
  assert.equal(removedReview.get("status"), "removed");

  await handleSubmitReview(
    request({
      restaurantId,
      rating: 5,
      text: "Review to delete",
      idempotencyKey: `review-delete-setup-${suffix}`,
    }),
  );
  const deleteData = {
    restaurantId,
    idempotencyKey: `review-delete-${suffix}`,
  };
  await handleDeleteReview(request(deleteData));
  await handleDeleteReview(request(deleteData));
  restaurant = await db.collection("restaurants").doc(restaurantId).get();
  assert.equal(restaurant.get("ratingSum"), 0);
  assert.equal(restaurant.get("ratingCount"), 0);
});
