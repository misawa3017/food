import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantPhoto {
  const RestaurantPhoto({
    required this.id,
    required this.url,
    required this.status,
    this.uploadedBy,
    required this.createdAt,
  });

  factory RestaurantPhoto.fromMap(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return RestaurantPhoto(
      id: id,
      url: data['url'] as String? ?? '',
      status: data['status'] as String? ?? 'removed',
      uploadedBy: data['uploadedBy'] as String?,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt is DateTime
          ? createdAt
          : null,
    );
  }

  final String id;
  final String url;
  final String status;
  final String? uploadedBy;
  final DateTime? createdAt;
}
