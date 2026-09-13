import 'package:chapter2/features/x402_approvals/ledger/ledger_derivation_path.dart';
import 'package:chapter2/features/x402_approvals/utils/byte_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes 44\'/60\'/0\'/0/0 as count byte + 5 big-endian uint32 components', () {
    final path = LedgerDerivationPath.ethereumDefault;
    expect(ByteUtils.bytesToHex(path), '0x058000002c8000003c800000000000000000000000');
    expect(path.length, 21);
  });
}
