import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_result.dart';
import '../repositories/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final currentLocationProvider = FutureProvider<LocationResult>((ref) {
  return ref.watch(locationRepositoryProvider).getCurrentLocation();
});
