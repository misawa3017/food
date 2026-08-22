# Firebase Console 設定步驟（Phase 1）

這份文件是給你（不是給 Claude）在瀏覽器裡手動操作 Firebase Console 的步驟。完成後回來告訴我，我會接著跑 `flutterfire configure` 把設定接進專案。

專案已確定的識別碼（後面會用到）：

| 平台 | 識別碼 |
|---|---|
| Android package name | `com.misawa.food.food_app` |
| iOS bundle ID | `com.misawa.food.foodApp` |
| Android debug SHA-1 | `C9:FD:7F:EF:44:A1:D8:EB:B9:A3:CA:81:C6:4D:F8:17:BF:3A:0F:20` |
| Android debug SHA-256 | `77:84:0A:F1:9C:50:7C:46:D9:84:2B:A1:93:A7:31:AD:AF:11:06:BA:08:4F:CA:03:17:EA:55:AE:FC:97:2B:18` |

> 這組 SHA-1/SHA-256 是這台電腦上 Flutter 預設的 **debug** 簽章（`~/.android/debug.keystore`），只能讓你在開發階段測試 Google 登入。正式上架前，還需要另外產生 **release** 簽章、算出它的 SHA-1/SHA-256，再加一組到 Firebase 主控台（這個之後在 Phase 7 上架準備時再處理，現在先不用管）。

---

## 1. 建立 Firebase 專案

