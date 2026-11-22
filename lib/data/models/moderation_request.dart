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

  /// 檢舉目標類型（`restaurant`、`photo`、`review`）
  String? get targetType {
    final value = data['targetType'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 被檢舉的子內容 ID（照片 ID 或評論作者 UID）
  String? get contentId {
    final value = data['contentId'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 重複店家合併時的保留目標店家 ID
  String? get targetRestaurantId {
    final value = data['targetRestaurantId'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// 資料修正申請的變更欄位
  Map<String, dynamic> get changes {
    final raw = data['changes'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const {};
  }
}
