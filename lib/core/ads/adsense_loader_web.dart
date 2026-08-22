import 'package:web/web.dart' as web;

import '../../firebase_environment.dart';

/// Loads the AdSense library only in the production web build.
///
/// The publisher ID is supplied by `ADSENSE_PUBLISHER_ID` at build time so it
/// is never embedded in a development build or committed to source control.
class AdSenseLoader {
  const AdSenseLoader._();

  static const _publisherId = String.fromEnvironment('ADSENSE_PUBLISHER_ID');
  static const _scriptSelector = 'script[data-food-adsense="true"]';

  static void load() {
    if (FirebaseEnvironment.name != 'prod' || _publisherId.isEmpty) {
      return;
    }

    if (web.document.head?.querySelector(_scriptSelector) != null) {
      return;
    }

    final script = web.HTMLScriptElement()
      ..async = true
      ..src =
          'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=$_publisherId'
      ..crossOrigin = 'anonymous'
      ..setAttribute('data-food-adsense', 'true');
    web.document.head?.append(script);
  }
}
