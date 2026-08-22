const assert = require("node:assert/strict");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
if (!firestoreHost || !authHost || !storageHost) {
  throw new Error("verify:phase4:emulator 只能在 Firebase Emulator 中執行。");
}
if (getApps().length === 0) {
  initializeApp({
    projectId: "food-9a095",
    storageBucket: "food-9a095.firebasestorage.app",
  });
}

const projectPath = "projects/food-9a095/databases/(default)/documents";
const firestoreUrl = `http://${firestoreHost}/v1/${projectPath}`;
const suffix = Date.now().toString();
const restaurantId = `favorite-rule-${suffix}`;

async function verify() {
  const signUp = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        email: `favorite-${suffix}@example.test`,
        password: "Password123!",
        returnSecureToken: true,
      }),
    },
  );
  assert.equal(signUp.status, 200);
  const user = await signUp.json();
  const db = getFirestore();
  const restaurantReference = db.collection("restaurants").doc(restaurantId);
  const userReference = db.collection("users").doc(user.localId);
  const favoriteName =
    `${projectPath}/users/${user.localId}/favorites/${restaurantId}`;
  const restaurantName = `${projectPath}/restaurants/${restaurantId}`;
  const reservationId = `storage-rule-${suffix}.jpg`;
  const storagePath = `restaurant_photos/${restaurantId}/${reservationId}`;
  const reservationReference = db
    .collection("uploadReservations")
    .doc(reservationId);

  try {
    await userReference.set({displayName: "Favorite Rule Test"});
    await restaurantReference.set({
      name: "收藏規則測試店家",
      nameLower: "收藏規則測試店家",
      status: "active",
      favoriteCount: 0,
    });

    const addFavorite = await commit(user.idToken, [
      {
        update: {
          name: favoriteName,
          fields: {
            addedAt: {timestampValue: new Date().toISOString()},
            restaurantName: {stringValue: "收藏規則測試店家"},
            restaurantCoverPhotoUrl: {nullValue: null},
            restaurantCategories: {
              arrayValue: {values: [{stringValue: "小吃"}]},
            },
          },
        },
        currentDocument: {exists: false},
      },
      {
        transform: {
          document: restaurantName,
          fieldTransforms: [
            {fieldPath: "favoriteCount", increment: {integerValue: "1"}},
          ],
        },
      },
    ]);
    assert.equal(addFavorite.status, 200, await addFavorite.text());
    assert.equal((await restaurantReference.get()).get("favoriteCount"), 1);

    const ownerRead = await fetch(
      `${firestoreUrl}/users/${user.localId}/favorites/${restaurantId}`,
      {headers: {authorization: `Bearer ${user.idToken}`}},
    );
    assert.equal(ownerRead.status, 200);
    const anonymousRead = await fetch(
      `${firestoreUrl}/users/${user.localId}/favorites/${restaurantId}`,
    );
    assert.equal(anonymousRead.status, 403);

    const removeFavorite = await commit(user.idToken, [
      {delete: favoriteName, currentDocument: {exists: true}},
      {
        transform: {
          document: restaurantName,
          fieldTransforms: [
            {fieldPath: "favoriteCount", increment: {integerValue: "-1"}},
          ],
        },
      },
    ]);
    assert.equal(removeFavorite.status, 200, await removeFavorite.text());
    assert.equal((await restaurantReference.get()).get("favoriteCount"), 0);

    await reservationReference.set({
      uid: user.localId,
      restaurantId,
      storagePath,
      status: "pending",
      expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
    });
    const upload = await fetch(
      `http://${storageHost}/v0/b/food-9a095.firebasestorage.app/o` +
        `?uploadType=media&name=${encodeURIComponent(storagePath)}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${user.idToken}`,
          "content-type": "image/jpeg",
        },
        body: Buffer.from("storage-rule-jpeg"),
      },
    );
    assert.equal(upload.status, 200, await upload.text());

    process.stdout.write("Phase 4 favorite and upload reservation rules verified.\n");
  } finally {
    await Promise.allSettled([
      getAuth().deleteUser(user.localId),
      db.recursiveDelete(userReference),
      db.recursiveDelete(restaurantReference),
      reservationReference.delete(),
      getStorage().bucket().file(storagePath).delete({ignoreNotFound: true}),
    ]);
  }
}

function commit(token, writes) {
  return fetch(`http://${firestoreHost}/v1/${projectPath}:commit`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({writes}),
  });
}

verify().catch((error) => {
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
});
