// Firebase settings for the production project.
//
// This file contains Firebase client identifiers, not server credentials.
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
        return ios;
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

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC4dOV9utfBzhaac0DxfSQoz1femurgZHU',
    appId: '1:251427655696:ios:0fe11d5e990904e147fa95',
    messagingSenderId: '251427655696',
    projectId: 'food-prod-9a095',
    storageBucket: 'food-prod-9a095.firebasestorage.app',
    iosClientId:
        '251427655696-dpsor34oq1bglq41eirmpuiu780o2fgq.apps.googleusercontent.com',
    iosBundleId: 'com.misawa.food.foodApp',
  );
}
