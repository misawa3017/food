import 'restaurant.dart';

enum LocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationResult {
  const LocationResult._({this.coordinates, this.failure});

  const LocationResult.success(GeoCoordinates coordinates)
    : this._(coordinates: coordinates);

  const LocationResult.failed(LocationFailure failure)
    : this._(failure: failure);

  final GeoCoordinates? coordinates;
  final LocationFailure? failure;

  bool get isSuccess => coordinates != null;
}
