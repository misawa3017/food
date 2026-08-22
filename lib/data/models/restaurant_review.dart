import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantReview {
  const RestaurantReview({
    required this.id,
    required this.rating,
    required this.text,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.status,
    required this.createdAt,
  });

  factory RestaurantReview.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return RestaurantReview(
      id: id,
      rating: _rating(data['rating']),
      text: data['text'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '美食通使用者',
      authorPhotoUrl: _nullableString(data['authorPhotoUrl']),
      status: data['status'] as String? ?? 'removed',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt is DateTime
          ? createdAt
          : null,
    );
  }

  final String id;
  final int rating;
  final String text;
  final String authorName;
  final String? authorPhotoUrl;
  final String status;
  final DateTime? createdAt;
}

String? _nullableString(Object? value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

int _rating(Object? value) {
  if (value is! num) {
    return 1;
  }
  final rating = value.toInt();
  if (rating < 1) {
    return 1;
  }
  return rating > 5 ? 5 : rating;
}
