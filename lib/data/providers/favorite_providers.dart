import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/favorite_restaurant.dart';
import '../repositories/favorite_repository.dart';
import 'auth_providers.dart';
import 'restaurant_providers.dart';

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
  );
});

final favoriteStatusProvider = StreamProvider.family<bool, String>((
  ref,
  restaurantId,
) {
  ref.watch(authStateChangesProvider);
  return ref.watch(favoriteRepositoryProvider).watchIsFavorite(restaurantId);
});

final favoritesProvider = StreamProvider<List<FavoriteRestaurant>>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(favoriteRepositoryProvider).watchFavorites();
});
