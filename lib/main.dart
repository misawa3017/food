import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_bootstrap.dart';
import 'core/ads/adsense_loader.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdSenseLoader.load();
  runApp(const ProviderScope(child: AppBootstrap()));
}
