import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/geo_utils.dart';
import '../models/nearby_restaurant.dart';
import '../models/restaurant.dart';
import '../models/restaurant_photo.dart';
import '../models/restaurant_review.dart';

class RestaurantRepository {
  RestaurantRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<Restaurant>> watchLatestRestaurants({int limit = 20}) {
    return _firestore
        .collection('restaurants')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_restaurantsFromSnapshot);
  }

  Future<List<Restaurant>> searchRestaurants(
    RestaurantSearchQuery searchQuery,
  ) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('restaurants')
        .where('status', isEqualTo: 'active');

    if (searchQuery.category != null) {
      query = query.where('categories', arrayContains: searchQuery.category);
    }

    if (searchQuery.keyword.isNotEmpty) {
      query = query
          .where('nameLower', isGreaterThanOrEqualTo: searchQuery.keyword)
          .where(
            'nameLower',
            isLessThanOrEqualTo: '${searchQuery.keyword}\uf8ff',
          )
          .orderBy('nameLower');
    } else {
      query = query.orderBy('createdAt', descending: true);
    }

    final snapshot = await query.limit(searchQuery.limit).get();
    return _restaurantsFromSnapshot(snapshot);
  }

  Future<NearbySearchResult> findNearbyRestaurants(
    NearbyRestaurantQuery nearbyQuery,
  ) async {
    final restaurants = await _findRestaurantsWithinRadius(
      nearbyQuery,
      nearbyQuery.radiusKm,
    );
    return NearbySearchResult(
      restaurants: restaurants,
      radiusKm: nearbyQuery.radiusKm,
    );
  }

  Future<List<NearbyRestaurant>> _findRestaurantsWithinRadius(
    NearbyRestaurantQuery nearbyQuery,
    double radiusKm,
  ) async {
    final ranges = GeoUtils.queryRanges(
      center: nearbyQuery.origin,
      radiusKm: radiusKm,
    );
    final snapshots = await Future.wait(
      ranges.map((range) {
        Query<Map<String, dynamic>> query = _firestore
            .collection('restaurants')
            .where('status', isEqualTo: 'active');
        if (nearbyQuery.category != null) {
          query = query.where(
            'categories',
            arrayContains: nearbyQuery.category,
          );
        }
        return query
            .where('geohash', isGreaterThanOrEqualTo: range.start)
            .where('geohash', isLessThanOrEqualTo: range.end)
            .orderBy('geohash')
            .limit(50)
            .get();
      }),
    );

    final restaurantsById = <String, Restaurant>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        restaurantsById[document.id] = Restaurant.fromMap(
          document.id,
          document.data(),
        );
      }
    }

    final radiusMeters = radiusKm * 1000;
    final nearbyRestaurants = <NearbyRestaurant>[];
    for (final restaurant in restaurantsById.values) {
      final location = restaurant.location;
      if (location == null) {
        continue;
      }
      final distanceMeters = GeoUtils.distanceMeters(
        nearbyQuery.origin,
        location,
      );
      if (distanceMeters <= radiusMeters) {
        nearbyRestaurants.add(
          NearbyRestaurant(
            restaurant: restaurant,
            distanceMeters: distanceMeters,
          ),
        );
      }
    }
    nearbyRestaurants.sort(
      (first, second) => first.distanceMeters.compareTo(second.distanceMeters),
    );
    return nearbyRestaurants;
  }

  Stream<Restaurant?> watchRestaurant(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return snapshot.exists && data != null
              ? Restaurant.fromMap(snapshot.id, data)
              : null;
        });
  }

  Stream<List<RestaurantPhoto>> watchPhotos(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('photos')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                return RestaurantPhoto.fromMap(document.id, document.data());
              })
              .toList(growable: false),
        );
  }

  Stream<List<RestaurantReview>> watchReviews(String restaurantId) {
    return _firestore
        .collection('restaurants')
        .doc(restaurantId)
        .collection('reviews')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                return RestaurantReview.fromMap(document.id, document.data());
              })
              .toList(growable: false),
        );
  }

  List<Restaurant> _restaurantsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((document) => Restaurant.fromMap(document.id, document.data()))
        .toList(growable: false);
  }
}

class RestaurantSearchQuery {
  const RestaurantSearchQuery({
    this.keyword = '',
    this.category,
    this.limit = 30,
  });

  final String keyword;
  final String? category;
  final int limit;

  RestaurantSearchQuery normalized() {
    return RestaurantSearchQuery(
      keyword: keyword.trim().toLowerCase(),
      category: category,
      limit: limit,
    );
  }

  /// 將已同步的公開店家目錄依搜尋條件篩選。
  ///
  /// 名稱規則與 Firestore 的前綴搜尋相同，避免快取結果與原查詢行為不同。
  List<Restaurant> filterCatalog(Iterable<Restaurant> restaurants) {
    final normalizedQuery = normalized();
    final matches = restaurants.where((restaurant) {
      final category = normalizedQuery.category;
      if (category != null && !restaurant.categories.contains(category)) {
        return false;
      }
      return normalizedQuery.keyword.isEmpty ||
          restaurant.nameLower.startsWith(normalizedQuery.keyword);
    }).toList(growable: false);

    if (normalizedQuery.keyword.isEmpty) {
      return matches.take(normalizedQuery.limit).toList(growable: false);
    }

    final sorted = [...matches]
      ..sort((first, second) => first.nameLower.compareTo(second.nameLower));
    return sorted.take(normalizedQuery.limit).toList(growable: false);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantSearchQuery &&
        other.keyword == keyword &&
        other.category == category &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(keyword, category, limit);
}
