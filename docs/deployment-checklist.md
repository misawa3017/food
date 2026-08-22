# Phase 7 部署檢查清單

目前 `food-9a095` 僅登記為 `dev` 專案。本文件是部署前操作清單，不代表已執行正式部署。

目前環境：`dev` 為 `food-9a095`；`prod` 為 `food-prod-9a095`（Firebase 專案名稱：Food Production）。prod 已註冊 Android App `com.misawa.food.food_app` 與 Web App，並建立位於 `asia-east1`、啟用刪除保護的預設 Firestore 資料庫。兩者的正式設定會以獨立 build flavor／設定檔處理，不覆蓋 dev。

## 1. 建立 prod Firebase 專案

1. 在 Firebase Console 建立新的正式專案，Firestore、Storage 與 Functions region 選擇 `asia-east1`。
2. 執行 `firebase use --add`，將新專案命名為 `prod`；不要把 `food-9a095` 當成正式環境。
3. 以 `flutterfire configure --project=<PROD_PROJECT_ID>` 產生正式 Android/Web 設定。正式設定不得覆蓋目前 dev 設定，應由 CI build flavor 或獨立設定檔注入。
4. 為正式 Android App 加入 release SHA-1/SHA-256，並啟用 Google 登入。

## 2. 帳單與預算

1. Functions、Storage 與 Cloud Scheduler 需要 Blaze 方案。
2. 在 Google Cloud Billing 建立每月預算警報，建議先設 NT$300、NT$1,000、NT$3,000 三個門檻通知。
3. 確認 Cloud Scheduler API、Cloud Functions API、Cloud Build API 與 Artifact Registry API 已啟用。
4. 每日孤兒照片清理會建立一個 Cloud Scheduler job；部署後到 Cloud Scheduler 確認時區為 `Asia/Taipei`。

## 3. App Check

1. Android 正式版註冊 Play Integrity；Web 註冊 reCAPTCHA Enterprise。
2. 先發布含 App Check SDK 的 dev/internal build，在 Firebase Console 的 **App Check → APIs** 觀察 verified/outdated/invalid metrics。
3. 未上線的新 prod 專案可直接開 enforcement；已有使用者時，必須確認絕大多數請求為 verified 後再逐項啟用。
4. Enforcement 順序：Cloud Functions → Firestore → Storage → Authentication。
5. Debug token 只能登記在 dev 專案，不得寫入原始碼、文件、CI log 或正式專案。

## 4. AdMob 與隱私權

1. 將 `AndroidManifest.xml` 的測試 App ID 換成正式 App ID。
2. 將 `lib/core/ads/ad_units.dart` 的 Banner/Interstitial 測試 ID 換成正式廣告單元。
3. 在 AdMob 建立 UMP「隱私權與訊息」，確認「我的 → 隱私權選項」在需要時可見。
4. 完成 Play Console Data safety、隱私權政策 URL 與帳號刪除 URL：`https://<domain>/account-deletion`。

## 5. 部署前驗證

```powershell
dart format .
flutter analyze
flutter test
flutter build web --release
flutter build appbundle --release

$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199'
$env:GCLOUD_PROJECT='food-9a095'
npm --prefix functions run test:emulator
npm --prefix functions audit --omit=dev
```

確認 `build/web` 不含測試用 debug token、Service Account 或其他 credential，再進行部署。

目前 `firebase-admin@14.2.0` 與 `firebase-functions@7.3.2` 已是可用的最新版，但 `npm audit --omit=dev` 仍會回報 7 個來自 `@google-cloud/storage` 依賴鏈的 moderate 漏洞。不要執行會把 `firebase-admin` 降級到 10.x 的 `npm audit fix --force`；正式部署前重新查核上游套件，待有相容修正版再升級。

## 6. 建議部署順序

先部署到 dev，完成 smoke test 後才部署 prod。執行以下命令前必須再次確認 CLI 目前專案：

```powershell
firebase use dev
firebase projects:list
firebase deploy --only firestore:rules,firestore:indexes,storage --project food-9a095
firebase deploy --only functions --project food-9a095
firebase deploy --only hosting --project food-9a095
```

prod 使用同樣順序，但 `--project` 必須明確指定正式專案 ID。不要只依賴 `default` alias。

## 7. 部署後 Smoke Test

- Web `/`、`/restaurants/<id>` 與 `/account-deletion` 直接重新整理仍能載入。
- Android/Web 登入、收藏、投稿、評論、檢舉與帳號刪除正常。
- 未帶 App Check 的 callable 被拒絕；合法 App 可呼叫。
- 無 reservation 的 Storage 上傳被拒絕。
- `cleanupOrphanedPhotos` 可從 Cloud Scheduler 手動執行，且不刪除 consumed 照片。
- Firebase/Google Cloud Logging 沒有大量 permission-denied、5xx 或重試風暴。

## 8. 回復策略

- Hosting 使用 Firebase Console 或 CLI rollback 到上一版本。
- Functions 保留上一版程式碼與 build artifact；有問題時只回復 Functions，不放寬 Rules。
- Rules 發生誤擋時，回復上一版已測試規則；禁止切換成公開測試模式。
- 索引建立可能耗時，部署期間不要刪除舊索引。
