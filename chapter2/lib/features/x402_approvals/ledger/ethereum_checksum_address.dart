import 'dart:convert';
import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/utils/byte_utils.dart';
import 'package:pointycastle/digests/keccak.dart';

/// EIP-55 mixed-case checksum encoding, used to present the address the
/// Ledger returns (and to compare it against the backend's configured
/// approver address) the way every other Ethereum tool displays it.
class EthereumChecksumAddress {
  const EthereumChecksumAddress._();

  static String encode(String hexAddress) {
    final normalized = hexAddress.toLowerCase().replaceFirst('0x', '');
    if (normalized.length != 40) {
      throw ArgumentError('Expected a 40-hex-character address, got "$hexAddress"');
    }

    final hash = KeccakDigest(256).process(Uint8List.fromList(utf8.encode(normalized)));
    final hashHex = ByteUtils.bytesToHex(hash, include0x: false);

    final buffer = StringBuffer('0x');
    for (var i = 0; i < normalized.length; i++) {
      final character = normalized[i];
      final isHexDigit = RegExp(r'[0-9]').hasMatch(character);
      if (isHexDigit) {
        buffer.write(character);
        continue;
      }
      final hashNibble = int.parse(hashHex[i], radix: 16);
      buffer.write(hashNibble >= 8 ? character.toUpperCase() : character);
    }
    return buffer.toString();
  }
}
