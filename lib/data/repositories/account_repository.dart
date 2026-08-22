import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/firebase_emulator_service.dart';
import 'auth_repository.dart';

class AccountRepository {
  AccountRepository({
    required AuthRepository authRepository,
    required FirebaseFunctions firebaseFunctions,
  }) : _authRepository = authRepository,
       _firebaseFunctions = firebaseFunctions;

  final AuthRepository _authRepository;
  final FirebaseFunctions _firebaseFunctions;

  Future<void> deleteAccount() async {
    try {
      await _authRepository.reauthenticateForAccountDeletion();
      final callable = _firebaseFunctions.httpsCallable(
        'deleteAccount',
        options: HttpsCallableOptions(
          limitedUseAppCheckToken: !FirebaseEmulatorService.enabled,
        ),
      );
      final result = await callable.call<Map<Object?, Object?>>({
        'confirmation': 'DELETE',
        'source': kIsWeb ? 'web' : 'app',
      });
      if (result.data['status'] != 'completed') {
        throw const AccountDeletionException('帳號刪除尚未完成，請稍後重試。');
      }
      await _authRepository.clearLocalSession();
    } on FirebaseFunctionsException catch (error) {
      throw AccountDeletionException(_functionsMessage(error));
    } on FirebaseAuthException catch (error) {
      throw AccountDeletionException(error.message ?? '重新驗證登入失敗，請稍後再試。');
    }
  }

  String _functionsMessage(FirebaseFunctionsException error) {
    return switch (error.code) {
      'already-exists' => '帳號刪除正在處理中，請稍後再試。',
      'failed-precondition' => '請重新驗證登入後再刪除帳號。',
      'permission-denied' => '安全驗證失敗，請重新開啟 App 後再試。',
      'unauthenticated' => '登入已失效，請重新登入後再試。',
      'unavailable' => '刪除服務暫時無法使用，請稍後再試。',
      _ => error.message ?? '帳號刪除未完成，請稍後重試。',
    };
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;
}
