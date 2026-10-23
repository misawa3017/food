import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:food_app/features/auth/login_screen.dart';

void main() {
  testWidgets('登入頁在無法 pop 時仍顯示返回鍵並回到來源頁', (tester) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('首頁')),
        GoRoute(path: '/search', builder: (_, _) => const Text('搜尋頁')),
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(redirectLocation: '/search'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('搜尋頁'), findsOneWidget);
  });
}
