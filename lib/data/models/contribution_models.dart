import 'package:image_picker/image_picker.dart';

import 'restaurant.dart';

class RestaurantContributionDraft {
  const RestaurantContributionDraft({
    required this.name,
    required this.address,
    this.googleMapsUrl,
    this.location,
    required this.categories,
    required this.recommendedDishes,
    required this.amenities,
    required this.photos,
  });

  final String name;
  final String address;
  final String? googleMapsUrl;

  /// Coordinates are optional; contributors can publish using an address only.
  final GeoCoordinates? location;
  final List<String> categories;
  final List<String> recommendedDishes;
  final List<String> amenities;
  final List<XFile> photos;
}

/// The restaurant is created even when a later photo upload fails.
class RestaurantSubmissionResult {
  const RestaurantSubmissionResult({
    required this.restaurantId,
    required this.photoUploadFailed,
  });

  final String restaurantId;
  final bool photoUploadFailed;
}

class DuplicateRestaurantCandidate {
  const DuplicateRestaurantCandidate({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceMeters,
  });

  factory DuplicateRestaurantCandidate.fromMap(Map<Object?, Object?> data) {
    return DuplicateRestaurantCandidate(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '未命名店家',
      address: data['address'] as String? ?? '',
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String name;
  final String address;
  final double distanceMeters;
}
