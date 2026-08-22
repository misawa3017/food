// Firebase settings for the production project.
//
// This file contains Firebase client identifiers, not server credentials.
// Generate it again with FlutterFire CLI when a production iOS app is added.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class ProductionFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'Production Firebase has not been configured for iOS yet.',
        );
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Production Firebase is not configured for this platform.',
        );
      default:
        throw UnsupportedError(
          'Production Firebase is not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCKYxKi8oRUv-HFRBGUigbLoaOD6pgXMC8',
    appId: '1:251427655696:web:34c2329999ca015b47fa95',
    messagingSenderId: '251427655696',
    projectId: 'food-prod-9a095',
    authDomain: 'food-prod-9a095.web.app',
    storageBucket: 'food-prod-9a095.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA-q4WAwsheub-ClMWJh00tyDYJ57VksIE',
    appId: '1:251427655696:android:ce351fc790054ab847fa95',
    messagingSenderId: '251427655696',
    projectId: 'food-prod-9a095',
    storageBucket: 'food-prod-9a095.firebasestorage.app',
  );
}
