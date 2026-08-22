import 'package:cloud_firestore/cloud_firestore.dart';

class FavoriteRestaurant {
  const FavoriteRestaurant({
    required this.restaurantId,
    required this.name,
    required this.coverPhotoUrl,
    required this.categories,
    required this.addedAt,
  });

  factory FavoriteRestaurant.fromMap(
    String restaurantId,
    Map<String, dynamic> data,
  ) {
    final categories = data['restaurantCategories'];
    final addedAt = data['addedAt'];
    return FavoriteRestaurant(
      restaurantId: restaurantId,
      name: data['restaurantName'] as String? ?? '未命名店家',
      coverPhotoUrl: data['restaurantCoverPhotoUrl'] as String?,
      categories: categories is Iterable
          ? categories.whereType<String>().toList(growable: false)
          : const [],
      addedAt: addedAt is Timestamp ? addedAt.toDate() : null,
    );
  }

  final String restaurantId;
  final String name;
  final String? coverPhotoUrl;
  final List<String> categories;
  final DateTime? addedAt;
}
