import 'package:url_launcher/url_launcher.dart';

/// 使用條款與隱私權政策的公開網址（放在 prod 的 Firebase Hosting）。
class LegalLinks {
  const LegalLinks._();

  static final terms = Uri.parse('https://food-prod-9a095.web.app/terms.html');
  static final privacy = Uri.parse(
    'https://food-prod-9a095.web.app/privacy.html',
  );

  static Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
