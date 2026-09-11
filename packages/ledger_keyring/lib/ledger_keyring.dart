
import 'ledger_keyring_platform_interface.dart';

class LedgerKeyring {
  Future<String?> getPlatformVersion() {
    return LedgerKeyringPlatform.instance.getPlatformVersion();
  }
}
