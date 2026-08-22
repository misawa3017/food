# AGENTS.md

# 專案說明

這是一個 Flutter Mobile App 專案。

主要技術：

* Flutter
* Dart
* Riverpod
* Firebase
* Firebase Authentication
* Cloud Firestore
* Flutter Integration Test

目標平台：

* Android
* iOS
* web

本文件用來告訴 Codex 在這個專案中應遵守的開發規範。

Codex 在修改程式碼之前，應先閱讀現有專案結構與程式碼，不要直接假設專案架構。

---

# 語言規範

與開發者溝通時，一律使用**繁體中文**。

包含：

* 問題說明
* 修改說明
* 錯誤說明
* 測試結果
* 架構說明
* 建議事項

程式碼中的名稱使用英文，例如：

```dart
UserRepository
AuthRepository
getUser()
createUser()
currentUser
userId
```

不要使用中文作為：

* class 名稱
* function 名稱
* variable 名稱
* method 名稱
* file 名稱

---

# 程式碼註解

程式碼註解使用**繁體中文**。

例如：

```dart
/// 使用者資料 Repository
///
/// 負責處理使用者資料的讀取與更新。
class UserRepository {

  /// 根據使用者 ID 取得使用者資料
  Future<User?> getUser(String userId) async {

    // 從 Firestore 取得使用者文件
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    // 如果文件不存在，代表找不到此使用者
    if (!snapshot.exists) {
      return null;
    }

    return User.fromJson(snapshot.data()!);
  }
}
```

註解應該說明：

* 為什麼這樣設計
* 特殊業務邏輯
* 不容易理解的程式邏輯
* Firebase / Firestore 特殊行為
* Riverpod 狀態變化
* workaround 的原因

不要加入沒有意義的註解。

例如不要：

```dart
// 設定名字
name = user.name;

// 回傳 user
return user;
```

因為程式碼本身已經很清楚。

應該寫成：

```dart
// Firestore 舊資料可能沒有 displayName，因此使用原本名稱作為 fallback
final name = data['displayName'] ?? user.name;
```

---

# Flutter 開發原則

開發 Flutter 程式時：

* 優先使用簡單、容易維護的寫法。
* Widget 應保持簡潔。
* Business Logic 不要直接寫在 Widget 裡。
* 優先使用 `const` constructor。
* 避免不必要的 `StatefulWidget`。
* 避免 Global Mutable State。
* 避免重複程式碼。
* 不要把 Firebase 操作直接寫在 UI。
* 不要為了抽象化而過度設計。

修改 Dart 程式碼後執行：

```bash
dart format .
```

並執行：

```bash
flutter analyze
```

確認沒有新的問題。

---

# 專案架構

專案優先使用 Feature-based Architecture。

建議結構：

```text
lib/

  core/
    constants/
    errors/
    services/
    utils/

  features/

    auth/
      data/
        datasources/
        repositories/

      domain/
        models/
        repositories/

      presentation/
        providers/
        screens/
        widgets/

    user/
      data/
      domain/
      presentation/

  shared/
    widgets/
    providers/

  main.dart
```

每一個功能放在自己的 `features` 目錄。

例如：

```text
features/auth/
features/user/
features/profile/
features/location/
```

不要把所有：

```text
screens
models
repositories
providers
```

全部集中在全域目錄。

---

# 程式資料流

原則上使用：

```text
Widget
  ↓
Riverpod Provider / Notifier
  ↓
Repository
  ↓
DataSource
  ↓
Firebase / Firestore
```

Widget 不應該直接操作 Firebase。

例如不要：

```dart
class UserPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {

    FirebaseFirestore.instance
        .collection('users')
        .doc('123')
        .get();

    return Container();
  }
}
```

應該：

```text
UserPage
   ↓
userProvider
   ↓
UserRepository
   ↓
FirestoreUserDataSource
   ↓
Cloud Firestore
```

這樣可以降低 UI 與 Firebase 的耦合。

---

# Riverpod 規範

專案使用 Riverpod 作為主要 State Management。

可以依需求使用：

```text
Provider
FutureProvider
StreamProvider
Notifier
AsyncNotifier
```

不要加入其他 State Management，例如：

```text
BLoC
GetX
Provider package
MobX
```

除非開發者明確要求。

---

# Riverpod Provider 的責任

Provider 負責：

* 管理 UI State
* 呼叫 Repository
* 處理 Loading
* 處理 Error
* 提供資料給 Widget

例如：

```text
Widget
   ↓
AsyncNotifier
   ↓
Repository
```

Widget 主要負責：

```text
watch state
      ↓
顯示畫面
      ↓
處理使用者操作
```

不要把大量 Business Logic 寫在 Widget。

---

# Repository Pattern

所有 Firebase / Firestore 操作應盡量透過 Repository。

