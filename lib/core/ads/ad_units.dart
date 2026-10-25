import 'dart:io';

/// AdMob 廣告單元 ID。
///
/// 目前一律使用 Google 官方測試 ID；正式 ID 要在 AdMob 建立 App 後，
/// 只在 release 版使用，避免開發時誤點正式廣告被判定為無效流量。
class AdUnits {
  const AdUnits._();

  static const androidBannerTest = 'ca-app-pub-3940256099942544/9214589741';
  static const androidInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosBannerTest = 'ca-app-pub-3940256099942544/2435281174';
  static const iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';

  static String get banner =>
      Platform.isIOS ? iosBannerTest : androidBannerTest;

  static String get interstitial =>
      Platform.isIOS ? iosInterstitialTest : androidInterstitialTest;
}
