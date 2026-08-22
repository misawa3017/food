import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/imported_place.dart';
import '../repositories/imported_places_repository.dart';
import 'account_providers.dart';
import 'auth_providers.dart';
import 'restaurant_providers.dart';

final importedPlacesRepositoryProvider = Provider<ImportedPlacesRepository>((
  ref,
) {
  return ImportedPlacesRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseFunctions: ref.watch(firebaseFunctionsProvider),
  );
});

final importedPlacesProvider = StreamProvider<List<ImportedPlace>>((ref) {
  final uid = ref.watch(authStateChangesProvider).asData?.value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(importedPlacesRepositoryProvider).watchImportedPlaces(uid);
});
