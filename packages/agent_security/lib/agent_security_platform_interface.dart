import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'agent_security_method_channel.dart';

abstract class AgentSecurityPlatform extends PlatformInterface {
  /// Constructs a AgentSecurityPlatform.
  AgentSecurityPlatform() : super(token: _token);

  static final Object _token = Object();

  static AgentSecurityPlatform _instance = MethodChannelAgentSecurity();

  /// The default instance of [AgentSecurityPlatform] to use.
  ///
  /// Defaults to [MethodChannelAgentSecurity].
  static AgentSecurityPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AgentSecurityPlatform] when
  /// they register themselves.
  static set instance(AgentSecurityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
