import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationRequest {
  const ModerationRequest({
    required this.id,
    required this.type,
    required this.restaurantId,
    required this.reason,
    required this.data,
    required this.createdAt,
  });

  factory ModerationRequest.fromMap(
    String id,
    String type,
    Map<String, dynamic> data,
  ) {
    final createdAt = data['createdAt'];
    return ModerationRequest(
      id: id,
      type: type,
      restaurantId:
          data['restaurantId'] as String? ??
          data['sourceRestaurantId'] as String? ??
          '',
      reason: data['reason'] as String? ?? '',
      data: data,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  final String id;
  final String type;
  final String restaurantId;
  final String reason;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
}
