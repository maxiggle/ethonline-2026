import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ledger_keyring_platform_interface.dart';

/// An implementation of [LedgerKeyringPlatform] that uses method channels.
class MethodChannelLedgerKeyring extends LedgerKeyringPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ledger_keyring');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
