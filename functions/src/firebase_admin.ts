import {getApps, initializeApp} from "firebase-admin/app";

export function initializeFirebaseAdmin() {
  if (getApps().length > 0) return;
  if (process.env.FIREBASE_CONFIG) {
    initializeApp();
    return;
  }
  const projectId = process.env.GCLOUD_PROJECT ??
    process.env.GOOGLE_CLOUD_PROJECT ??
    "food-9a095";
  initializeApp({
    projectId,
    storageBucket: process.env.FIREBASE_STORAGE_BUCKET ??
      `${projectId}.firebasestorage.app`,
  });
}
