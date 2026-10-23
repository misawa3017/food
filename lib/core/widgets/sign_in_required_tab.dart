import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_providers.dart';
import 'app_shell.dart';

/// 需要登入的底部導覽分頁：未登入時留在分頁內顯示登入提示（保留導覽列），
/// 登入後才顯示 [child]
class SignInRequiredTab extends ConsumerWidget {
  const SignInRequiredTab({
    super.key,
    required this.path,
    required this.title,
    required this.message,
    required this.child,
  });

  /// 此分頁的路徑，登入後會導回這裡
  final String path;
  final String title;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          const Scaffold(body: Center(child: Text('無法取得登入狀態，請稍後再試。'))),
      data: (user) {
        if (user != null) {
          return child;
        }

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () => goToPreviousTab(context, ref, from: path),
            ),
            title: Text(title),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    '尚未登入',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push(
                      '/login?from=${Uri.encodeComponent(path)}',
                    ),
                    child: const Text('前往登入'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
