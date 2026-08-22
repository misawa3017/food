import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_providers.dart';

class AccountDeletionInfoScreen extends ConsumerWidget {
  const AccountDeletionInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('刪除帳號與資料')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.delete_forever_outlined, size: 64),
              const SizedBox(height: 20),
              Text(
                '申請刪除美食通帳號',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              const Text(
                '刪除後，你的登入帳號、收藏與個人資料會永久移除；你上傳的評論與照片會下架，必要的防濫用與審核紀錄會匿名化。此操作無法復原。',
              ),
              const SizedBox(height: 16),
              const _DeletionStep(
                number: '1',
                text: '使用要刪除的 Google 或 Apple 帳號登入。',
              ),
              const _DeletionStep(number: '2', text: '前往「我的」，選擇「刪除帳號與資料」。'),
              const _DeletionStep(number: '3', text: '重新驗證登入並輸入「刪除」完成確認。'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(
                  user == null
                      ? '/login?from=${Uri.encodeComponent('/account-deletion')}'
                      : '/me',
                ),
                icon: Icon(user == null ? Icons.login : Icons.person_outline),
                label: Text(user == null ? '登入後申請刪除' : '前往我的帳號'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首頁'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletionStep extends StatelessWidget {
  const _DeletionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(number)),
      title: Text(text),
    );
  }
}
