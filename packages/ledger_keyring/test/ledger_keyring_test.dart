import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_keyring/ledger_keyring.dart';
import 'package:ledger_keyring/ledger_keyring_platform_interface.dart';
import 'package:ledger_keyring/ledger_keyring_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLedgerKeyringPlatform
    with MockPlatformInterfaceMixin
    implements LedgerKeyringPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LedgerKeyringPlatform initialPlatform = LedgerKeyringPlatform.instance;

  test('$MethodChannelLedgerKeyring is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLedgerKeyring>());
  });

  test('getPlatformVersion', () async {
    LedgerKeyring ledgerKeyringPlugin = LedgerKeyring();
    MockLedgerKeyringPlatform fakePlatform = MockLedgerKeyringPlatform();
    LedgerKeyringPlatform.instance = fakePlatform;

    expect(await ledgerKeyringPlugin.getPlatformVersion(), '42');
  });
}
