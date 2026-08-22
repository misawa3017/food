import 'package:dart_geohash/dart_geohash.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/restaurant.dart';

class GeoHashQueryRange {
  const GeoHashQueryRange({required this.start, required this.end});

  final String start;
  final String end;
}

class GeoUtils {
  GeoUtils._();

  static final GeoHasher _geoHasher = GeoHasher();

  static int precisionForRadius(double radiusKm) {
    if (radiusKm <= 3) {
      return 5;
    }
    if (radiusKm <= 10) {
      return 4;
    }
    return 3;
  }

  static List<GeoHashQueryRange> queryRanges({
    required GeoCoordinates center,
    required double radiusKm,
  }) {
    final precision = precisionForRadius(radiusKm);
    final centerHash = _geoHasher.encode(
      center.longitude,
      center.latitude,
      precision: precision,
    );
    final prefixes = _geoHasher.neighbors(centerHash).values.toSet().toList()
      ..sort();

    return prefixes
        .map((prefix) => GeoHashQueryRange(start: prefix, end: '$prefix\uf8ff'))
        .toList(growable: false);
  }

  static double distanceMeters(
    GeoCoordinates origin,
    GeoCoordinates destination,
  ) {
    return Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
  }
}
