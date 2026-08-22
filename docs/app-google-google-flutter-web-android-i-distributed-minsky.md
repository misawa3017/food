# 美食介紹 APP — Flutter + Firebase 開發計畫

## Context

使用者想開發一款**免費、靠 Google 廣告營利**的美食介紹 APP，用 Flutter 開發以支援 **Android、iOS、Web** 三平台。核心需求：
- 使用者可**免登入瀏覽/搜尋**資料庫中的美食（依 GPS 距離排序 或 關鍵字搜尋）
- 需**先登入**才能上傳照片、推薦美食（新增餐廳）；Android/Web 提供 Google 登入，iOS 同時提供同等醒目的 Google 登入與 Sign in with Apple
- 登入後可以把喜歡的餐廳加入**我的最愛**，餐廳頁面公開顯示收藏數
- 登入後可以針對店家**留言評論**（含 1~5 星評分），每人每店限一則，可編輯/刪除自己的留言；餐廳的平均星等就是由此聚合而來
- 上傳的內容需要基本的內容審核機制（檢舉 + 後台下架），留言/評論也適用同一套機制
- 新增餐廳前先做**重複店家偵測**，使用者可回報重複店家，管理員可將資料合併並保留舊連結導向
- 使用者可提出**店家資料修正**（名稱、地址、座標、營業狀態等），由管理員審核後套用並保留修改紀錄
- 登入使用者可在 App 內要求**刪除帳號與關聯資料**，並提供 Web 刪除申請入口以符合商店政策
- 以 **Firebase App Check + 伺服器端投稿限流**保護 Firestore、Storage 與 Cloud Functions，限制大量新增店家、照片、評論與檢舉
- 廣告：目前先做 **Android/iOS（AdMob）**，Web 廣告（AdSense）延後到未來階段

目前工作目錄是全新空白的，尚未建立任何 Flutter 專案或 Firebase 設定，屬於從零開始的專案。此計畫確立技術選型與分階段的建置順序，讓後續可以逐步、可驗證地實作。

---

## 技術選型

| 項目 | 選擇 | 理由 |
|---|---|---|
| 後端 | **Firebase**（Firestore + Storage + Auth + Cloud Functions + App Check） | 免自建伺服器；一般查詢仍由 Firestore 處理，帳號刪除、店家合併、投稿限流等高權限操作集中在可信任的 Functions |
| 登入 | **Google Sign-In + Sign in with Apple** | Android/Web 以 Google 為主；iOS 提供 Apple 等價登入，Firebase Auth 統一管理身分並處理同信箱帳號連結 |
| 狀態管理 | **Riverpod** | 本 App 本質是「訂閱 Firestore 資料流 → 渲染列表/詳情」，`StreamProvider`/`AsyncNotifier` 與此模式高度契合，且方便搭配 Firebase Emulator 測試 |
| 路由 | **go_router** | Web 需要真實可分享網址（如 `/restaurant/abc123`），且方便做登入攔截導頁（`/upload`、`/admin` 未登入時導去登入頁） |
| 資料模型 | **以餐廳（店家）為單位**，內含推薦菜色欄位 | 符合使用者選擇；貼近 Google 地圖的使用習慣 |
| 地理搜尋 | 手刻 geohash bounding-box（`dart_geohash`）+ 前端 Haversine 排序 | Firestore 原生不支援半徑查詢；不依賴維護狀態不確定的第三方套件 |
| 地圖檢視 | **MVP 不整合，列入上線後 Phase 10** | 前期只提供附近列表與外部導航，避免地圖 SDK、三平台設定與圖磚費用影響核心需求驗證；後期再依流量評估 `flutter_map + MapTiler`、MapLibre 或 Google Maps |
| 廣告 | `google_mobile_ads`（AdMob，僅 Android/iOS） | 依使用者決定，Web 廣告位置先保留版位但不啟用 |

---

## Firebase 專案設定

