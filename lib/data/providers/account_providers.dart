import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/account_repository.dart';
import 'auth_providers.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: 'asia-east1');
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    authRepository: ref.watch(authRepositoryProvider),
    firebaseFunctions: ref.watch(firebaseFunctionsProvider),
  );
});
