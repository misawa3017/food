import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/moderation_request.dart';
import 'auth_providers.dart';
import 'contribution_providers.dart';
import 'restaurant_providers.dart';

final adminStatusProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateChangesProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((snapshot) => snapshot.exists);
});

final pendingEditRequestsProvider = StreamProvider<List<ModerationRequest>>((
  ref,
) {
  return _watchRequests(ref, 'restaurantEditRequests', 'edit');
});

final pendingReportsProvider = StreamProvider<List<ModerationRequest>>((ref) {
  return _watchRequests(ref, 'reports', 'report');
});

final pendingMergeRequestsProvider = StreamProvider<List<ModerationRequest>>((
  ref,
) {
  return _watchRequests(ref, 'restaurantMergeRequests', 'merge');
});

final adminRestaurantDailyLimitProvider = FutureProvider<int>((ref) {
  return ref.watch(contributionRepositoryProvider).getRestaurantDailyLimit();
});

Stream<List<ModerationRequest>> _watchRequests(
  Ref ref,
  String collection,
  String type,
) {
  return ref
      .watch(firestoreProvider)
      .collection(collection)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt')
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ModerationRequest.fromMap(doc.id, type, doc.data()))
            .toList(growable: false),
      );
}
