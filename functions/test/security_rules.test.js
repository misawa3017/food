const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");
const {deleteObject, ref, uploadBytes} = require("firebase/storage");

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST;

test("phase 7 firestore and storage rules enforce client boundaries", async (context) => {
  if (!firestoreHost || !storageHost) {
    context.skip("Firebase Firestore and Storage emulators are required.");
    return;
  }
  const projectId = "food-9a095";
  const [firestoreHostname, firestorePort] = firestoreHost.split(":");
  const [storageHostname, storagePort] = storageHost.split(":");
  const testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: firestoreHostname,
      port: Number(firestorePort),
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firebase/firestore.rules"),
        "utf8",
      ),
    },
    storage: {
      host: storageHostname,
      port: Number(storagePort),
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firebase/storage.rules"),
        "utf8",
      ),
    },
  });
  const restaurantId = "rules-restaurant";
  const uploadId = "valid-upload.jpg";
  context.after(async () => {
    await testEnvironment.withSecurityRulesDisabled(async (adminContext) => {
      const firestore = adminContext.firestore();
      await Promise.all([
        deleteDoc(doc(firestore, "restaurants", restaurantId)),
        deleteDoc(doc(firestore, "admins", "admin-user")),
        deleteDoc(doc(firestore, "reports", "report-1")),
        deleteDoc(doc(firestore, "restaurantEditRequests", "edit-1")),
        deleteDoc(doc(firestore, "restaurantMergeRequests", "merge-1")),
        deleteDoc(doc(firestore, "uploadReservations", uploadId)),
        deleteObject(
          ref(
            adminContext.storage(),
            `restaurant_photos/${restaurantId}/${uploadId}`,
          ),
        ).catch(() => undefined),
      ]);
    });
    await testEnvironment.cleanup();
  });

  await testEnvironment.withSecurityRulesDisabled(async (adminContext) => {
    const firestore = adminContext.firestore();
    await Promise.all([
      setDoc(doc(firestore, "restaurants", restaurantId), {
        name: "Rules Restaurant",
        status: "active",
        favoriteCount: 0,
      }),
      setDoc(doc(firestore, "admins", "admin-user"), {enabled: true}),
      setDoc(doc(firestore, "reports", "report-1"), {
        status: "pending",
        reportedBy: "alice",
      }),
      setDoc(doc(firestore, "restaurantEditRequests", "edit-1"), {
        status: "pending",
        submittedBy: "alice",
      }),
      setDoc(doc(firestore, "restaurantMergeRequests", "merge-1"), {
        status: "pending",
        submittedBy: "alice",
      }),
      setDoc(doc(firestore, "uploadReservations", uploadId), {
        uid: "alice",
        restaurantId,
        storagePath: `restaurant_photos/${restaurantId}/${uploadId}`,
        status: "pending",
        expiresAt: Timestamp.fromMillis(Date.now() + 60_000),
      }),
    ]);
  });

  const anonymous = testEnvironment.unauthenticatedContext();
  const alice = testEnvironment.authenticatedContext("alice");
  const bob = testEnvironment.authenticatedContext("bob");
  const admin = testEnvironment.authenticatedContext("admin-user");
  const aliceDb = alice.firestore();

  await assertFails(
    setDoc(doc(anonymous.firestore(), "restaurants", "anonymous-write"), {
      status: "active",
    }),
  );
  for (const documentPath of [
    "restaurants/client-created",
    `restaurants/${restaurantId}/photos/client-photo`,
    `restaurants/${restaurantId}/reviews/alice`,
    "reports/client-report",
    "restaurantEditRequests/client-edit",
    "restaurantMergeRequests/client-merge",
    "contributionUsage/alice",
    "uploadReservations/client-upload",
  ]) {
    await assertFails(setDoc(doc(aliceDb, documentPath), {status: "pending"}));
  }

  await assertFails(
    updateDoc(doc(aliceDb, "restaurants", restaurantId), {name: "Changed"}),
  );
  await assertFails(
    getDocs(
      query(
        collection(bob.firestore(), "reports"),
        where("status", "==", "pending"),
      ),
    ),
  );
  await assertSucceeds(
    getDocs(
      query(
        collection(admin.firestore(), "reports"),
        where("status", "==", "pending"),
      ),
    ),
  );

  const favoriteReference = doc(
    aliceDb,
    "users",
    "alice",
    "favorites",
    restaurantId,
  );
  const restaurantReference = doc(aliceDb, "restaurants", restaurantId);
  await assertFails(
    setDoc(favoriteReference, {
      addedAt: Timestamp.now(),
      restaurantName: "Rules Restaurant",
      restaurantCoverPhotoUrl: null,
      restaurantCategories: [],
    }),
  );
  await assertSucceeds(
    runTransaction(aliceDb, async (transaction) => {
      transaction.set(favoriteReference, {
        addedAt: Timestamp.now(),
        restaurantName: "Rules Restaurant",
        restaurantCoverPhotoUrl: null,
        restaurantCategories: [],
      });
      transaction.update(restaurantReference, {favoriteCount: increment(1)});
    }),
  );
  await assertFails(
    getDoc(
      doc(
        bob.firestore(),
        "users",
        "alice",
        "favorites",
        restaurantId,
      ),
    ),
  );
  await assertFails(deleteDoc(favoriteReference));
  await assertSucceeds(
    runTransaction(aliceDb, async (transaction) => {
      transaction.delete(favoriteReference);
      transaction.update(restaurantReference, {favoriteCount: increment(-1)});
    }),
  );

  const content = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
  await assertFails(
    uploadBytes(
      ref(
        alice.storage(),
        `restaurant_photos/${restaurantId}/missing-reservation.jpg`,
      ),
      content,
      {contentType: "image/jpeg"},
    ),
  );
  await assertSucceeds(
    uploadBytes(
      ref(
        alice.storage(),
        `restaurant_photos/${restaurantId}/${uploadId}`,
      ),
      content,
      {contentType: "image/jpeg"},
    ),
  );
});
