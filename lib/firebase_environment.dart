import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'firebase_options_prod.dart';

/// Selects Firebase using an explicit compile-time build environment.
///
/// Use `--dart-define=FIREBASE_ENV=prod` for release builds. Local builds
/// intentionally default to development to protect production data.
class FirebaseEnvironment {
  static const name = String.fromEnvironment(
    'FIREBASE_ENV',
    defaultValue: 'dev',
  );

  static FirebaseOptions get options {
    switch (name) {
      case 'dev':
        return DefaultFirebaseOptions.currentPlatform;
      case 'prod':
        return ProductionFirebaseOptions.currentPlatform;
      default:
        throw ArgumentError.value(
          name,
          'FIREBASE_ENV',
          'Expected either dev or prod.',
        );
    }
  }
}
