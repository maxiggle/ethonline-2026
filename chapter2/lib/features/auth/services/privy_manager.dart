import 'dart:developer';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:chapter2/core/config/app_config.dart';

class PrivyAuthResult {
  final String userId;
  final String? email;
  final String? name;
  final String? walletAddress;
  final String authToken;

  const PrivyAuthResult({
    required this.userId,
    this.email,
    this.name,
    this.walletAddress,
    required this.authToken,
  });
}

class PrivyManager {
  PrivyManager({Privy? privy}) : _privy = privy;

  Privy? _privy;

  Privy get privy {
    _privy ??= Privy.init(
      config: PrivyConfig(
        appId: AppConfig.privyAppId,
        appClientId: AppConfig.privyClientId,
        logLevel: PrivyLogLevel.verbose,
      ),
    );
    return _privy!;
  }

  bool get isNativeSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<PrivyAuthResult> loginWithGoogle() async {
    if (!isNativeSupported) {
      throw UnsupportedError(
        "Privy Google Authentication requires native iOS or Android. Please run on iOS Simulator or mobile device.",
      );
    }

    final p = privy;
    await p.getAuthState();

    final result = await p.oAuth.login(
      provider: OAuthProvider.google,
      appUrlScheme: AppConfig.privyAppScheme,
    );

    switch (result) {
      case Success<PrivyUser>(value: final user):
        return await _extractAuthResult(user);

      case Failure<PrivyUser>(error: final error):
        throw Exception("Google Sign-In failed: ${error.message}");
    }
  }

  /// Retrieves the active authenticated session if one exists in the native Privy SDK.
  Future<PrivyAuthResult?> getCurrentSession() async {
    if (!isNativeSupported) return null;
    try {
      final authState = await privy.getAuthState();
      if (authState is Authenticated) {
        return await _extractAuthResult(authState.user);
      }
      return null;
    } catch (e) {
      log('Error checking Privy auth state: $e');
      return null;
    }
  }

  /// Logs out of Privy SDK.
  Future<void> logout() async {
    if (!isNativeSupported) return;
    try {
      await privy.logout();
    } catch (e) {
      log('Error during Privy logout: $e');
    }
  }

  Future<PrivyAuthResult> _extractAuthResult(PrivyUser user) async {
    final tokenResult = await user.getAccessToken();
    String authToken = "";
    switch (tokenResult) {
      case Success<String>(value: final token):
        authToken = token;
      case Failure<String>(error: final error):
        throw Exception("Failed to obtain Privy token: ${error.message}");
    }

    String? email;
    String? name;
    for (final account in user.linkedAccounts) {
      if (account is GoogleOAuthAccount) {
        email = account.email;
        name = account.name;
        break;
      } else if (account is EmailAccount) {
        email = account.emailAddress;
      }
    }

    String? walletAddress;
    if (user.embeddedEthereumWallets.isNotEmpty) {
      walletAddress = user.embeddedEthereumWallets.first.address;
    } else {
      for (final account in user.linkedAccounts) {
        if (account is EmbeddedEthereumWalletAccount) {
          walletAddress = account.address;
          break;
        } else if (account is ExternalWalletAccount) {
          walletAddress = account.address;
          break;
        }
      }
    }

    log(
      'Extracted Privy User: ${user.id}, email: $email, wallet: $walletAddress',
    );
    return PrivyAuthResult(
      userId: user.id,
      email: email,
      name: name,
      walletAddress: walletAddress,
      authToken: authToken,
    );
  }
}
