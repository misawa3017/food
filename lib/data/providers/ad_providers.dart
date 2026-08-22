import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ad_service.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final service = createAdService();
  ref.onDispose(service.dispose);
  return service;
});

final adInitializationProvider = FutureProvider<bool>((ref) {
  return ref.watch(adServiceProvider).initialize();
});

final adPrivacyOptionsRequiredProvider = FutureProvider<bool>((ref) {
  return ref.watch(adServiceProvider).isPrivacyOptionsRequired();
});
