import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/geo_utils.dart';
import '../models/nearby_restaurant.dart';
import '../models/restaurant.dart';
import '../models/restaurant_photo.dart';
import '../models/restaurant_review.dart';

class RestaurantRepository {
  static const _keywordScanBatchSize = 100;

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
    return (await searchRestaurantPage(searchQuery)).restaurants;
  }

  /// 依搜尋條件取得一頁店家，並保留下一頁所需的 Firestore 游標。
  Future<RestaurantSearchPage> searchRestaurantPage(
    RestaurantSearchQuery searchQuery, {
    RestaurantSearchPage? previousPage,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('restaurants')
        .where('status', isEqualTo: 'active');

    if (searchQuery.category != null) {
      query = query.where('categories', arrayContains: searchQuery.category);
    }

    if (searchQuery.keyword.isNotEmpty) {
      return _scanKeywordPage(
        query.orderBy('nameLower'),
        searchQuery,
        previousPage,
      );
    }
    query = query.orderBy('createdAt', descending: true);

    final lastDocument = previousPage?._lastDocument;
    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final snapshot = await query.limit(searchQuery.limit + 1).get();
    final visibleDocuments = snapshot.docs
        .take(searchQuery.limit)
        .toList(growable: false);
    return RestaurantSearchPage._(
      restaurants: visibleDocuments
          .map((document) => Restaurant.fromMap(document.id, document.data()))
          .toList(growable: false),
      hasMore: snapshot.docs.length > searchQuery.limit,
      lastDocument: visibleDocuments.isEmpty ? null : visibleDocuments.last,
    );
  }

  /// 分批讀取店家並在本機比對店名，直到湊滿一頁或讀完為止。
  ///
  /// Firestore 只支援前綴查詢，無法直接搜尋店名中段的文字。
  Future<RestaurantSearchPage> _scanKeywordPage(
    Query<Map<String, dynamic>> orderedQuery,
    RestaurantSearchQuery searchQuery,
    RestaurantSearchPage? previousPage,
  ) async {
    final matches = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var cursor = previousPage?._lastDocument;
    while (true) {
      final batchQuery = cursor == null
          ? orderedQuery
          : orderedQuery.startAfterDocument(cursor);
      final snapshot = await batchQuery.limit(_keywordScanBatchSize).get();
      for (final document in snapshot.docs) {
        final restaurant = Restaurant.fromMap(document.id, document.data());
        if (!searchQuery.matchesKeyword(restaurant)) continue;
        if (matches.length == searchQuery.limit) {
          return RestaurantSearchPage._(
            restaurants: _restaurantsFromDocuments(matches),
            hasMore: true,
            lastDocument: matches.last,
          );
        }
        matches.add(document);
      }
      if (snapshot.docs.length < _keywordScanBatchSize) {
        return RestaurantSearchPage._(
          restaurants: _restaurantsFromDocuments(matches),
          hasMore: false,
          lastDocument: matches.isEmpty ? null : matches.last,
        );
      }
      cursor = snapshot.docs.last;
    }
  }

  List<Restaurant> _restaurantsFromDocuments(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return documents
        .map((document) => Restaurant.fromMap(document.id, document.data()))
        .toList(growable: false);
  }

  /// 依收藏清單讀取目前仍公開的完整店家資料。
  Future<List<Restaurant>> getRestaurantsByIds(Iterable<String> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return const [];

    final snapshots = <QuerySnapshot<Map<String, dynamic>>>[];
    for (var index = 0; index < uniqueIds.length; index += 30) {
      final end = (index + 30).clamp(0, uniqueIds.length);
      snapshots.add(
        await _firestore
            .collection('restaurants')
            .where('status', isEqualTo: 'active')
            .where(FieldPath.documentId, whereIn: uniqueIds.sublist(index, end))
            .get(),
      );
    }

    final restaurantsById = <String, Restaurant>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        restaurantsById[document.id] = Restaurant.fromMap(
          document.id,
          document.data(),
        );
      }
    }
    return uniqueIds
        .map((id) => restaurantsById[id])
        .whereType<Restaurant>()
        .toList(growable: false);
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

  /// 店名包含關鍵字即符合，關鍵字需先經過 [normalized] 處理。
  bool matchesKeyword(Restaurant restaurant) {
    return keyword.isEmpty || restaurant.nameLower.contains(keyword);
  }

  /// 將已同步的公開店家目錄依搜尋條件篩選。
  ///
  /// 名稱規則與 [RestaurantRepository] 的關鍵字搜尋相同，避免兩邊結果不一致。
  List<Restaurant> filterCatalog(Iterable<Restaurant> restaurants) {
    final normalizedQuery = normalized();
    final matches = restaurants
        .where((restaurant) {
          final category = normalizedQuery.category;
          if (category != null && !restaurant.categories.contains(category)) {
            return false;
          }
          return normalizedQuery.matchesKeyword(restaurant);
        })
        .toList(growable: false);

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

class RestaurantSearchPage {
  const RestaurantSearchPage._({
    required this.restaurants,
    required this.hasMore,
    required DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) : _lastDocument = lastDocument;

  final List<Restaurant> restaurants;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
}
