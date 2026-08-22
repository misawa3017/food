import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectLocation});

  final String? redirectLocation;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signIn(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
      if (mounted) {
        context.go(widget.redirectLocation ?? '/');
      }
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        _showError(_messageFor(error));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(_messageFor(error));
      }
    } catch (_) {
      if (mounted) {
        _showError('登入失敗，請稍後再試。');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'operation-not-allowed' => 'Firebase 尚未啟用這個登入方式。',
        'network-request-failed' => '網路連線失敗，請確認連線後重試。',
        'account-exists-with-different-credential' => '此信箱已使用其他登入方式，請先用原方式登入。',
        _ => error.message ?? '登入失敗，請稍後再試。',
      };
    }

    if (error is GoogleSignInException) {
      return switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'Google 登入設定尚未完成。',
        GoogleSignInExceptionCode.providerConfigurationError =>
          '裝置上的 Google 登入服務無法使用。',
        _ => error.description ?? 'Google 登入失敗，請稍後再試。',
      };
    }

    return '登入失敗，請稍後再試。';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final showAppleSignIn =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(title: const Text('登入')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.restaurant, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    '登入後繼續',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '登入後即可推薦餐廳、上傳照片、收藏與管理自己的投稿。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _signIn(
                            () => ref
                                .read(authRepositoryProvider)
                                .signInWithGoogle(),
                          ),
                    icon: const Icon(Icons.login),
                    label: const Text('使用 Google 登入'),
                  ),
                  if (showAppleSignIn) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _signIn(
                              () => ref
                                  .read(authRepositoryProvider)
                                  .signInWithApple(),
                            ),
                      icon: const Icon(Icons.apple),
                      label: const Text('使用 Apple 登入'),
                    ),
                  ],
                  if (_isLoading) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
