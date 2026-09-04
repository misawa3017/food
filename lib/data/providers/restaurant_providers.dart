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

final paginatedSearchRestaurantsProvider = AsyncNotifierProvider.autoDispose
    .family<
      PaginatedRestaurantSearchNotifier,
      PaginatedRestaurantSearchState,
      RestaurantSearchQuery
    >(PaginatedRestaurantSearchNotifier.new);

class PaginatedRestaurantSearchNotifier
    extends
        AutoDisposeFamilyAsyncNotifier<
          PaginatedRestaurantSearchState,
          RestaurantSearchQuery
        > {
  late RestaurantSearchQuery _query;
  RestaurantSearchPage? _lastPage;

  @override
  Future<PaginatedRestaurantSearchState> build(
    RestaurantSearchQuery query,
  ) async {
    _query = query.normalized();
    final page = await ref
        .watch(restaurantRepositoryProvider)
        .searchRestaurantPage(_query);
    _lastPage = page;
    return PaginatedRestaurantSearchState(
      restaurants: page.restaurants,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    final previousPage = _lastPage;
    if (current == null ||
        previousPage == null ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    state = AsyncData(
      PaginatedRestaurantSearchState(
        restaurants: current.restaurants,
        hasMore: current.hasMore,
        isLoadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(restaurantRepositoryProvider)
          .searchRestaurantPage(_query, previousPage: previousPage);
      _lastPage = page;
      state = AsyncData(
        PaginatedRestaurantSearchState(
          restaurants: [...current.restaurants, ...page.restaurants],
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncData(
        PaginatedRestaurantSearchState(
          restaurants: current.restaurants,
          hasMore: current.hasMore,
          loadMoreError: '載入更多店家失敗，請稍後再試。',
        ),
      );
    }
  }
}

class PaginatedRestaurantSearchState {
  const PaginatedRestaurantSearchState({
    required this.restaurants,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Restaurant> restaurants;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
}

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
