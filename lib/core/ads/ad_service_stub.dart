import 'ad_service_contract.dart';

AdService createAdService() => const StubAdService();

class StubAdService implements AdService {
  const StubAdService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<String?> showPrivacyOptions() async => null;

  @override
  Future<void> showInterstitial() async {}

  @override
  void dispose() {}
}
