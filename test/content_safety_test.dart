import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:food_app/data/models/auth_user.dart';
import 'package:food_app/data/models/restaurant.dart';
import 'package:food_app/data/models/restaurant_review.dart';
import 'package:food_app/data/providers/auth_providers.dart';
import 'package:food_app/data/providers/block_providers.dart';
import 'package:food_app/data/providers/moderation_providers.dart';
import 'package:food_app/data/providers/restaurant_providers.dart';
import 'package:food_app/data/repositories/block_repository.dart';
import 'package:food_app/features/auth/login_screen.dart';
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
  createdBy: 'creator-1',
  recommenderName: '推薦達人',
);

const _signedInUser = AuthUser(
  uid: 'user-1',
  displayName: '測試使用者',
  email: 'tester@example.com',
  photoUrl: null,
  providerIds: ['apple.com'],
);

RestaurantReview _review(String authorUid, String name, String text) {
  return RestaurantReview(
    id: authorUid,
    rating: 4,
    text: text,
    authorName: name,
    authorPhotoUrl: null,
    status: 'active',
    createdAt: null,
  );
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required List<BlockedUser> blockedUsers,
}) async {
  // 評論區在頁面下方，加高畫面讓評論直接顯示。
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateChangesProvider.overrideWith(
          (ref) => Stream.value(_signedInUser),
        ),
        adminStatusProvider.overrideWith((ref) => Stream.value(false)),
        blockedUsersProvider.overrideWith((ref) => Stream.value(blockedUsers)),
        restaurantProvider.overrideWith(
          (ref, restaurantId) => Stream.value(_restaurant),
        ),
        restaurantPhotosProvider.overrideWith(
          (ref, restaurantId) => Stream.value(const []),
        ),
        restaurantReviewsProvider.overrideWith(
          (ref, restaurantId) => Stream.value([
            _review('friend-1', '好朋友', '拉麵很好吃'),
            _review('troll-1', '討厭鬼', '不當內容'),
          ]),
        ),
      ],
      child: const MaterialApp(
        home: RestaurantDetailScreen(restaurantId: 'restaurant-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('登入前必須先同意使用條款', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [GoRoute(path: '/login', builder: (_, _) => const LoginScreen())],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    FilledButton googleButton() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('使用 Google 登入'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );

    expect(googleButton().onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(googleButton().onPressed, isNotNull);
  });

  testWidgets('封鎖的使用者評論會被隱藏', (tester) async {
    await _pumpDetail(
      tester,
      blockedUsers: const [BlockedUser(uid: 'troll-1', displayName: '討厭鬼')],
    );

    expect(find.text('拉麵很好吃'), findsOneWidget);
    expect(find.text('不當內容'), findsNothing);
  });

  testWidgets('別人的評論可以檢舉與封鎖', (tester) async {
    await _pumpDetail(tester, blockedUsers: const []);

    await tester.tap(find.byTooltip('評論操作').first);
    await tester.pumpAndSettle();

    expect(find.text('檢舉評論'), findsOneWidget);
    expect(find.text('封鎖此使用者'), findsOneWidget);
    expect(find.text('刪除評論'), findsNothing);
  });

  testWidgets('店家選單提供檢舉與封鎖推薦人', (tester) async {
    await _pumpDetail(tester, blockedUsers: const []);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('檢舉不當內容'), findsOneWidget);
    expect(find.text('封鎖推薦人'), findsOneWidget);
  });
}
