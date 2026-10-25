# 管吃 iOS 開發說明

iOS 版需要在 macOS 上建置。本文件記錄 iOS 專案的設定方式與本機開發流程；上架流程待 Apple Developer 帳號開通後補上。

## 開發環境

- Xcode（`xcode-select -p` 必須指向 `/Applications/Xcode.app/Contents/Developer`，不能是 Command Line Tools）
- iOS Simulator runtime：`xcodebuild -downloadPlatform iOS`
- Flutter：`brew install --cask flutter`
- CocoaPods：`brew install cocoapods`（不要用系統 Ruby 的 `gem install`）

## 專案設定

| 項目 | 設定 |
| --- | --- |
| Bundle ID | `com.misawa.food.foodApp`（iOS 不允許底線，因此與 Android 的 `com.misawa.food.food_app` 不同） |
| 最低版本 | iOS 15.0（Firebase iOS SDK 12 起的要求） |
| 裝置 | 僅 iPhone（`TARGETED_DEVICE_FAMILY = 1`） |
| 方向 | 僅直向 |
| 相依管理 | CocoaPods（`pubspec.yaml` 關閉 Swift Package Manager，原因見下方） |

### dev / prod flavor

與 Android 相同，iOS 以 `--flavor` 區分環境，Xcode 中有 `dev`、`prod` 兩個 scheme，以及 `Debug-dev`、`Release-prod` 等 build configuration。未指定 flavor 的 `Debug`/`Release` 等同 dev。

各 flavor 的原生設定在 `ios/Flutter/dev.xcconfig` 與 `ios/Flutter/prod.xcconfig`：

- `GOOGLE_CLIENT_ID`、`GOOGLE_REVERSED_CLIENT_ID`：注入 `Info.plist` 的 `GIDClientID` 與 Google 登入 URL scheme。
- prod 的 iOS App（`1:251427655696:ios:0fe11d5e990904e147fa95`）已於 2026-10-23 註冊；Dart 端設定在 `lib/firebase_options_prod.dart`。

App 內**不放** `GoogleService-Info.plist`。Firebase 由 Dart 的 `FirebaseOptions`（`lib/firebase_environment.dart`）初始化；而 Google 登入外掛會優先讀取 plist 的 `CLIENT_ID`，若 dev 的 plist 被打包進 prod build，就會用錯 client。之後執行 `flutterfire configure` 時，若它把 plist 加回 `ios/Runner/`，要再移除，只把 client ID 填進對應的 xcconfig。

### 為什麼用 CocoaPods

`firebase_core` 5 在 Swift Package Manager 下固定使用 Firebase iOS SDK 13（需要 `gtm-session-fetcher` 4–6），與 `google_sign_in_ios` 使用的 GoogleSignIn 9（需要 3.x）衝突。CocoaPods 路徑使用 Firebase 12.19，可以共存。`google_sign_in` 支援 GoogleSignIn 10 後，應改回 Swift Package Manager。

### google_mobile_ads 編譯設定

`google_mobile_ads` 9.1.0 的 header 引用了 GoogleMobileAds 的非 modular private header，因此 `ios/Podfile` 的 `post_install` 與 dev/prod xcconfig 都設定了 `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES`。外掛修正後可以移除。

iOS 第一版不顯示廣告（`Platform.isAndroid` 判斷）。`Info.plist` 的 `GADApplicationIdentifier` 是 Google 官方測試 ID，只是為了避免 SDK 在啟動時因缺少此值而 crash；之後 iOS 要放廣告時，必須換成正式 App ID，並加入 ATT 與 SKAdNetwork 設定。

## 本機開發

```bash
# 建置模擬器版本
flutter build ios --flavor dev --simulator --debug

# 連 dev Firebase 執行
flutter run --flavor dev

# 連 prod Firebase 執行
flutter run --flavor prod --dart-define=FIREBASE_ENV=prod

# 使用本機 Firebase Emulator（模擬器可直接連 localhost）
firebase emulators:start --only auth,firestore,functions,storage
npm --prefix functions run seed:emulator
flutter run --flavor dev --dart-define=USE_FIREBASE_EMULATORS=true
```

模擬器位置可在 Simulator 選單 **Features → Location → Custom Location** 設為台北（25.04, 121.53）。

### App Check debug token

debug build 使用 `AppleDebugProvider`。第一次執行時，從 `flutter run` 的輸出複製 App Check debug token，登記到要連線的專案的 App Check（App Check → Apps → iOS App → Manage debug tokens）。不得寫入原始碼、文件或 log。

模擬器不支援 App Attest，因此在模擬器上連 prod 時，必須把 debug token 登記到 prod。這個 token 可以繞過 App Check，要妥善保管；改用實機測試後，就從 prod 刪除。在模擬器上連 prod 新增的店家、照片與評論都是正式資料，測完要清除。

## 安裝到自己的 iPhone（免費 Apple ID）

尚未加入付費 Apple Developer Program 時，可以用免費 Apple ID 的 Personal Team 安裝到自己的 iPhone；App 在 7 天後失效，需要重新安裝。

- Xcode 的 Signing & Capabilities 只設定 Team，不要套用「Update to recommended settings」，它會把最低版本改掉，導致 Pods 建置失敗。
- 建置一律用終端機的 `flutter run`，不要在 Xcode 按 ▶（Xcode 不會先準備實機用的 Flutter 引擎）。
- debug 版在 iOS 14+ 不能從主畫面啟動，因此個人測試用 release 版。

免費帳號不能使用 App Attest，而 Cloud Functions 強制要求 App Check。為了在 release 版通過 App Check，可以帶入固定的 debug token：

1. 在專案根目錄建立 `app_check_debug.local.json`（已列入 `.gitignore`，不可提交）：
   ```json
   {
     "FIREBASE_APP_CHECK_APPLE_DEBUG_TOKEN": "<已登記在 Firebase App Check 的 iOS debug token>"
   }
   ```
2. 建置 release 版並安裝到接上傳輸線的 iPhone：
   ```bash
   flutter build ios --release --flavor prod --dart-define=FIREBASE_ENV=prod \
     --dart-define-from-file=app_check_debug.local.json
   xcrun devicectl device install app --device <iPhone 名稱> build/ios/iphoneos/Runner.app
   ```
   不要用 `flutter run --release --flavor prod`：使用 flavor 時它會到 `build/ios/iphoneos/` 找 App，但實際產物在 `build/ios/Release-prod-iphoneos/`，因此安裝失敗。

**上架（TestFlight / App Store）的版本絕對不能帶 `--dart-define-from-file=app_check_debug.local.json`**，否則 token 會被包進 App。付費帳號開通並改用 App Attest 後，就不再需要這個檔案。

## 待 Apple Developer 帳號開通後

- 在 Xcode 的 Signing & Capabilities 設定 Team，加入 Sign in with Apple 與 App Attest
- Firebase（dev、prod）啟用 Apple 登入 provider，並在 App Check 註冊 iOS App
- TestFlight 上架流程
