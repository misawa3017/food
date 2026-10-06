import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_app/app.dart';
import 'package:food_app/core/ads/ad_service_stub.dart';
import 'package:food_app/core/router/app_router.dart';
import 'package:food_app/data/models/auth_user.dart';
import 'package:food_app/data/models/contribution_models.dart';
import 'package:food_app/data/models/location_result.dart';
import 'package:food_app/data/providers/ad_providers.dart';
import 'package:food_app/data/providers/auth_providers.dart';
import 'package:food_app/data/providers/contribution_providers.dart';
import 'package:food_app/data/providers/location_providers.dart';
import 'package:food_app/data/providers/restaurant_providers.dart';
import 'package:food_app/data/repositories/contribution_repository.dart';

class _SubmissionRepository implements ContributionRepository {
  _SubmissionRepository({required this.photoUploadFailed});

  final bool photoUploadFailed;
  @override
  Future<RestaurantSubmissionResult> submitRestaurant(
    RestaurantContributionDraft draft, {
    required bool duplicateAcknowledged,
    required void Function(double progress) onProgress,
    String? idempotencyKey,
  }) async {
    return RestaurantSubmissionResult(
      restaurantId: 'created-restaurant',
      photoUploadFailed: photoUploadFailed,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final action in ['回首頁', '修改店家', 'photoUploadFailed']) {
    testWidgets('Publication via $action opens an empty upload form', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
            latestRestaurantsProvider.overrideWith((ref) => Stream.value([])),
            searchCatalogProvider.overrideWith((ref) => Stream.value([])),
            restaurantProvider.overrideWith((ref, id) => Stream.value(null)),
            contributionRepositoryProvider.overrideWithValue(
              _SubmissionRepository(
                photoUploadFailed: action == 'photoUploadFailed',
              ),
            ),
            adServiceProvider.overrideWithValue(const StubAdService()),
          ],
          child: const FoodApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      Finder field(String label) => find
          .byType(TextFormField)
          .at(['店家名稱', '路段與門牌', '推薦菜色'].indexOf(label));
      await tester.enterText(field('店家名稱'), '上一間店家');
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('臺北市').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('中正區').last);
      await tester.pumpAndSettle();
      await tester.enterText(field('路段與門牌'), '測試路1號');
      await tester.tap(find.text('日式'));
      await tester.enterText(field('推薦菜色'), '上一道菜');
      await tester.tap(find.text('發布店家'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      if (action != 'photoUploadFailed') {
        expect(find.text('店家新增完成'), findsOneWidget);
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      if (action != '回首頁') {
        final container = ProviderScope.containerOf(
          tester.element(find.byType(FoodApp)),
        );
        container.read(appRouterProvider).go('/');
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('新增'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(field('店家名稱')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextFormField>(field('路段與門牌')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextFormField>(field('推薦菜色')).controller!.text,
        isEmpty,
      );
      for (final dropdown in tester.widgetList<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      )) {
        expect(dropdown.initialValue, isNull);
      }
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '日式'))
            .selected,
        isFalse,
      );
    });
  }
}
