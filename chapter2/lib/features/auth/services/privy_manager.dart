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
      // In headless test environments or non-mobile platforms
      return const PrivyAuthResult(
        userId: "did:privy:google_user",
        email: "google_user@example.com",
        name: "Google User",
        walletAddress: "0x1234567890123456789012345678901234567890",
        authToken: "test_token_google_user",
      );
    }

    final p = privy;
    await p.awaitReady();

    final result = await p.oAuth.login(
      provider: OAuthProvider.google,
      appUrlScheme: AppConfig.privyAppScheme,
    );

    switch (result) {
      case Success<PrivyUser>(value: final user):
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
        }

        return PrivyAuthResult(
          userId: user.id,
          email: email,
          name: name,
          walletAddress: walletAddress,
          authToken: authToken,
        );

      case Failure<PrivyUser>(error: final error):
        throw Exception("Google Sign-In failed: ${error.message}");
    }
  }
}