1. 於 [console.firebase.google.com](https://console.firebase.google.com) 建立專案，Firestore/Storage 區域選 `asia-east1`
2. Authentication → 啟用 **Google** 與 **Apple** 登入方式；Apple 需設定 Apple Developer Team ID、Service ID、Key ID 與私密金鑰，私密金鑰只放 Firebase/CI secret，不進入 App 或 Git
3. Firestore：Native mode，production 模式（規則另外部署）
4. Storage：同區域啟用
5. 升級 **Blaze（隨用隨付）方案**：Cloud Storage for Firebase 已要求 Blaze；同時設定預算警報與 API quota。Cloud Functions 僅用於帳號刪除、投稿限流、照片上傳預約、資料修正套用與店家合併
6. 安裝必要 CLI（此機器目前尚未安裝）：
   ```
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools
   firebase login
   ```
7. 於 Flutter 專案根目錄執行 `flutterfire configure`，選擇 android/ios/web 三平台，產生 `lib/firebase_options.dart`
8. Android：需將 debug/release 的 SHA-1/SHA-256 加入 Firebase 主控台（Google 登入必要）
9. iOS：確認 `GoogleService-Info.plist` 的 `REVERSED_CLIENT_ID` 已加入 `Info.plist` 的 URL scheme
10. iOS：啟用 Sign in with Apple capability；AuthRepository 使用隨機 nonce 完成 Apple OAuth，若同信箱已存在 Google 帳號則引導使用者完成 provider linking，避免產生兩個 App 帳號
11. Web：Authentication → Authorized domains 加入 `localhost` 及未來正式網域；部署公開的帳號刪除申請頁
12. **Firebase App Check**：Android 使用 Play Integrity、iOS 使用 App Attest（不支援時 fallback DeviceCheck）、Web 使用 reCAPTCHA Enterprise；開發/Emulator/CI 使用 debug provider。先觀察 metrics，再依序對 Firestore、Storage、Authentication 與 Functions 開啟 enforcement

**MVP 地圖範圍**：前期不申請、不設定任何 App 內地圖 SDK 或圖磚服務。`geolocator`、geohash 與 Haversine 仍用於附近距離排序；「取得路線」只以 `url_launcher` 開啟裝置既有的 Google Maps、Apple Maps 或瀏覽器導航頁，不在 App 內渲染地圖。地圖供應商、金鑰、帳單與 Map Ad 策略統一延後到 Phase 10 決定。

**注意**：此開發機是 Windows，iOS 實機/模擬器建置測試需要 Mac 或 macOS CI（如 Codemagic/GitHub Actions macOS runner）。依照分階段建置順序，這在進到 **Phase 8（iOS 帶入）** 前準備即可，不影響前期 Android/Web 開發。

---

## 專案結構（Flutter, feature-first）

```
lib/
  main.dart / app.dart / firebase_options.dart
  core/
    theme/ router/app_router.dart
    constants/food_categories.dart   // 固定分類清單，搜尋篩選與上傳表單共用同一份
    utils/geo_utils.dart        // geohash bbox + haversine 排序
    utils/image_utils.dart      // 上傳前壓縮
    services/app_check_service.dart
    widgets/ (restaurant_card, banner_ad_slot, loading/error/empty states)
  data/
    models/ (restaurant, restaurant_photo, report, app_user, restaurant_edit_request, restaurant_merge_request, contribution_limit)
    repositories/ (restaurant_repository, auth_repository, account_repository, report_repository, storage_repository, admin_repository, favorite_repository, review_repository, restaurant_correction_repository, contribution_repository)
    providers/ (auth_providers, restaurant_providers, report_providers, favorite_providers, review_providers, correction_providers, contribution_providers)
  features/
    auth/ (login_screen, account_linking_screen)
    home/home_screen.dart              // 附近
    search/
      search_screen.dart               // 附近/關鍵字 切換
      search_list_view.dart
      // search_map_view.dart 延後到 Phase 10 建立
    restaurant_detail/ (detail, photo_gallery, report_dialog, review_section, review_form_sheet)
    upload/ (add_restaurant_screen, photo_picker_field, location_input_field)
    profile/ (my_page_screen, delete_account_dialog)
    restaurant_correction/ (suggest_edit_sheet, duplicate_restaurant_sheet)
    admin/ (admin_screen, admin_guard, edit_request_queue, merge_request_queue)
firebase/
  firebase.json / firestore.rules / firestore.indexes.json / storage.rules
functions/
  src/ (contribution_limits, photo_upload, account_deletion, restaurant_correction, restaurant_merge)
```

MVP 主要套件：`firebase_core/auth/firestore/storage/functions/app_check`、`google_sign_in`、`sign_in_with_apple`、`go_router`、`flutter_riverpod`、`geolocator`、`dart_geohash`、`image_picker`、`image`（跨平台壓縮，含 Web）、`google_mobile_ads`、`cached_network_image`、`url_launcher`。**前期不安裝** `google_maps_flutter`、`flutter_map`、MapLibre 或任何圖磚 SDK；Phase 10 決定供應商後才加入單一地圖 dependency。

**實作調整（Phase 0 執行時）**：`riverpod_generator`/`freezed`/`json_serializable`/`build_runner` 這組 code-gen 工具鏈目前版本間互相衝突（`riverpod_generator` 最新版需要比目前 Dart SDK 更新的版本，退回舊版又跟 `json_serializable`/`freezed` 的 `analyzer`/`source_gen` 依賴對不上），改為**不使用程式碼產生器**：Riverpod provider 手寫（`StreamProvider`/`Provider`/`NotifierProvider`），資料模型手寫 `fromJson`/`toJson`。對這個專案規模來說程式碼量差異不大，且免除 build_runner 的維護負擔與版本相容風險。

---

## Firestore 資料結構

```
restaurants/{id}
  name, nameLower, nameNormalized, address, geo{lat,lng}, geohash
  categories[]          // 只能是固定清單中的值（見下方），上傳時多選、非自由輸入
  recommendedDishes[]
  coverPhotoUrl, photoCount, ratingSum, ratingCount, reportCount   // photoCount 上限 30；平均星等 = ratingSum/ratingCount，由 reviews 聚合而來
  favoriteCount                                                    // 公開收藏數，見下方安全規則
  status: "active" | "removed" | "closed" | "merged"
  mergedIntoRestaurantId?   // status == merged 時必填；舊網址開啟後導向保留中的店家
  createdBy, createdAt, updatedAt

restaurants/{id}/photos/{photoId}
  url, storagePath, uploadedBy, createdAt, status, reportCount

restaurants/{id}/reviews/{uid}   // 文件 ID 直接用留言者的 uid，天然強制「每人每店限一則」
  rating              // 1~5 整數
  text
  authorUid           // 必須與文件 ID 及 request.auth.uid 相同，供帳號刪除 collection group 查詢
  authorName, authorPhotoUrl   // 反正規化，列表渲染不用再查 users
  status: "active" | "removed"
  reportCount
  createdAt, updatedAt

users/{uid}
  displayName, photoURL, email, providerIds[], accountStatus, createdAt, uploadCount
  // 不存 isAdmin 欄位在自己的文件（避免使用者自行竄改）

users/{uid}/favorites/{restaurantId}   // 子集合，僅本人可讀寫
  addedAt
  // 輕量反正規化欄位，讓「我的最愛」清單不需逐筆再查 restaurants：
  restaurantName, restaurantCoverPhotoUrl, restaurantCategories

admins/{uid}   // 純標記文件，僅由主控台/管理者手動建立，前端完全禁止寫入

reports/{id}
  targetType: "restaurant"|"photo"|"review", targetId, restaurantId
  reason, note?, reportedBy, createdAt
  status: "pending"|"dismissed"|"actioned", reviewedBy?, reviewedAt?

restaurantEditRequests/{id}
  restaurantId, proposedChanges{name?,address?,geo?,categories?,recommendedDishes?,status?}
  reason, submittedBy, submittedAt
  status: "pending"|"approved"|"rejected"
  reviewedBy?, reviewedAt?, rejectionReason?
  beforeSnapshot?, appliedChanges?   // 審核紀錄與回復依據

restaurantMergeRequests/{id}
  sourceRestaurantId, targetRestaurantId, reason, submittedBy, submittedAt
  status: "pending"|"approved"|"rejected"
  reviewedBy?, reviewedAt?, mergeSummary?

contributionUsage/{uid}
  windowStartedAt, restaurantCreateCount, photoUploadCount
  reviewWriteCount, reportCreateCount, editRequestCount
  lastActionAt, blockedUntil?, updatedAt
  // 僅 Cloud Functions 可寫；採滾動 24 小時視窗

systemConfig/contributionLimits
  restaurantCreatePerDay, photoUploadPerDay, reviewWritePerDay
  reportCreatePerDay, editRequestPerDay, minimumActionIntervalSeconds
  // 僅管理員可寫，Functions 讀取；預設值分別為 3、20、10、10、10、10 秒

accountDeletionRequests/{id}
  uid, requestedAt, source: "app"|"web"
  status: "requested"|"processing"|"completed"|"failed"
  completedAt?, errorCode?

uploadReservations/{id}
  uid, restaurantId, storagePath, expiresAt, status: "reserved"|"consumed"|"expired"
  // requestPhotoUpload 建立；Storage Rules 驗證後才允許上傳指定路徑
```

需要的複合索引：`status+geohash`、`status+nameLower`、`status+categories+createdAt`、`status+createdAt`、`restaurantEditRequests(status+submittedAt)`、`restaurantMergeRequests(status+submittedAt)`。

**固定分類清單**（`lib/core/constants/food_categories.dart`，搜尋篩選 chip 與上傳表單多選共用同一份常數，避免同義詞/打法不一致）：
`小吃`、`日式`、`韓式`、`中式`、`西式`、`東南亞料理`、`火鍋`、`燒烤`、`甜點`、`飲料`。
不含「餐廳」——所有項目本來就是店家，用具體料理類型分類才有篩選意義。這份清單之後如果要增減分類，需要同步處理既有資料的遷移，因此上線前務必先跟使用者確認清單夠用。

---

## 安全規則重點

- **App Check**：App 啟動時在 `Firebase.initializeApp()` 後、使用其他 Firebase 服務前啟用。正式環境 enforcement 涵蓋 Firestore、Storage、Authentication 與 callable Functions；Emulator/CI 僅使用已註冊的 debug token，debug token 不得提交到 Git
- 所有 callable Functions 都必須同時驗證 `context.auth`、有效 App Check token、輸入 schema、帳號 `blockedUntil` 與投稿配額；使用 Admin SDK 的 Functions 會繞過 Security Rules，因此驗證不能只依賴前端或 Rules
- `restaurants`/`photos`：列表只公開讀取 `status == active`；指定文件 `get` 可讀 `status == merged`，讓舊網址取得 `mergedIntoRestaurantId` 後導向保留店家
- 新增店家、建立照片 metadata、寫入評論、送出檢舉、資料修正與合併申請都透過 callable Functions；前端不可直接建立這些文件，Functions 負責填入呼叫者 `uid`、server timestamp、限流計數與必要聚合欄位
- 一般使用者**不能修改/刪除**已存在的餐廳核心欄位（名稱/地址/座標/狀態）；只能送出 `restaurantEditRequests`。核准修正、下架、標記停業與合併都僅能由管理員呼叫對應 Function
- `users/{uid}/favorites/{restaurantId}`：**只有本人**（`request.auth.uid == uid`）可讀寫，其他人完全不能存取
- `restaurants/{id}.favoriteCount`：前端收藏/取消收藏仍使用 Firestore transaction，同時寫入 favorite 文件與更新計數；Rules 使用 `getAfter()` 驗證 favorite 文件的新增/刪除與 `favoriteCount` 的 ±1 是同一 atomic operation，且其他餐廳欄位未變更
- `restaurants/{id}/reviews/{uid}`：公開讀取僅限 `status == active`；文件 ID 固定為作者 uid。`submitReview` Function 驗證 1~5 整數、每人每店一則、限流與文字長度，並在同一 transaction 維護 `ratingSum`/`ratingCount`
- `reports`：只能透過 `submitReport` Function 建立，同一使用者不得對同一目標建立未結案的重複檢舉；只有管理員可讀取全部與更新狀態
- `contributionUsage`、`systemConfig`、`accountDeletionRequests` 與 `uploadReservations` 禁止客戶端直接寫入；`restaurantEditRequests`/`restaurantMergeRequests` 的建立與狀態變更也分別由投稿 Function／管理員 Function 處理
- 管理員身分透過獨立的 `admins/{uid}` 標記文件判斷（`exists()` 規則），**前端完全不能寫入**此集合，只能由你手動在主控台新增
- Storage：需登入且 App Check 有效，限制檔案 5MB 內、MIME type 為圖片；只能上傳至 `requestPhotoUpload` 預先核發、屬於本人且尚未過期的 `storagePath`。刪除照片與孤兒檔案清理由 Functions 執行
- **投稿限流**：Functions 使用 transaction 更新 `contributionUsage/{uid}` 的滾動 24 小時視窗；超過 `systemConfig/contributionLimits` 或未達最小操作間隔時回傳 `resource-exhausted` 與 `retryAfter`，UI 顯示剩餘等待時間。管理員可設定 `blockedUntil` 暫停投稿，但不影響公開瀏覽與帳號刪除
- **帳號刪除**：必須在近期重新驗證登入後才能呼叫；Function 撤銷 Apple token（若有）、刪除 favorites、將評論與照片下架並移除 Storage 物件、匿名化必須保留的審核紀錄，最後刪除 `users/{uid}` 與 Firebase Auth 帳號。流程可重試且具 idempotency，避免執行中斷留下半刪除狀態

---

## 核心畫面/流程

- **底部導覽 4 tab**：附近(Home) / 搜尋(Search) / 新增(+) / 我的(My)
- **HomeScreen**：取得 GPS 權限成功 → 依距離排序附近餐廳列表；拒絕/失敗 → fallback 依建立時間排序，並顯示提示 banner
- **SearchScreen**：MVP 只提供列表模式，可切換「附近／關鍵字」搜尋；關鍵字用 `nameLower` prefix 查詢 + 分類篩選，附近模式依 GPS 距離排序。列表／地圖切換與 Marker 互動延後到 Phase 10
- **RestaurantCard**（Home/Search 共用列表項目）：除了點卡片進入詳情頁，卡片上放「取得路線」與「收藏愛心」兩個快捷圖示；取得路線使用 `url_launcher` 開啟裝置外部地圖／瀏覽器導航，不初始化 App 內地圖。未登入時點收藏觸發登入；登入後樂觀更新收藏狀態
- **RestaurantDetailScreen**：封面圖+照片牆、分類標籤、推薦菜色、公開的「❤️ 收藏數」與「★ 平均星等（reviews 數量）」、「取得路線」、收藏愛心、「+新增照片」、留言評論區；取得路線同樣只開外部導航。更多選單提供「建議修改資料」、「回報停業」與「回報重複店家」。若讀到 `status == merged`，自動 replace route 至 `mergedIntoRestaurantId` 並顯示一次合併提示
- **LoginScreen**：Android/Web 顯示「使用 Google 登入」；iOS 同時顯示同等醒目的 Google 與 Apple 登入按鈕。登入後導回原本要做的動作；遇到同信箱不同 provider 時進入安全的帳號連結流程，不自動合併未驗證帳號
- **AddRestaurantScreen**（登入才能進入）：名稱、地址、目前位置按鈕、分類多選、推薦菜色、封面照與多張照片上傳；MVP 以 GPS 取得座標或手動輸入地址，不提供互動地圖選點。輸入名稱與座標後先查詢 `nameNormalized` 與附近 geohash，顯示可能重複店家；使用者可選擇前往既有店家補資料，或確認「不是同一家」後繼續
- **MyPageScreen**：個人資料、**我的最愛**、自己上傳的紀錄、資料修正申請紀錄、登出，以及「刪除帳號與資料」。刪除前說明影響、要求近期重新登入並二次確認；若是管理員才顯示「後台管理」入口
- **AdminScreen**（透過 `admins/{uid}` 判斷是否可進入）：以分頁顯示待處理檢舉、資料修正與重複店家申請；可下架／忽略、核准／拒絕修正、合併店家，並留下 reviewer、時間與 before/after audit log

「以基本反應式審核（使用者檢舉 + 後台人工下架）」取代事前審核佇列 — 內容上傳後立即公開，符合使用者決定，也大幅簡化實作；這套機制同樣涵蓋餐廳、照片、留言評論三種內容。後台管理直接做成 App 內的一個路由（而非只靠 Firebase 主控台手動操作），因為下架動作需要同時更新「檢舉紀錄狀態」與「內容 status」兩筆資料，用主控台手動做容易出錯。留言被下架（`status` 改為 `removed`）時，同一筆 transaction 也要把 `ratingSum`/`ratingCount` 扣掉，避免下架的留言仍計入平均分。

### 重複店家與資料修正流程

1. 新增店家時，以 `nameNormalized`、地址文字與 200 公尺內座標產生候選清單；這只是提示，不因同名直接阻擋，避免連鎖店被誤判
2. 回報重複時必須選擇「來源店家」與「保留店家」並填寫原因；同一組合只允許一筆 pending 申請
3. 管理員核准合併後，把來源店家標記為 `merged` 並寫入 `mergedIntoRestaurantId`；Function 將不衝突的推薦菜色與照片移到保留店家，評論若同一使用者兩邊都有則保留較新的有效評論，再重新計算照片數與評分聚合
4. favorites 不大量搬移；MyPage 讀到 merged 店家時導向保留店家並以 transaction 更新該使用者的 favorite。舊餐廳網址永久保留導向，避免分享連結失效
5. 資料修正申請只保存允許修改的欄位；管理員核准時 Function 重新驗證內容、保存 before snapshot、套用變更並記錄 audit log。座標變更時必須同步重算 geohash

### 投稿限流與錯誤體驗

- 預設滾動 24 小時上限：新增店家 3 家、照片 20 張、評論新增/編輯 10 次、檢舉 10 次、資料修正/重複申請合計 10 次；所有投稿最短間隔 10 秒
- 限制值放在 `systemConfig/contributionLimits`，只供 Functions 當作可信任設定；前端可讀公開副本顯示提示，但不可用 Remote Config 或前端值作為安全判斷
- 超限時保留使用者已輸入的表單草稿，顯示可再次投稿的時間；網路重試需攜帶 idempotency key，避免相同內容重複建立
- 管理員封鎖投稿時必須填寫原因與期限；使用者仍可登入、瀏覽、匯出或刪除自己的資料

### 帳號刪除流程

1. App 內與公開 Web 頁都提供刪除申請；App 內要求 Google/Apple 重新驗證，Web 透過登入後送出申請
2. 建立 `accountDeletionRequests` 後立即停用投稿，背景 Function 依序清除 favorites、評論、照片與 Storage 物件，並匿名化依法或為防濫用必須短期保留的 audit log
3. 刪除 Apple 登入帳號時先撤銷 Apple authorization token，再刪除 Firebase Auth user；若中途失敗可從 request status 繼續，不重複扣除聚合數值
4. 完成後寄送或顯示刪除結果；隱私權政策需明確說明刪除範圍、處理時間與必要保留資料

---

## AdMob 整合（僅 Android/iOS）

- 版位：Home/Search 列表下方 anchored banner，列表每 ~8 筆插入一個 inline banner；Interstitial 在自然斷點（如成功新增餐廳後、瀏覽數家詳情後）最多每個 session 顯示一次，絕不擋在使用者操作進行中
- Android `AndroidManifest.xml` 加 `APPLICATION_ID` meta-data；iOS `Info.plist` 加 `GADApplicationIdentifier`、`SKAdNetworkItems`，並用 `app_tracking_transparency` 套件在 iOS 請求 ATT 權限（個人化廣告前置需求）
- 需整合 Google **UMP（User Messaging Platform）** 同意流程
- 開發期間全程使用 Google **測試廣告 ID**，正式上架前才切換成正式 ID（避免誤觸發廣告帳號風險）
- Web 版的廣告版位（`BannerAdSlot`）先用空 widget 占位，明確標記為未來 AdSense 階段要做的事，本階段**不實作**

---

## 圖片上傳流程

1. `image_picker` 選圖（相機/相簿），單次最多選 5 張
2. 用 `image` 套件在前端壓縮（最長邊縮到約 1600px、JPEG quality ~80），此套件跨平台含 Web，避免原生壓縮套件在 Web 上的相容問題
3. 呼叫 `requestPhotoUpload`；Function 驗證 App Check、投稿限流與該餐廳 `photoCount < 30`，為每張圖片建立短效 `uploadReservations` 並回傳唯一 Storage path
4. 只允許上傳到 reservation 指定的 `restaurant_photos/{restaurantId}/{uploadId}.jpg`，顯示上傳進度；Storage Rules 驗證 uid、path、有效期限、大小與 MIME type
5. 上傳完成後呼叫 `finalizePhotoUpload`；Function 確認物件存在且 reservation 未使用，在 transaction 中建立 photo 文件、遞增 `photoCount`、必要時設定 `coverPhotoUrl`，最後將 reservation 標記為 consumed
6. 預約過期或 finalize 失敗的孤兒物件由排程 Function 清理；同一 idempotency key 重試不得重複計數
7. 每家餐廳照片總數上限 30 張，所有使用者累積計算；達上限或個人每日配額時 UI 顯示具體原因與可重試時間
8. 顯示圖片一律用 `cached_network_image`

---

## 地理搜尋實作細節

**「附近」模式**：
1. `geolocator` 取得目前位置（先處理權限流程與拒絕情境）
2. 以使用者座標算出對應半徑（先抓 3km）的 geohash bounding box 及其鄰近格子（約至多 9 格）
3. 對每格用 `where('geohash', >=, start).where('geohash', <=, end)` 各發一次查詢（加上 `status==active`），合併去重
4. 用 `Geolocator.distanceBetween` 算精確距離，過濾掉超出半徑的（geohash 格子是方形不是圓形，需二次過濾），依距離排序
5. 結果太少時（<5筆）逐步擴大半徑（3km→10km→30km），有上限避免無限查詢

**「關鍵字」模式**：用 `nameLower` 做前綴比對查詢（Firestore 沒有原生全文搜尋），搭配 `categories` 的 `array-contains` 篩選、`.limit()` + cursor 分頁。若未來需要更強的模糊/全文搜尋，可考慮 Algolia/Typesense，但**非本階段需求**。

---

## 分階段建置順序

**平台優先順序：Android → Web → iOS。** 每個功能 Phase（0～7）都先在 Android 與 Web 上開發、測試、驗收，iOS 完全不參與這些 Phase 的驗證。等 Android + Web 的功能都做完、穩定後，才在 Phase 8 一次把整個 App 帶上 iOS（同步補上 iOS 專屬設定並驗證所有既有功能）。好處：這台開發機是 Windows，前期完全不受「沒有 Mac」卡關；Mac/macOS CI 只需要在最後 iOS 階段才準備。

0. **專案骨架**：`flutter create`、資料夾結構、加入套件依賴、建立 `functions/` TypeScript 專案 → 驗證：`flutter run -d chrome` 能看到 4-tab 空殼，Android emulator 也能跑起來；Functions emulator 可啟動
1. **Firebase + 登入 + App Check 骨架**：`flutterfire configure`、Google 登入串接、auth provider、路由攔截；加入 App Check 並在開發環境使用 debug provider；先建立帳號刪除 UI 與 callable Function 的 emulator 流程 → 驗證：Chrome、Android emulator 登入登出、重新驗證與刪除測試帳號皆正常，未帶 App Check token 的 Function 請求被拒絕
2. **唯讀瀏覽/搜尋（用種子資料）**：`food_categories.dart` 固定分類清單、Firestore models/repositories、手動塞幾筆涵蓋各分類的餐廳種子資料、Home（先不做地理排序）、Search 關鍵字模式 + 分類篩選 chip、詳情頁 → 驗證：對照 `firebase emulators:start`，Chrome + Android 都跑一次
3. **地理搜尋（列表模式）**：實作 `geo_utils.dart`，串進 Home 與 Search 的「附近」模式；處理 GPS 權限、3km→10km→30km 擴大半徑、精確距離過濾與列表排序。此階段不安裝地圖 SDK、不申請地圖金鑰、不實作 Marker → 驗證：用已知座標的種子資料確認排序、半徑與 fallback 正確（Chrome + Android）
4. **上傳流程 + 重複處理 + 我的最愛**：新增餐廳表單、`nameNormalized`/附近座標重複候選、照片壓縮、upload reservation/finalize Functions（含每店 30 張上限）；實作重複店家申請與管理員合併流程；同時實作收藏功能與 merged favorite 自動導向 → 驗證：先在 emulator 端到端測試，再在真實 dev Firebase 專案測試；確認連鎖店不被錯誤阻擋、合併後舊連結可導向、照片及聚合數值正確，收藏/取消收藏重整後仍保留（Chrome + Android）
5. **留言評論 + 資料修正 + 檢舉審核與限流**：留言 CRUD 與評分聚合改由 Function transaction 處理；完成資料修正申請/審核、檢舉、後台下架/忽略；所有投稿 Function 共用 `contributionUsage` 限流與 idempotency → 驗證：下架內容從公開查詢消失，留言新增/編輯/刪除/下架後平均星等正確；超限回應包含 `retryAfter`，重送同一 idempotency key 不產生重複資料（Chrome + Android）
6. **AdMob（先 Android）**：banner/interstitial（測試 ID）、Android 平台設定（`AndroidManifest.xml`）、UMP 同意流程 → 驗證：Android 上廣告版位正常顯示、確認 Web build 沒有廣告相關元件或錯誤
7. **安全性強化 + 部署（Android + Web）**：正式部署 Functions、`firestore.rules`/`storage.rules`/索引；App Check 先觀察 metrics 再開 enforcement；建立 dev/prod 專案、預算警報、孤兒圖片清理排程與公開帳號刪除申請頁；Web build 上架準備、Play Console 內部測試
8. **iOS 帶入**：安裝/確認 macOS 開發環境（實機或 CI），`flutterfire configure` 補上 iOS app、Sign in with Apple capability 與 Firebase Apple provider、App Attest/DeviceCheck、Google 登入 URL scheme、AdMob/ATT 設定；外部導航使用 Apple Maps/Google Maps URL，不加入 App 內地圖 SDK → 驗證：Apple 登入、Google 登入、同信箱 provider linking、重新驗證與 Apple token revoke/帳號刪除皆正常，再重跑 Phase 1～6 的所有功能點
9. **打磨（三平台）**：搜尋結果分頁/無限捲動、各狀態的 loading/empty/error 處理、投稿表單草稿保留、App icon/splash、隱私權政策與資料刪除說明、`flutter analyze`/`flutter test` 全過、上架準備（Play Data Safety 的 Web 刪除 URL、Play Console 正式送審、TestFlight/App Store 送審）
10. **後期 App 內地圖整合（三平台）**：核心產品上線並取得實際「附近搜尋／取得路線」使用數據後再啟動；比較 `flutter_map + MapTiler`、MapLibre 與 Google Maps 的三平台支援、商用條款、每月成本及維護風險，只選一套供應商。新增 Search 的列表／地圖切換、Marker、店家小卡、相機位置保存與懶初始化；地圖只在使用者主動開啟時載入並盡量復用同一 instance。Mobile 地圖底部可放與控制項分離的固定 Banner；Interstitial 僅在自然轉場、每 session 最多一次，頻率由 Remote Config 控制；Web 廣告需等 AdSense 階段另行評估 → 驗證：三平台 Marker 與列表結果一致、地圖重開不重複初始化、費用監控／quota／attribution 正確、廣告不遮擋 Marker 與控制項

---

## 驗證方式

- **Firebase Local Emulator Suite**：`firebase emulators:start --only auth,firestore,storage,functions`，App 在 debug 模式下指向 emulator；App Check 使用專用 debug token，測試資料不得連到 production
- **單元測試**：`geo_utils_test.dart`（geohash bbox 與距離排序）、店名正規化與重複候選排序、投稿配額視窗/reset/retryAfter、model 的 `fromJson`/`toJson`
- **Widget 測試**：`RestaurantCard`、附近/關鍵字列表切換、重複候選對話框、資料修正表單、超限錯誤與表單草稿保留、刪除帳號二次確認；MVP 不建立地圖 Widget 測試
- **Functions 測試**：未登入或缺少 App Check 時拒絕；配額 transaction 在併發呼叫下不超額；同一 idempotency key 只建立一筆；合併後舊店家導向、子集合與聚合一致；帳號刪除可中斷重試且不重複扣除計數
- **規則測試**（Phase 7 必做）：用 `@firebase/rules-unit-testing` 驗證未登入寫入會被拒絕、客戶端不能直接建立受 Functions 管理的 UGC/限流/申請文件、非管理員不能審核或合併、非本人不能讀寫他人的 favorites、`getAfter()` 可確保 favorite 與 `favoriteCount` 同交易更新、Storage 沒有有效 reservation 時無法上傳
- **整合測試**：Google 登入→投稿→觸發限流、重複店家提示→送出合併申請→管理員合併→舊網址導向、資料修正申請→核准、重新驗證→刪除測試帳號；iOS 另驗證 Sign in with Apple 與 provider linking
- **各平台手動測試**：Phase 0～7 用 `flutter run -d chrome`（Web）與 Android emulator；iOS simulator/實機測試集中在 Phase 8 一次進行（**需要 Mac/macOS CI**，此 Windows 機器需另外處理，屆時再準備即可，不影響前期開發）
- **上架前檢查**：`flutter analyze`/測試乾淨、App Check enforcement metrics 正常、隱私權政策與 Web 帳號刪除入口可用、Play Data Safety 表單、App Store 隱私標籤、iOS 的 Apple 登入/帳號刪除可操作、測試廣告 ID 換成正式 ID、release 簽章 SHA-1/SHA-256 已加入 Firebase
- **Phase 10 地圖驗證**：供應商 emulator/mock 測試、Marker 點擊與店家導頁、懶載入與 instance reuse、API key/domain/package restrictions、attribution、月用量警報、Banner 安全間距與 Interstitial frequency cap

---

## 關鍵檔案

- `lib/firebase_options.dart` — 由 `flutterfire configure` 產生，後續一切依賴它存在
- `lib/core/utils/geo_utils.dart` — geohash bounding-box + haversine 排序，「附近」功能核心
- `lib/features/search/search_map_view.dart` — **Phase 10 才建立**；將搜尋結果轉為 Marker，實作列表／地圖切換且不得耦合特定店家 Repository
- `lib/data/repositories/restaurant_repository.dart` — Home/Search/Detail/Upload 共用的資料存取入口
- `lib/data/repositories/restaurant_correction_repository.dart` — 重複候選、資料修正與合併申請的前端存取入口
- `lib/data/repositories/account_repository.dart` — 重新驗證、provider linking 與帳號刪除申請
- `lib/data/repositories/contribution_repository.dart` — 封裝投稿 callable Functions、idempotency key 與限流錯誤
- `lib/data/repositories/favorite_repository.dart` — 收藏/取消收藏的 transaction 邏輯，MyPageScreen 我的最愛清單的資料來源
- `lib/data/repositories/review_repository.dart` — 呼叫留言 Function，處理 CRUD、限流與 `ratingSum`/`ratingCount` 聚合結果
- `lib/core/services/app_check_service.dart` — 各平台 App Check provider、debug/production 切換與初始化
- `lib/core/router/app_router.dart` — go_router 設定，含 `/upload`、`/admin` 的登入攔截邏輯
- `functions/src/contribution_limits.ts` — 共用身分、App Check、限流與 idempotency 驗證
- `functions/src/restaurant_merge.ts`、`functions/src/restaurant_correction.ts` — 管理員合併與資料修正套用
- `functions/src/account_deletion.ts` — 可重試的帳號與關聯資料刪除流程，包含 Apple token revoke
- `functions/src/photo_upload.ts` — 圖片 reservation/finalize 與孤兒檔案清理
- `firebase/firestore.rules`、`firebase/storage.rules` — 公開讀取、拒絕直接寫受保護資料、favorites atomic 驗證與 reservation 上傳限制
