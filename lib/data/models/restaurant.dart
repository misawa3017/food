import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.nameLower,
    required this.address,
    this.googleMapsUrl,
    required this.location,
    required this.categories,
    required this.recommendedDishes,
    this.amenities = const [],
    required this.coverPhotoUrl,
    required this.photoCount,
    required this.ratingSum,
    required this.ratingCount,
    required this.favoriteCount,
    required this.status,
    required this.mergedIntoRestaurantId,
    required this.createdAt,
    this.recommenderName = '匿名美食家',
  });

  factory Restaurant.fromMap(String id, Map<String, dynamic> data) {
    return Restaurant(
      id: id,
      name: data['name'] as String? ?? '未命名店家',
      nameLower: data['nameLower'] as String? ?? '',
      address: data['address'] as String? ?? '',
      googleMapsUrl: _nullableString(data['googleMapsUrl']),
      location: GeoCoordinates.fromValueOrNull(data['geo']),
      categories: _stringList(data['categories']),
      recommendedDishes: _stringList(data['recommendedDishes']),
      amenities: _stringList(data['amenities']),
      coverPhotoUrl: _nullableString(data['coverPhotoUrl']),
      photoCount: _nonNegativeInt(data['photoCount']),
      ratingSum: _nonNegativeDouble(data['ratingSum']),
      ratingCount: _nonNegativeInt(data['ratingCount']),
      favoriteCount: _nonNegativeInt(data['favoriteCount']),
      status: data['status'] as String? ?? 'removed',
      mergedIntoRestaurantId: _nullableString(data['mergedIntoRestaurantId']),
      createdAt: _dateTime(data['createdAt']),
      recommenderName: _nullableString(data['recommenderName']) ?? '匿名美食家',
    );
  }

  final String id;
  final String name;
  final String nameLower;
  final String address;
  final String? googleMapsUrl;
  final GeoCoordinates? location;
  final List<String> categories;
  final List<String> recommendedDishes;
  final List<String> amenities;
  final String? coverPhotoUrl;
  final int photoCount;
  final double ratingSum;
  final int ratingCount;
  final int favoriteCount;
  final String status;
  final String? mergedIntoRestaurantId;
  final DateTime? createdAt;
  final String recommenderName;

  double get averageRating => ratingCount == 0 ? 0 : ratingSum / ratingCount;
  bool get isActive => status == 'active';
  bool get isMerged => status == 'merged';
}

class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  factory GeoCoordinates.fromValue(Object? value) {
    if (value is GeoPoint) {
      return GeoCoordinates(
        latitude: value.latitude,
        longitude: value.longitude,
      );
    }
    if (value is Map) {
      final latitude = value['lat'];
      final longitude = value['lng'];
      if (latitude is num && longitude is num) {
        return GeoCoordinates(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        );
      }
    }
    throw const FormatException('Invalid geo coordinates');
  }

  static GeoCoordinates? fromValueOrNull(Object? value) {
    try {
      return GeoCoordinates.fromValue(value);
    } on FormatException {
      return null;
    }
  }

  final double latitude;
  final double longitude;
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

String? _nullableString(Object? value) {
  return value is String && value.trim().isNotEmpty ? value : null;
}

int _nonNegativeInt(Object? value) {
  if (value is! num) {
    return 0;
  }
  final converted = value.toInt();
  return converted < 0 ? 0 : converted;
}

double _nonNegativeDouble(Object? value) {
  if (value is! num) {
    return 0;
  }
  final converted = value.toDouble();
  return converted.isFinite && converted > 0 ? converted : 0;
}

DateTime? _dateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}
