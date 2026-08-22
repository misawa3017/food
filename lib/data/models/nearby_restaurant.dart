import 'restaurant.dart';

class NearbyRestaurant {
  const NearbyRestaurant({
    required this.restaurant,
    required this.distanceMeters,
  });

  final Restaurant restaurant;
  final double distanceMeters;
}

class NearbySearchResult {
  const NearbySearchResult({required this.restaurants, required this.radiusKm});

  final List<NearbyRestaurant> restaurants;
  final double radiusKm;
}

class NearbyRestaurantQuery {
  const NearbyRestaurantQuery({
    required this.origin,
    this.category,
    this.radiusKm = 10,
  });

  final GeoCoordinates origin;
  final String? category;
  final double radiusKm;

  @override
  bool operator ==(Object other) {
    return other is NearbyRestaurantQuery &&
        other.origin.latitude == origin.latitude &&
        other.origin.longitude == origin.longitude &&
        other.category == category &&
        other.radiusKm == radiusKm;
  }

  @override
  int get hashCode {
    return Object.hash(origin.latitude, origin.longitude, category, radiusKm);
  }
}
