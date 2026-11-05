import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/block_repository.dart';
import 'auth_providers.dart';
import 'restaurant_providers.dart';

final blockRepositoryProvider = Provider<BlockRepository>((ref) {
  return BlockRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
  );
});

final blockedUsersProvider = StreamProvider<List<BlockedUser>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(blockRepositoryProvider).watchBlockedUsers();
});

/// 目前使用者封鎖的帳號 ID；未登入或尚未載入時為空集合，不擋住內容顯示。
final blockedUserIdsProvider = Provider<Set<String>>((ref) {
  final users = ref.watch(blockedUsersProvider).asData?.value ?? const [];
  return {for (final user in users) user.uid};
});
