import 'package:flutter_test/flutter_test.dart';

import 'package:food_app/core/utils/geo_utils.dart';
import 'package:food_app/data/models/restaurant.dart';

void main() {
  const taipeiMainStation = GeoCoordinates(
    latitude: 25.0478,
    longitude: 121.517,
  );

  test('uses coarser geohash precision as radius expands', () {
    expect(GeoUtils.precisionForRadius(3), 5);
    expect(GeoUtils.precisionForRadius(10), 4);
    expect(GeoUtils.precisionForRadius(30), 3);
  });

  test('creates unique center and neighbor query ranges', () {
    final ranges = GeoUtils.queryRanges(center: taipeiMainStation, radiusKm: 3);

    expect(ranges, hasLength(9));
    expect(ranges.map((range) => range.start).toSet(), hasLength(9));
    for (final range in ranges) {
      expect(range.end, '${range.start}\uf8ff');
    }
  });

  test('calculates a realistic distance between Taipei landmarks', () {
    const taipei101 = GeoCoordinates(latitude: 25.0339, longitude: 121.5645);

    final distance = GeoUtils.distanceMeters(taipeiMainStation, taipei101);

    expect(distance, greaterThan(4500));
    expect(distance, lessThan(5500));
  });
}
