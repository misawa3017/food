const assert = require("node:assert/strict");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
if (!firestoreHost || !authHost) {
  throw new Error("verify:phase5:emulator 只能在 Firebase Emulator 中執行。");
}
if (getApps().length === 0) {
  initializeApp({projectId: "food-9a095"});
}

const projectPath = "projects/food-9a095/databases/(default)/documents";
const firestoreUrl = `http://${firestoreHost}/v1/${projectPath}`;
const suffix = Date.now().toString();

async function verify() {
  const [adminUser, ownerUser, otherUser] = await Promise.all([
    signUp(`admin-${suffix}@example.test`),
    signUp(`owner-${suffix}@example.test`),
    signUp(`other-${suffix}@example.test`),
  ]);
  const db = getFirestore();
  const reportReference = db.collection("reports").doc(`report-${suffix}`);
  const editReference = db
    .collection("restaurantEditRequests")
    .doc(`edit-${suffix}`);
  const mergeReference = db
    .collection("restaurantMergeRequests")
    .doc(`merge-${suffix}`);
  const adminReference = db.collection("admins").doc(adminUser.localId);

  try {
    await Promise.all([
      adminReference.set({createdAt: new Date()}),
      reportReference.set({
        status: "pending",
        reportedBy: ownerUser.localId,
        restaurantId: "restaurant-1",
      }),
      editReference.set({
        status: "pending",
        submittedBy: ownerUser.localId,
        restaurantId: "restaurant-1",
      }),
      mergeReference.set({
        status: "pending",
        submittedBy: ownerUser.localId,
        sourceRestaurantId: "restaurant-1",
      }),
    ]);

    const adminStatus = await readDocument(
      adminUser.idToken,
      `admins/${adminUser.localId}`,
    );
    assert.equal(adminStatus.status, 200);

    for (const [collection, documentId] of [
      ["reports", reportReference.id],
      ["restaurantEditRequests", editReference.id],
      ["restaurantMergeRequests", mergeReference.id],
    ]) {
      const adminList = await queryPending(adminUser.idToken, collection);
      await assertStatus(adminList, 200);

      const ownerRead = await readDocument(
        ownerUser.idToken,
        `${collection}/${documentId}`,
      );
      await assertStatus(ownerRead, 200);

      const otherRead = await readDocument(
        otherUser.idToken,
        `${collection}/${documentId}`,
      );
      assert.equal(otherRead.status, 403);

      const otherList = await queryPending(otherUser.idToken, collection);
      assert.equal(otherList.status, 403);
    }

    process.stdout.write("Phase 5 moderation access rules verified.\n");
  } finally {
    await Promise.allSettled([
      getAuth().deleteUser(adminUser.localId),
      getAuth().deleteUser(ownerUser.localId),
      getAuth().deleteUser(otherUser.localId),
      adminReference.delete(),
      reportReference.delete(),
      editReference.delete(),
      mergeReference.delete(),
    ]);
  }
}

async function signUp(email) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        email,
        password: "Password123!",
        returnSecureToken: true,
      }),
    },
  );
  await assertStatus(response, 200);
  return response.json();
}

async function assertStatus(response, expected) {
  if (response.status !== expected) {
    assert.fail(`Expected ${expected}, received ${response.status}: ${await response.text()}`);
  }
}

function readDocument(token, path) {
  return fetch(`${firestoreUrl}/${path}`, {
    headers: {authorization: `Bearer ${token}`},
  });
}

function queryPending(token, collection) {
  return fetch(`http://${firestoreHost}/v1/${projectPath}:runQuery`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{collectionId: collection}],
        where: {
          fieldFilter: {
            field: {fieldPath: "status"},
            op: "EQUAL",
            value: {stringValue: "pending"},
          },
        },
      },
    }),
  });
}

verify().catch((error) => {
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
});
