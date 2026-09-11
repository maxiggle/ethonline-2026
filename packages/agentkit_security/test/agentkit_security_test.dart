import 'package:flutter_test/flutter_test.dart';
import 'package:agentkit_security/agentkit_security.dart';
import 'package:agentkit_security/agentkit_security_platform_interface.dart';
import 'package:agentkit_security/agentkit_security_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAgentkitSecurityPlatform
    with MockPlatformInterfaceMixin
    implements AgentkitSecurityPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AgentkitSecurityPlatform initialPlatform = AgentkitSecurityPlatform.instance;

  test('$MethodChannelAgentkitSecurity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAgentkitSecurity>());
  });

  test('getPlatformVersion', () async {
    AgentkitSecurity agentkitSecurityPlugin = AgentkitSecurity();
    MockAgentkitSecurityPlatform fakePlatform = MockAgentkitSecurityPlatform();
    AgentkitSecurityPlatform.instance = fakePlatform;

    expect(await agentkitSecurityPlugin.getPlatformVersion(), '42');
  });
}
