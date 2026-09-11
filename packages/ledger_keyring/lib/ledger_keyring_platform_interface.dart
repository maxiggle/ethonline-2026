import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ledger_keyring_method_channel.dart';

abstract class LedgerKeyringPlatform extends PlatformInterface {
  /// Constructs a LedgerKeyringPlatform.
  LedgerKeyringPlatform() : super(token: _token);

  static final Object _token = Object();

  static LedgerKeyringPlatform _instance = MethodChannelLedgerKeyring();

  /// The default instance of [LedgerKeyringPlatform] to use.
  ///
  /// Defaults to [MethodChannelLedgerKeyring].
  static LedgerKeyringPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LedgerKeyringPlatform] when
  /// they register themselves.
  static set instance(LedgerKeyringPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