例如：

```text
UserRepository
AuthRepository
LocationRepository
```

不要讓 UI 知道資料來自 Firestore。

例如 UI 可以呼叫：

```dart
getUser(userId);
```

不要讓 UI 呼叫：

```dart
FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .get();
```

---

# Repository Interface

如果功能較複雜，可以建立 Repository Interface。

例如：

```dart
abstract class UserRepository {

  /// 根據 ID 取得使用者
  Future<User?> getUser(String userId);

  /// 建立使用者
  Future<void> createUser(User user);

  /// 更新使用者
  Future<void> updateUser(User user);
}
```

Firebase 實作：

```dart
class FirebaseUserRepository implements UserRepository {
  // Firebase / Firestore 實作
}
```

這樣未來比較容易：

* 測試
* Mock
* 更換 Backend
* 使用 Firebase Emulator

---

# Firebase 規範

Firebase 相關程式盡量集中在：

```text
data/
datasources/
repositories/
```

例如：

```text
FirestoreUserDataSource
FirebaseAuthDataSource
FirebaseUserRepository
FirebaseLocationRepository
```

不要把 Firebase SDK 操作散落在整個專案。

---

# Firestore Model

Firestore 資料應轉換成 Model。

不要在整個 App 傳遞：

```dart
Map<String, dynamic>
```

建議：

```text
Firestore
   ↓
UserModel
   ↓
Repository
   ↓
Provider
   ↓
Widget
```

例如：

```dart
class User {
  final String id;
  final String name;

  const User({
    required this.id,
    required this.name,
  });
}
```

---

# Firestore 欄位安全

不要假設 Firestore 每一筆舊資料都有完整欄位。

例如不要直接：

```dart
final name = data['name'] as String;
```

如果欄位可能不存在，應安全處理：

```dart
final name = data['name'] as String? ?? '';
```

避免舊資料造成 App Crash。

---

# Firestore Query

Firestore Query 應注意讀取成本。

避免：

```text
讀取整個 Collection
↓
在 App 裡面自己 Filter
```

優先使用 Firestore Query：

```dart
.where(...)
.orderBy(...)
.limit(...)
```

如果資料很多，應考慮：

```text
Pagination
Query Limit
Cursor
```

---

# Firestore Index

使用以下組合時：

```text
where
+
orderBy
```

或多個條件：

```text
where
+
where
+
orderBy
```

要注意 Firestore 可能需要建立 Composite Index。

如果 Codex 新增這類 Query，應提醒開發者是否需要新增 Firestore Index。

---

# Firebase Authentication

Firebase Authentication 應透過：

```text
Widget
   ↓
AuthProvider
   ↓
AuthRepository
   ↓
FirebaseAuth
```

Widget 不要大量直接操作：

```dart
FirebaseAuth.instance
```

---

# 安全規範

禁止把以下資料寫入程式碼或 Git：

* Password
* API Token
* Access Token
* Refresh Token
* Service Account Key
* Private Key
* Firebase Admin Credential

不要在 Log 中輸出：

```text
password
token
credential
authorization header
```

---

# Firebase Production 安全

沒有開發者明確允許時：

禁止：

* 刪除 Production Firestore Collection
* 大量修改 Production Data
* 清空 Firestore
* 修改 Production Firebase 設定
* 修改 Production Security Rules
* 執行破壞性 Migration

如果操作可能影響 Production Data，必須先告知開發者。

---

# UI 開發規範

Screen 主要負責：

* Layout
* 顯示資料
* 使用者互動

不要在 Screen 裡放大量 Business Logic。

畫面太大時，可以拆成：

```text
screens/
widgets/
```

但不要過度拆分。

例如一個只有：

```dart
Text(user.name)
```

的小元件通常沒有必要單獨建立 Widget File。

---

# Theme

優先使用專案現有 Theme。

避免大量：

```dart
Color(0xFFxxxxxx)
TextStyle(...)
EdgeInsets(...)
```

散落在程式碼。

如果專案已經有：

```text
AppColors
AppTheme
AppTextStyles
AppSpacing
```

應優先使用現有設定。

---

# Navigation

使用專案目前既有的 Navigation Solution。

例如專案已使用：

```text
go_router
```

就繼續使用。

不要同時再加入：

```text
auto_route
GetX routing
```

除非開發者要求。

Repository 不應該處理 Navigation。

---

# Integration Test

本專案主要使用 Flutter Integration Test。

測試放在：

```text
integration_test/
```

例如：

```text
integration_test/
  login_test.dart
  register_test.dart
  profile_test.dart
```

重要流程應建立 Integration Test，例如：

* Login
* Logout
* Register
* 建立資料
* 修改資料
* 主要頁面 Navigation
* Form Submit

---

# 執行 Integration Test

一般執行：

```bash
flutter test integration_test
```

