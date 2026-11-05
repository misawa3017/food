import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/block_providers.dart';

/// 封鎖名單，可以在這裡解除封鎖。
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsers = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('封鎖名單')),
      body: blockedUsers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('無法載入封鎖名單，請稍後再試。')),
        data: (users) => users.isEmpty
            ? const Center(child: Text('你沒有封鎖任何使用者。'))
            : ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: const Icon(Icons.block),
                    title: Text(user.displayName),
                    trailing: TextButton(
                      onPressed: () => _unblock(context, ref, user.uid),
                      child: const Text('解除封鎖'),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref, String uid) async {
    try {
      await ref.read(blockRepositoryProvider).unblockUser(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已解除封鎖。')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('解除封鎖失敗，請稍後再試。')));
      }
    }
  }
}
