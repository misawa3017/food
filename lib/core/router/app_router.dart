import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/imported_place.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/account/account_deletion_info_screen.dart';
import '../../features/admin/admin_screen.dart';
import '../../features/admin/google_saved_places_import_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/my_page_screen.dart';
import '../../features/restaurant/restaurant_detail_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/upload/add_restaurant_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/sign_in_required_tab.dart';

const _loginPath = '/login';

/// 判斷路徑是否需要登入才能進入（未登入會被導向登入頁）
///
/// 「新增」分頁 `/upload` 不在此列：未登入時由 [SignInRequiredTab]
/// 在分頁內顯示登入提示，才能保留底部導覽列。
bool routeRequiresSignIn(String path) {
  return path == '/admin' || path == '/import-google-saved-places';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading) {
        return null;
      }

      final isSignedIn = authState.asData?.value != null;
      final isLoginRoute = state.uri.path == _loginPath;
      final requiresSignIn = routeRequiresSignIn(state.uri.path);

      if (!isSignedIn && requiresSignIn) {
        return Uri(
          path: _loginPath,
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }

      if (isSignedIn && isLoginRoute) {
        return state.uri.queryParameters['from'] ?? '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/account-deletion',
        builder: (context, state) => const AccountDeletionInfoScreen(),
      ),
      GoRoute(path: '/admin', builder: (context, state) => const AdminScreen()),
      GoRoute(
        path: '/import-google-saved-places',
        builder: (context, state) => const GoogleSavedPlacesImportScreen(),
      ),
      GoRoute(
        path: _loginPath,
        builder: (context, state) {
          return LoginScreen(
            redirectLocation: state.uri.queryParameters['from'],
          );
        },
      ),
      GoRoute(
        path: '/restaurants/:restaurantId',
        builder: (context, state) {
          return RestaurantDetailScreen(
            restaurantId: state.pathParameters['restaurantId']!,
            showPhotoUploadFailureNotice:
                state.uri.queryParameters['photoUploadFailed'] == '1',
            openEditSheet: state.uri.queryParameters['edit'] == '1',
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upload',
                builder: (context, state) => SignInRequiredTab(
                  path: '/upload',
                  title: '分享一家好店',
                  message: '登入後即可推薦餐廳、上傳照片。',
                  child: AddRestaurantScreen(
                    importedPlace: state.extra is ImportedPlace
                        ? state.extra! as ImportedPlace
                        : null,
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (context, state) => const MyPageScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
