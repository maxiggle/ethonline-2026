import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentkit_security/agentkit_security_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAgentkitSecurity platform = MethodChannelAgentkitSecurity();
  const MethodChannel channel = MethodChannel('agentkit_security');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
