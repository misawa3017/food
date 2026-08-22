import 'package:url_launcher/url_launcher.dart';

import '../../data/models/restaurant.dart';

class ExternalNavigationService {
  const ExternalNavigationService();

  Future<bool> openDirections(Restaurant restaurant) {
    final savedGoogleMapsUri = restaurant.googleMapsUrl == null
        ? null
        : Uri.tryParse(restaurant.googleMapsUrl!);
    if (savedGoogleMapsUri != null) {
      return launchUrl(
        savedGoogleMapsUri,
        mode: LaunchMode.externalApplication,
      );
    }
    final location = restaurant.location;
    final destination = location == null
        ? restaurant.address
        : '${location.latitude},${location.longitude}';
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
