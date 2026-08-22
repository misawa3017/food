import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/app_check_service.dart';
import 'core/services/firebase_emulator_service.dart';
import 'firebase_environment.dart';

/// Shows a first Flutter frame before Firebase and App Check finish starting.
///
/// [FoodApp] is only built after the security services are ready, so no
/// Firestore, Storage, or callable request can run without App Check.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<void> _initialization = _initialize();

  Future<void> _initialize() async {
    await Firebase.initializeApp(options: FirebaseEnvironment.options);
    if (kIsWeb) {
      await FirebaseAuth.instance.getRedirectResult();
    }
    await const FirebaseEmulatorService().connect();
    const appCheckService = AppCheckService();
    await appCheckService.activate();
    unawaited(appCheckService.warmUpToken());
  }

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const FoodApp();
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFF7F7F2),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 48),
                          const SizedBox(height: 16),
                          const Text('啟動服務時發生問題。'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _retry,
                            child: const Text('重新嘗試'),
                          ),
                        ],
                      )
                    : const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu, size: 48),
                          SizedBox(height: 16),
                          SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '管吃',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('正在準備美食資訊…'),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
