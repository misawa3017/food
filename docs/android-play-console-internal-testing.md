# 管吃 Android：Play Console 內部測試流程

本文件記錄將「管吃」Android 版送進 Google Play 內部測試的步驟。內部測試不會公開給一般 Play 商店使用者。

## 目前完成的設定

- Application ID：`com.misawa.food.food_app`
- 正式 Firebase 專案：`food-prod-9a095`
- Android 原生顯示名稱：`管吃`
- 正式簽章 alias：`guanchi-upload`
- Firebase 已登記 upload key 的 SHA-1 與 SHA-256 指紋。
- `android/key.properties` 與 `.jks` 均已被 Git 忽略，絕不能提交或分享。

## 私密簽章檔案

簽章檔存放於本機：

```text
C:/Users/jason/guanchi-keys/guanchi-upload.jks
```

`android/key.properties` 只存在本機，格式如下：

```properties
storePassword=<keystore 密碼>
keyPassword=<key 密碼>
keyAlias=guanchi-upload
storeFile=C:/Users/jason/guanchi-keys/guanchi-upload.jks
```

密碼不得加上引號。請將 `.jks` 與密碼保存在獨立、安全的備份位置；遺失後將無法更新已上架的 App。

## 建立正式 AAB

在專案根目錄執行：

```powershell
& 'C:\Users\jason\flutter\flutter_windows_3.29.3-stable\flutter\bin\flutter.bat' build appbundle --flavor prod --release --dart-define=FIREBASE_ENV=prod
```

產物路徑：

```text
build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

每次要上傳新版時，先把 `pubspec.yaml` 的版本號遞增，例如從 `1.0.0+1` 改成 `1.0.0+2`。Google Play 不接受相同 `versionCode` 的第二次上傳。

## 申請 Google Play 開發人員帳戶

1. 開啟 <https://play.google.com/console>，以擁有此 App 的 Google 帳號登入。
2. 依流程支付開發人員帳戶費用並完成 Android 開發人員身分驗證。
3. 驗證時確認法定全名、法定地址與網站資料均正確。

## 建立管吃 App

1. 在 Play Console 點選「建立應用程式」。
2. 預設語言選「繁體中文」。
3. 名稱填「管吃」，類型選「應用程式」，價格選「免費」。
4. 填入聯絡 Email，接受政策與出口聲明後建立。
5. 第一次上傳 AAB 時接受 **Play App Signing**，建議由 Google 管理 app signing key；本機 `guanchi-upload` 金鑰是 upload key。

## 建立內部測試版本

1. 左側選單進入「測試」→「內部測試」。
2. 在「測試人員」加入測試帳號，例如 `misawa3017@gmail.com`。
3. 點選「建立新版本」，上傳 `app-prod-release.aab`。
4. 版本名稱可填 `1.0.0-internal.1`，版本資訊填「首次內部測試」。
5. 儲存、檢查版本，選擇「開始推出內部測試」。
6. 複製測試加入連結，用測試帳號在 Android 手機上開啟、加入測試後從 Play 商店安裝。

內部測試最多可加入 100 位測試者；測試版本通常幾分鐘可用，首次建立偶爾需要較久。

## 上傳後必做：加入 Play App Signing 指紋

從 Play Console 進入「設定」→「應用程式完整性」，複製 **App signing key certificate** 的 SHA-1 與 SHA-256。

在 Firebase Console：`food-prod-9a095` → 專案設定 → 一般 → Android App → SHA 憑證指紋，將這兩組指紋新增進去。

不要刪除原本 upload key 的指紋。從 Play 商店安裝的 App 是以 Google 的 app signing key 簽署；缺少這兩組指紋時，Google 登入與 App Check 可能無法正常運作。

## 實機測試清單

- 從 Play 商店的內部測試頁安裝，而非直接安裝 APK。
- Android 桌面名稱顯示為「管吃」。
- Google 登入、登出與重新登入正常。
- 定位權限、附近店家與搜尋正常。
- 新增店家、照片壓縮與照片上傳正常。
- 收藏、資料修正與管理員功能正常。
- App Check 沒有 `unauthenticated`、`permission-denied` 或 Play Integrity 相關錯誤。
- AdMob 仍為測試廣告；正式公開前才改用正式 Android 廣告單元。

## 參考資料

- [Google Play：建立及設定應用程式](https://support.google.com/googleplay/android-developer/answer/9859152)
- [Google Play：設定內部、封閉或開放測試](https://support.google.com/googleplay/android-developer/answer/9845334)
