import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:food_app/core/ads/ad_service_stub.dart';
import 'package:food_app/data/models/auth_user.dart';
import 'package:food_app/data/models/contribution_models.dart';
import 'package:food_app/data/models/location_result.dart';
import 'package:food_app/data/providers/account_providers.dart';
import 'package:food_app/data/providers/ad_providers.dart';
import 'package:food_app/data/providers/auth_providers.dart';
import 'package:food_app/data/providers/contribution_providers.dart';
import 'package:food_app/data/providers/location_providers.dart';
import 'package:food_app/data/repositories/account_repository.dart';
import 'package:food_app/data/repositories/contribution_repository.dart';
import 'package:food_app/features/upload/add_restaurant_screen.dart';

class _ContributionRepository implements ContributionRepository {
  int submitCount = 0;

  @override
  Future<RestaurantSubmissionResult> submitRestaurant(
    RestaurantContributionDraft draft, {
    required bool duplicateAcknowledged,
    required void Function(double progress) onProgress,
    String? idempotencyKey,
  }) async {
    submitCount += 1;
    return const RestaurantSubmissionResult(
      restaurantId: 'created-restaurant',
      photoUploadFailed: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AccountRepository implements AccountRepository {
  _AccountRepository(this.currentName);

  final Future<String?> Function() currentName;
  final savedNames = <String>[];
  String? failure;

  @override
  Future<String?> getPublicRecommenderName() => currentName();

  @override
  Future<int> updatePublicRecommenderName(String name) async {
    final message = failure;
    if (message != null) throw AccountDeletionException(message);
    savedNames.add(name);
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _ContributionRepository contributions;
  late _AccountRepository accounts;

  Future<void> pumpAndSubmit(
    WidgetTester tester,
    Future<String?> Function() recommenderName,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    contributions = _ContributionRepository();
    accounts = _AccountRepository(recommenderName);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateChangesProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                uid: 'test-user',
                displayName: '測試使用者',
                email: 'test@example.com',
                photoUrl: null,
                providerIds: ['google.com'],
              ),
            ),
          ),
          currentLocationProvider.overrideWith(
            (ref) async =>
                const LocationResult.failed(LocationFailure.permissionDenied),
          ),
          accountRepositoryProvider.overrideWithValue(accounts),
          contributionRepositoryProvider.overrideWithValue(contributions),
          adServiceProvider.overrideWithValue(const StubAdService()),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const AddRestaurantScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder field(int index) => find.byType(TextFormField).at(index);
    await tester.enterText(field(0), '測試店家');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('臺北市').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('中正區').last);
    await tester.pumpAndSettle();
    await tester.enterText(field(1), '測試路1號');
    await tester.tap(find.text('日式'));
    await tester.tap(find.text('發布店家'));
    await tester.pump();
    await tester.pump();
  }

  // 檢查暱稱期間會顯示進度動畫，pumpAndSettle 不會結束，改為推進固定時間。
  Future<void> settleDialog(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> fillDialog(WidgetTester tester, String name) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      name,
    );
    await tester.tap(find.text('儲存'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('submits directly when a nickname exists', (tester) async {
    await pumpAndSubmit(tester, () async => '測試暱稱');

    expect(find.text('公開推薦暱稱'), findsNothing);
    expect(contributions.submitCount, 1);
  });

  testWidgets('cancelling the nickname dialog does not submit', (tester) async {
    await pumpAndSubmit(tester, () async => null);
    await settleDialog(tester);

    expect(find.text('公開推薦暱稱'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await settleDialog(tester);

    expect(contributions.submitCount, 0);
    expect(accounts.savedNames, isEmpty);
    expect(find.text('測試店家'), findsOneWidget);
  });

  testWidgets('rejects a too short nickname inside the dialog', (tester) async {
    await pumpAndSubmit(tester, () async => null);
    await settleDialog(tester);

    await fillDialog(tester, ' 甲 ');
    await settleDialog(tester);

    expect(find.text('請輸入至少 2 個字元。'), findsOneWidget);
    expect(accounts.savedNames, isEmpty);
    expect(contributions.submitCount, 0);
  });

  testWidgets('saves the nickname and then submits', (tester) async {
    await pumpAndSubmit(tester, () async => null);
    await settleDialog(tester);

    await fillDialog(tester, ' 我的暱稱 ');

    expect(accounts.savedNames, ['我的暱稱']);
    expect(contributions.submitCount, 1);
  });

  testWidgets('does not submit when saving the nickname fails', (tester) async {
    await pumpAndSubmit(tester, () async => null);
    await settleDialog(tester);
    accounts.failure = '請換一個公開暱稱。';

    await fillDialog(tester, '匿名美食家');
    await settleDialog(tester);

    expect(find.text('請換一個公開暱稱。'), findsOneWidget);
    expect(contributions.submitCount, 0);
    expect(find.text('測試店家'), findsOneWidget);
  });

  testWidgets('does not submit when the nickname cannot be read', (
    tester,
  ) async {
    await pumpAndSubmit(
      tester,
      () async => throw const AccountDeletionException('network'),
    );
    await settleDialog(tester);

    expect(find.text('無法確認公開暱稱，請稍後再試。'), findsOneWidget);
    expect(find.text('公開推薦暱稱'), findsNothing);
    expect(contributions.submitCount, 0);
  });
}
