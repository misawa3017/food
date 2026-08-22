import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/restaurant.dart';
import '../models/nearby_restaurant.dart';
import '../models/restaurant_photo.dart';
import '../models/restaurant_review.dart';
import '../repositories/restaurant_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepository(firestore: ref.watch(firestoreProvider));
});

final latestRestaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  return ref.watch(restaurantRepositoryProvider).watchLatestRestaurants();
});

/// 搜尋頁使用的公開店家快取。
///
/// 首頁先建立這個串流，讓使用者點選分類時可以直接在本機篩選，
/// 避免每次切換分類都重新等待 Firestore 查詢。
final searchCatalogProvider = StreamProvider<List<Restaurant>>((ref) {
  return ref
      .watch(restaurantRepositoryProvider)
      .watchLatestRestaurants(limit: 50);
});

final searchRestaurantsProvider =
    FutureProvider.family<List<Restaurant>, RestaurantSearchQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(restaurantRepositoryProvider)
          .searchRestaurants(query.normalized());
    });

final nearbyRestaurantsProvider =
    FutureProvider.family<NearbySearchResult, NearbyRestaurantQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(restaurantRepositoryProvider)
          .findNearbyRestaurants(query);
    });

final restaurantProvider = StreamProvider.family<Restaurant?, String>((
  ref,
  restaurantId,
) {
  return ref.watch(restaurantRepositoryProvider).watchRestaurant(restaurantId);
});

final restaurantPhotosProvider =
    StreamProvider.family<List<RestaurantPhoto>, String>((ref, restaurantId) {
      return ref.watch(restaurantRepositoryProvider).watchPhotos(restaurantId);
    });

final restaurantReviewsProvider =
    StreamProvider.family<List<RestaurantReview>, String>((ref, restaurantId) {
      return ref.watch(restaurantRepositoryProvider).watchReviews(restaurantId);
    });
