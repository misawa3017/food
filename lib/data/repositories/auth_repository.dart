import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;

  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_mapUser);
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters(const {'prompt': 'select_account'});
      await _firebaseAuth.signInWithRedirect(provider);
      return;
    }

    final credential = await _googleCredential();
    await _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signInWithApple() async {
    final provider = _appleProvider();
    if (kIsWeb) {
      await _firebaseAuth.signInWithPopup(provider);
      return;
    }

    await _firebaseAuth.signInWithProvider(provider);
  }

  Future<void> reauthenticateForAccountDeletion() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'requires-sign-in',
        message: '請先登入後再刪除帳號。',
      );
    }

    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (providerIds.contains('apple.com')) {
      final provider = _appleProvider();
      final credential = kIsWeb
          ? await user.reauthenticateWithPopup(provider)
          : await user.reauthenticateWithProvider(provider);
      final authorizationCode =
          credential.additionalUserInfo?.authorizationCode;
      if (authorizationCode == null || authorizationCode.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-apple-authorization-code',
          message: '無法取得 Apple 授權碼，請重新登入後再試。',
        );
      }
      await _firebaseAuth.revokeTokenWithAuthorizationCode(authorizationCode);
    } else if (providerIds.contains('google.com')) {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters(const {'prompt': 'select_account'});
        await user.reauthenticateWithPopup(provider);
      } else {
        final credential = await _googleCredential();
        await user.reauthenticateWithCredential(credential);
      }
    } else {
      throw FirebaseAuthException(
        code: 'unsupported-reauthentication-provider',
        message: '目前無法重新驗證這個登入方式。',
      );
    }

    await _firebaseAuth.currentUser?.getIdToken(true);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _clearGoogleSession();
  }

  Future<void> clearLocalSession() async {
    await _firebaseAuth.signOut();
    await _clearGoogleSession();
  }

  Future<OAuthCredential> _googleCredential() async {
    await _ensureGoogleInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google 登入未提供有效的 ID token。',
      );
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  AppleAuthProvider _appleProvider() {
    return AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
  }

  Future<void> _clearGoogleSession() async {
    if (kIsWeb) {
      return;
    }
    await _ensureGoogleInitialized();
    await _googleSignIn.signOut();
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitialization ??= _googleSignIn.initialize();
  }

  AuthUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AuthUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      providerIds: user.providerData
          .map((provider) => provider.providerId)
          .toList(growable: false),
    );
  }
}
