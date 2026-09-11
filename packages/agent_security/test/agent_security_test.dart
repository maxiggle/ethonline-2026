import 'package:flutter_test/flutter_test.dart';
import 'package:agent_security/agent_security.dart';
import 'package:agent_security/agent_security_platform_interface.dart';
import 'package:agent_security/agent_security_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAgentSecurityPlatform
    with MockPlatformInterfaceMixin
    implements AgentSecurityPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AgentSecurityPlatform initialPlatform = AgentSecurityPlatform.instance;

  test('$MethodChannelAgentSecurity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAgentSecurity>());
  });

  test('getPlatformVersion', () async {
    AgentSecurity agentSecurityPlugin = AgentSecurity();
    MockAgentSecurityPlatform fakePlatform = MockAgentSecurityPlatform();
    AgentSecurityPlatform.instance = fakePlatform;

    expect(await agentSecurityPlugin.getPlatformVersion(), '42');
  });
}
