import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/contribution_repository.dart';
import 'account_providers.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final contributionRepositoryProvider = Provider<ContributionRepository>((ref) {
  return ContributionRepository(
    firebaseFunctions: ref.watch(firebaseFunctionsProvider),
    firebaseStorage: ref.watch(firebaseStorageProvider),
  );
});
