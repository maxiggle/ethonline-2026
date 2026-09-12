import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'agent_security_platform_interface.dart';

/// An implementation of [AgentSecurityPlatform] that uses method channels.
class MethodChannelAgentSecurity extends AgentSecurityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('agent_security');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
