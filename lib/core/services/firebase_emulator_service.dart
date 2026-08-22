import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseEmulatorService {
  const FirebaseEmulatorService();

  static const enabled = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  Future<void> connect() async {
    if (!enabled) {
      return;
    }

    const host = 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(
      region: 'asia-east1',
    ).useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);

    if (kDebugMode) {
      debugPrint('Firebase Emulators 已啟用。');
    }
  }
}
