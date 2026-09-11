import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'agentkit_security_platform_interface.dart';

/// An implementation of [AgentkitSecurityPlatform] that uses method channels.
class MethodChannelAgentkitSecurity extends AgentkitSecurityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('agentkit_security');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
