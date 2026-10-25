import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 將 StateProvider 移到 legacy；此處只需單純讀寫字串，沿用即可。
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import 'ads/app_banner_ad.dart';

/// 底部導覽各分頁的路徑，順序與 [AppShell] 的 destinations 相同
const appShellTabPaths = ['/', '/search', '/upload', '/me'];

/// 切換分頁前所在的分頁路徑，供未登入時的返回鍵回到上一個分頁
final previousTabPathProvider = StateProvider<String>((ref) => '/');

/// 回到切換前的分頁；若上一個分頁就是目前分頁 [from] 或需要登入，改回首頁
void goToPreviousTab(
  BuildContext context,
  WidgetRef ref, {
  required String from,
}) {
  final previous = ref.read(previousTabPathProvider);
  context.go(
    previous == from || routeRequiresSignIn(previous) ? '/' : previous,
  );
}

/// Bottom-nav shell for the 4 top-level tabs: 附近 / 搜尋 / 新增 / 我的.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: navigationShell),
          // 填寫投稿表單時容易誤點廣告，「新增」分頁不顯示橫幅
          if (appShellTabPaths[navigationShell.currentIndex] != '/upload')
            const AppBannerAd(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              if (index != navigationShell.currentIndex) {
                ref.read(previousTabPathProvider.notifier).state =
                    appShellTabPaths[navigationShell.currentIndex];
              }
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: '附近',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜尋',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: '新增',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