指定裝置：

```bash
flutter test integration_test -d <device-id>
```

修改重要 User Flow 後，應執行相關 Integration Test。

---

# 測試資料安全

Integration Test 不應使用正式 Production Data。

優先使用：

```text
Firebase Emulator
```

或：

```text
Test Firebase Project
```

測試程式禁止：

```text
清空 Production Firestore
```

測試資料應該：

* 可以識別
* 可以安全刪除
* 不影響正式使用者

---

# Dependency 規範

加入新的 Flutter Package 前：

先檢查：

```text
pubspec.yaml
```

確認：

1. 是否已經有類似 Package。
2. Flutter / Dart 本身是否已經能完成。
3. 是否真的需要增加 Dependency。
4. Package 是否仍有維護。

不要為了一個簡單功能就加入大型 Package。

---

# 修改 Dependency

修改：

```text
pubspec.yaml
```

後執行：

```bash
flutter pub get
```

不要在沒有必要的情況下升級所有 Dependency。

---

# Code Generation

如果專案使用：

```text
freezed
json_serializable
riverpod_generator
build_runner
```

修改相關檔案後執行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

不要直接修改：

```text
*.g.dart
*.freezed.dart
```

這些是自動產生的檔案。

應修改來源檔，再重新 Generate。

---

# 修改程式前

Codex 接到任務後，先：

1. 了解需求。
2. 查看相關程式碼。
3. 查看目前專案架構。
4. 查看是否已經有類似功能。
5. 查看目前使用的 Repository / Provider。
6. 再決定如何修改。

不要一收到需求就直接建立新的：

```text
Service
Repository
Provider
Model
```

應先確認是否已有可以使用的程式。

---

# 修改原則

修改程式時：

優先採用：

```text
最小必要修改
```

不要因為修改一個功能，就順便重構大量無關程式。

例如需求只是：

```text
修改登入按鈕文字
```

就不應該順便：

```text
重構 AuthRepository
修改 Firestore Schema
更換 Riverpod 架構
```

---

# 大型修改

如果需要進行大型架構調整：

先說明：

1. 為什麼需要修改。
2. 預計修改哪些部分。
3. 有什麼風險。
4. 是否有更簡單的方法。

再進行修改。

---

# 完成任務前檢查

修改完成後執行：

```bash
dart format .
```

接著：

```bash
flutter analyze
```

再執行：

```bash
flutter test
```

如果修改涉及重要 User Flow，再執行：

```bash
flutter test integration_test
```

---

# 如果測試失敗

不要為了讓測試變綠而直接刪除 Test。

應先判斷：

```text
程式錯誤？
    ↓
修正程式

需求真的改變？
    ↓
才修改 Test
```

如果無法解決測試問題，應清楚告訴開發者。

---

# Git 規範

不要執行破壞性 Git 操作，除非開發者明確要求。

例如不要自行：

```bash
git reset --hard
git clean -fd
git push --force
```

不要修改與目前任務無關的檔案。

不要 Commit：

```text
Password
Token
Credential
Private Key
Service Account
```

---

# 任務完成後回報

完成任務後，用繁體中文提供簡短報告。

格式：

```text
完成內容：

- 新增 UserRepository
- 新增 userProvider
- UserPage 改由 Riverpod 取得資料

修改檔案：

- lib/features/user/data/user_repository.dart
- lib/features/user/presentation/providers/user_provider.dart
- lib/features/user/presentation/screens/user_page.dart

檢查結果：

dart format      ✓
flutter analyze  ✓
flutter test     ✓
integration test ✓

注意事項：

- Firestore Query 需要建立 Composite Index
```

---

# Codex 工作流程

Codex 每次處理開發任務時，遵循：

```text
了解需求
   ↓
閱讀現有程式
   ↓
確認目前架構
   ↓
尋找可重用程式
   ↓
規劃最小修改
   ↓
修改程式
   ↓
dart format
   ↓
flutter analyze
   ↓
測試
   ↓
繁體中文回報結果
```

---

# 最重要規則

請特別遵守以下原則：

1. 與開發者溝通使用繁體中文。
2. 程式碼名稱使用英文。
3. 程式碼註解使用繁體中文。
4. 使用 Riverpod 管理 State。
5. UI 不直接操作 Firestore。
6. Firebase 操作透過 Repository / DataSource。
7. 不修改與任務無關的程式。
8. 不隨意增加 Dependency。
9. 不對 Production Firebase 執行破壞性操作。
10. 修改後執行 `dart format`。
11. 修改後執行 `flutter analyze`。
12. 修改重要流程後執行 Integration Test。
13. 不刪除測試來掩蓋程式錯誤。
14. 不 Commit Password、Token、Credential。
15. 優先遵循專案現有架構。
16. 優先進行最小必要修改。
