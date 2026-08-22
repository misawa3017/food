abstract interface class AdService {
  bool get isSupported;

  Future<bool> initialize();

  Future<bool> isPrivacyOptionsRequired();

  Future<String?> showPrivacyOptions();

  Future<void> showInterstitial();

  void dispose();
}
