import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_app/app.dart';
import 'package:food_app/data/models/auth_user.dart';
import 'package:food_app/data/models/location_result.dart';
import 'package:food_app/data/models/nearby_restaurant.dart';
import 'package:food_app/data/models/restaurant.dart';
import 'package:food_app/data/providers/auth_providers.dart';
import 'package:food_app/data/providers/location_providers.dart';
import 'package:food_app/data/providers/moderation_providers.dart';
import 'package:food_app/data/providers/restaurant_providers.dart';
import 'package:food_app/features/account/account_deletion_info_screen.dart';
import 'package:food_app/features/admin/admin_screen.dart';
import 'package:food_app/features/restaurant/restaurant_detail_screen.dart';

const _restaurant = Restaurant(
  id: 'restaurant-1',
  name: '測試食堂',
  nameLower: '測試食堂',
  address: '台北市測試路1號',
  location: GeoCoordinates(latitude: 25.04, longitude: 121.52),
  categories: ['日式'],
  recommendedDishes: ['測試定食'],
  coverPhotoUrl: null,
  photoCount: 0,
  ratingSum: 9,
  ratingCount: 2,
  favoriteCount: 3,
  status: 'active',
  mergedIntoRestaurantId: null,
  createdAt: null,
);

void main() {
  testWidgets('App boots and shows the 4-tab shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('附近'), findsWidgets);
    expect(find.text('搜尋'), findsWidgets);
    expect(find.text('新增'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('測試食堂'), findsOneWidget);
  });

  testWidgets('Upload redirects signed-out users to login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.text('登入後繼續'), findsOneWidget);
    expect(find.text('使用 Google 登入'), findsOneWidget);
  });

  testWidgets('Signed-in upload tab displays restaurant form', (
    WidgetTester tester,
  ) async {
    const user = AuthUser(
      uid: 'user-1',
      displayName: '測試使用者',
      email: 'tester@example.com',
      photoUrl: null,
      providerIds: ['google.com'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(user)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.text('店家名稱'), findsOneWidget);
    expect(find.text('使用目前位置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('發布店家'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('選擇照片'), findsOneWidget);
    expect(find.text('發布店家'), findsOneWidget);
  });

  testWidgets('Profile displays the signed-in user', (
    WidgetTester tester,
  ) async {
    const user = AuthUser(
      uid: 'user-1',
      displayName: '測試使用者',
      email: 'tester@example.com',
      photoUrl: null,
      providerIds: ['google.com'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(user)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('測試使用者'), findsOneWidget);
    expect(find.text('tester@example.com'), findsOneWidget);
    expect(find.text('登出'), findsOneWidget);
    expect(find.text('刪除帳號與資料'), findsOneWidget);
  });

  testWidgets('Account deletion requires typed confirmation', (
    WidgetTester tester,
  ) async {
    const user = AuthUser(
      uid: 'user-1',
      displayName: '測試使用者',
      email: 'tester@example.com',
      photoUrl: null,
      providerIds: ['google.com'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(user)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除帳號與資料'));
    await tester.pumpAndSettle();

    expect(find.text('永久刪除帳號？'), findsOneWidget);
    var deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '永久刪除'),
    );
    expect(deleteButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '刪除');
    await tester.pump();

    deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '永久刪除'),
    );
    expect(deleteButton.onPressed, isNotNull);
  });

  testWidgets('Public account deletion page explains the process', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(home: AccountDeletionInfoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('申請刪除美食通帳號'), findsOneWidget);
    expect(find.text('登入後申請刪除'), findsOneWidget);
    expect(find.textContaining('此操作無法復原'), findsOneWidget);
  });

  testWidgets('Search filters display restaurant results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchRestaurantsProvider.overrideWith(
            (ref, query) async => const [_restaurant],
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜尋'));
    await tester.pumpAndSettle();

    expect(find.text('全部'), findsOneWidget);
    expect(find.text('日式'), findsWidgets);
    expect(find.text('輸入店名開始搜尋'), findsOneWidget);
    expect(find.text('測試食堂'), findsNothing);

    await tester.enterText(find.byType(TextField), '測試');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('測試食堂'), findsOneWidget);
  });

  testWidgets('Restaurant detail displays readonly content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restaurantProvider.overrideWith(
            (ref, restaurantId) => Stream.value(_restaurant),
          ),
          restaurantPhotosProvider.overrideWith(
            (ref, restaurantId) => Stream.value(const []),
          ),
          restaurantReviewsProvider.overrideWith(
            (ref, restaurantId) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(
          home: RestaurantDetailScreen(restaurantId: 'restaurant-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('測試食堂'), findsOneWidget);
    expect(find.text('測試定食'), findsOneWidget);
    expect(find.text('帶我去'), findsOneWidget);
    expect(find.text('目前還沒有評論。'), findsOneWidget);
    expect(find.text('寫評論'), findsOneWidget);
  });

  testWidgets('Admin screen displays moderation queues', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminStatusProvider.overrideWith((ref) => Stream.value(true)),
          pendingReportsProvider.overrideWith((ref) => Stream.value(const [])),
          pendingEditRequestsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          pendingMergeRequestsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('後台管理'), findsOneWidget);
    expect(find.text('檢舉'), findsOneWidget);
    expect(find.text('資料修正'), findsOneWidget);
    expect(find.text('重複店家'), findsOneWidget);
    expect(find.text('目前沒有待處理項目。'), findsOneWidget);
  });

  testWidgets('Home displays nearby radius and restaurant distance', (
    WidgetTester tester,
  ) async {
    const coordinates = GeoCoordinates(latitude: 25.04, longitude: 121.52);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith(
            (ref) async => const LocationResult.success(coordinates),
          ),
          nearbyRestaurantsProvider.overrideWith(
            (ref, query) async => const NearbySearchResult(
              restaurants: [
                NearbyRestaurant(restaurant: _restaurant, distanceMeters: 850),
              ],
              radiusKm: 3,
            ),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('依距離排序 · 3 公里'), findsOneWidget);
    expect(find.text('850 公尺'), findsOneWidget);
    expect(find.text('測試食堂'), findsOneWidget);
  });

  testWidgets('Home falls back to latest restaurants when nearby is empty', (
    WidgetTester tester,
  ) async {
    const coordinates = GeoCoordinates(latitude: 24, longitude: 120);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith((ref) => Stream.value(null)),
          currentLocationProvider.overrideWith(
            (ref) async => const LocationResult.success(coordinates),
          ),
          nearbyRestaurantsProvider.overrideWith(
            (ref, query) async =>
                const NearbySearchResult(restaurants: [], radiusKm: 30),
          ),
          latestRestaurantsProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
          searchCatalogProvider.overrideWith(
            (ref) => Stream.value(const [_restaurant]),
          ),
        ],
        child: const FoodApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('30 公里內沒有店家，先顯示最新店家。'), findsOneWidget);
    expect(find.text('測試食堂'), findsOneWidget);
  });

  test('Restaurant model tolerates missing and invalid optional fields', () {
    final restaurant = Restaurant.fromMap('safe-model', {
      'name': '安全店家',
      'geo': 'invalid',
      'ratingSum': -5,
      'ratingCount': -1,
      'categories': ['小吃', 123],
      'amenities': ['可刷卡', 123],
    });

    expect(restaurant.location, isNull);
    expect(restaurant.ratingSum, 0);
    expect(restaurant.ratingCount, 0);
    expect(restaurant.categories, ['小吃']);
    expect(restaurant.amenities, ['可刷卡']);
    expect(restaurant.status, 'removed');
  });
}