1. 開啟 [console.firebase.google.com](https://console.firebase.google.com)，用你要拿來管理這個 App 的 Google 帳號登入。
2. 點「建立專案」（Add project / Create a project）。
3. 專案名稱建議直接叫 `food-app` 或你喜歡的名字（這只是 Firebase 內部顯示用，不影響 App 本身）。
4. 是否要開啟 Google Analytics：**可以直接關閉**（跟本計畫無關，之後隨時能再開），或保留預設也沒差。
5. 按「建立專案」，等個十幾秒它建好。

---

## 2. 新增三個平台的 App（Android / iOS / Web）

在專案總覽頁面，會看到一排平台圖示（Android、iOS、Web、Unity）。**這一步其實可以跳過**，因為等一下我會用 `flutterfire configure` 這個指令自動幫三個平台註冊 App、產生設定檔，不需要你在網頁上手動一個個加。

如果 `flutterfire configure` 過程中出問題，才需要回來這裡手動註冊，屆時會用到上面表格裡的 package name / bundle ID。

---

## 3. 啟用 Google 登入

1. 左側選單 → **Authentication**（驗證）。
2. 第一次進入會出現「開始使用」（Get started）按鈕，點下去。
3. 在 **Sign-in method**（登入方式）分頁，找到清單裡的 **Google**，點進去。
4. 右上角切成「啟用」（Enable）。
5. 「專案的公開名稱」隨意填（會顯示在使用者的 Google 登入同意畫面上），例如「美食通」。
6. 「專案支援電子郵件」選你自己的信箱。
7. 按「儲存」。

---

## 4. 建立 Firestore 資料庫

1. 左側選單 → **Firestore Database**。
2. 點「建立資料庫」（Create database）。
3. 位置（Location）選 **`asia-east1`（台灣）**——這個之後不能改，選錯要重建資料庫，務必選對。
4. 安全性規則模式：兩個選項（正式模式 / 測試模式）**選哪個都可以**，因為之後 Phase 7 會用 `firebase deploy` 部署我們自己寫好的規則檔案，把主控台這裡設的規則整個覆蓋掉。選「正式模式（Production mode）」比較保險（預設全部拒絕，不會有安全空窗期）。
5. 按「建立」。

---

## 5. 建立 Storage

1. 左側選單 → **Storage**。
2. 點「開始使用」（Get started）。
3. 安全性規則一樣選正式模式即可（理由同上，之後會被我們的規則檔覆蓋）。
4. 位置會自動跟 Firestore 一致（`asia-east1`），確認後按「完成」。

> 如果畫面上出現要求「升級付費方案」的提示：Storage 現在新專案有時會要求綁定帳單資訊（Blaze 方案）才能建立，即使用量在免費額度內也一樣要綁卡。這是 Google 近期的政策，如果遇到，綁定帳單卡片本身**不會馬上收費**，只有超過免費額度才會收費；免費額度對這個規模的 App 來說很難用完。如果你不想現在綁卡，也可以先跳過這步，等要測試上傳照片功能（Phase 4）前再回來設定。

---

## 6. 確認方案

左下角「升級」（Upgrade）旁邊會顯示目前方案。維持 **Spark（免費）方案**即可，除非上一步 Storage 要求你綁定 Blaze，那就照它的引導走（Blaze 是「用多少付多少」，免費額度內不收費，不是月租）。

---

## 7. 之後回報給我

完成以上步驟後，告訴我：
1. Firebase 專案名稱（或專案 ID，在主控台網址列或「專案設定」齒輪圖示裡看得到）
2. 上面第 5 步有沒有卡在要求綁定 Blaze 方案

我會接著在終端機跑：
```
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login
flutterfire configure
```
`firebase login` 跟 `flutterfire configure` 這兩步都會跳出瀏覽器要你用 Google 帳號登入/選專案/選平台，需要你在旁邊確認幾個提示視窗，其餘我可以直接處理。

---

## Phase 2：啟動本機唯讀餐廳資料

開發與測試餐廳列表時使用 Firebase Emulator，不會寫入正式 `food-9a095` 資料：

```powershell
firebase emulators:start --only auth,firestore,functions,storage
```

Emulator 啟動後，另開一個 PowerShell 視窗加入十種分類的測試店家、照片與評論：

```powershell
npm --prefix functions run seed:emulator
```

啟動 Flutter 並指定使用 Emulator：

```powershell
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_EMULATORS=true
```

種子腳本會檢查 `FIRESTORE_EMULATOR_HOST`；沒有啟動 Emulator 時會直接拒絕執行，避免誤寫正式 Firestore。

### Phase 3：模擬器定位

首頁會要求前景定位權限，並依距離搜尋店家；資料不足五筆時會自動把範圍從 3 公里擴大到 10、30 公里。Android Emulator 可先把位置設在台北市中心：

```powershell
adb -s emulator-5554 emu geo fix 121.53 25.04
```

若拒絕權限、關閉裝置定位或取得位置失敗，App 會顯示提示並自動改為最新店家列表。此階段只使用 GPS 與 geohash 查詢，不使用地圖 SDK 或 Maps API 金鑰。

### Phase 4：投稿、照片與收藏驗證

Phase 4 的店家、照片、收藏與合併測試仍只操作 Emulator。啟動 Emulator 並完成 seed 後，可執行：

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199'
$env:GCLOUD_PROJECT='food-9a095'
npm --prefix functions run test:emulator
npm --prefix functions run verify:phase4:emulator
```

新增店家每 24 小時最多 3 家、照片最多 20 張；單次最多選 5 張、每家累積最多 30 張。圖片會縮至最長邊 1600px 並轉成 JPEG quality 80。所有 callable 都要求登入、App Check、idempotency key，Storage 只接受有效 upload reservation 指定的路徑。

### Phase 5：評論、修正、檢舉與後台驗證

Phase 5 新增每位使用者每日最多 10 次評論操作、10 次資料修正及 10 次檢舉。評論採每人每店一筆，新增、編輯、刪除或下架評論時都會同步修正店家的 `ratingSum` 與 `ratingCount`；資料修正與檢舉必須由管理員審核。

管理員帳號須由 Firebase Admin SDK 或 Emulator 建立 `admins/{uid}` 文件，App 不允許使用者自行取得管理員權限。管理員登入後，可從「我的」頁進入「後台管理」。

本機驗證指令：

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:FIREBASE_STORAGE_EMULATOR_HOST='127.0.0.1:9199'
$env:GCLOUD_PROJECT='food-9a095'
npm --prefix functions run test:emulator
npm --prefix functions run verify:phase5:emulator
```

`verify:phase5:emulator` 會確認管理員可讀取待審清單、投稿者可讀取自己的申請，其他一般使用者無法讀取。

### Phase 6：Android AdMob 與 UMP

Android Debug 版目前使用 Google 官方測試 App ID、Banner ID 與 Interstitial ID，不會產生收益，也不會造成無效流量。Banner 固定顯示在底部導覽列上方；Interstitial 只會在新增店家成功後的自然轉場顯示。Web 使用空實作，不會初始化 Mobile Ads、載入廣告元件或顯示廣告。

每次啟動 Android App 時都會透過 UMP 更新同意狀態，完成必要表單後才初始化 Mobile Ads 並請求廣告。如果 AdMob 的隱私權訊息要求提供重新設定入口，「我的」頁會顯示「隱私權選項」。

Android 驗證：

```powershell
flutter build apk --debug --dart-define=USE_FIREBASE_EMULATORS=true
flutter run -d emulator-5554 --dart-define=USE_FIREBASE_EMULATORS=true
```

Web 隔離驗證：

```powershell
flutter build web --debug --dart-define=USE_FIREBASE_EMULATORS=true
```

上架前必須先在 AdMob 建立正式 App 與廣告單元、設定「隱私權與訊息」，再替換 `AndroidManifest.xml` 的測試 App ID，以及 `ad_units.dart` 的兩個測試廣告 ID。正式版禁止繼續使用測試 ID。

### Phase 7：安全性強化與部署準備

Phase 7 新增 Firebase Security Rules 單元測試、每日孤兒照片清理、Firebase Hosting SPA rewrite，以及公開的 `/account-deletion` 帳號刪除說明頁。目前只完成本機與 Emulator 驗證，尚未部署到 Firebase。

完整的 dev/prod 分離、App Check enforcement、預算警報、AdMob 正式 ID、部署順序與回復流程請依照：

```text
docs/deployment-checklist.md
```

Firebase 官方建議先觀察 App Check metrics；如果 App 已經有使用者，不應在 outdated requests 仍偏高時直接開 enforcement。Functions callable 已在程式層啟用 `enforceAppCheck`，Firestore、Storage 與 Authentication enforcement 則必須在 Firebase Console 個別開啟。

---

## 後期才需要：App 內地圖（Phase 10）

Phase 3 只實作 GPS、距離計算與列表排序，不加入地圖 SDK，也不需要申請 Maps API 金鑰。App 內地圖已延後到 Phase 10，屆時會先比較供應商、商用條款與成本後再選擇單一方案；目前「取得路線」只會開啟裝置外部地圖或瀏覽器導航。
