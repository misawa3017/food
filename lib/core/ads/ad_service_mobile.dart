import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service_contract.dart';
import 'ad_units.dart';

AdService createAdService() => MobileAdService();

class MobileAdService implements AdService {
  Future<bool>? _initialization;
  InterstitialAd? _interstitialAd;
  bool _mobileAdsInitialized = false;
  bool _interstitialLoading = false;

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Future<bool> initialize() {
    if (!isSupported) return Future.value(false);
    return _initialization ??= _initialize();
  }

  Future<bool> _initialize() async {
    final updateCompleter = Completer<FormError?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updateCompleter.complete(),
      updateCompleter.complete,
    );
    final updateError = await updateCompleter.future;
    if (updateError == null) {
      await ConsentForm.loadAndShowConsentFormIfRequired((formError) {
        if (formError != null) {
          debugPrint('UMP consent form failed: ${formError.message}');
        }
      });
    } else {
      debugPrint('UMP consent update failed: ${updateError.message}');
    }
    return _ensureMobileAdsInitialized();
  }

  Future<bool> _ensureMobileAdsInitialized() async {
    if (_mobileAdsInitialized) return true;
    if (!await ConsentInformation.instance.canRequestAds()) return false;
    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
    _loadInterstitial();
    return true;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    if (!isSupported) return false;
    await initialize();
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<String?> showPrivacyOptions() async {
    if (!isSupported) return null;
    await initialize();
    String? message;
    await ConsentForm.showPrivacyOptionsForm((formError) {
      message = formError?.message;
    });
    await _ensureMobileAdsInitialized();
    return message;
  }

  void _loadInterstitial() {
    if (!_mobileAdsInitialized ||
        _interstitialLoading ||
        _interstitialAd != null) {
      return;
    }
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AdUnits.androidInterstitialTest,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialLoading = false;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    if (!await initialize()) return;
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
