import 'dart:io';

import 'package:flutter/foundation.dart';

/// AdMob 廣告單元 ID。
///
/// 正式廣告單元只在 release 版使用，開發時一律用 Google 官方測試 ID，
/// 避免誤點正式廣告被判定為無效流量。
class AdUnits {
  const AdUnits._();

  static const iosBannerRelease = 'ca-app-pub-7028927879955041/4227214027';

  static const androidBannerTest = 'ca-app-pub-3940256099942544/9214589741';
  static const androidInterstitialTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosBannerTest = 'ca-app-pub-3940256099942544/2435281174';
  static const iosInterstitialTest = 'ca-app-pub-3940256099942544/4411468910';

  static String get banner {
    if (Platform.isIOS) {
      return kReleaseMode ? iosBannerRelease : iosBannerTest;
    }
    return androidBannerTest;
  }

  /// 目前沒有正式的插頁廣告單元，release 版不載入插頁廣告。
  static String? get interstitial {
    if (kReleaseMode) return null;
    return Platform.isIOS ? iosInterstitialTest : androidInterstitialTest;
  }
}
