import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'firebase_emulator_service.dart';

class AppCheckService {
  const AppCheckService();

  static const _webEnterpriseSiteKey = String.fromEnvironment(
    'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY',
  );

  Future<void> activate() async {
    if (FirebaseEmulatorService.enabled) {
      if (kDebugMode) {
        debugPrint('Firebase App Check skipped for local emulators.');
      }
      return;
    }

    if (kIsWeb && kReleaseMode && _webEnterpriseSiteKey.isEmpty) {
      throw StateError(
        'Release Web build requires '
        'FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY.',
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: kDebugMode
          ? WebDebugProvider()
          : ReCaptchaEnterpriseProvider(_webEnterpriseSiteKey),
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  /// 預先取得並快取 App Check token，避免第一個受保護請求才開始驗證。
  ///
  /// 不等待此程序完成，讓首頁仍能優先顯示；失敗時由 Firebase SDK 在真正請求時重試。
  Future<void> warmUpToken() async {
    try {
      await FirebaseAppCheck.instance.getToken();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('App Check token 預取失敗：$error');
      }
    }
  }
}
