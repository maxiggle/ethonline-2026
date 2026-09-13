import 'dart:typed_data';

/// Shared byte / hex helpers for the Ledger APDU and EIP-712 hashing code.
///
/// Kept dependency-free (no keccak, no BigInt tricks beyond what Dart's
/// arbitrary-precision [BigInt] already provides) so it can be reused by both
/// `eip712/` and `ledger/` without pulling either into the other.
class ByteUtils {
  const ByteUtils._();

  static Uint8List hexToBytes(String hex) {
    var normalized = hex.startsWith('0x') || hex.startsWith('0X') ? hex.substring(2) : hex;
    if (normalized.length.isOdd) {
      normalized = '0$normalized';
    }
    final bytes = Uint8List(normalized.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      final byteHex = normalized.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(byteHex, radix: 16);
    }
    return bytes;
  }

  static String bytesToHex(List<int> bytes, {bool include0x = true}) {
    final buffer = StringBuffer(include0x ? '0x' : '');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static Uint8List leftPad(Uint8List bytes, int length) {
    if (bytes.length >= length) return bytes;
    final padded = Uint8List(length);
    padded.setRange(length - bytes.length, length, bytes);
    return padded;
  }

  static Uint8List rightPad(Uint8List bytes, int length) {
    if (bytes.length >= length) return bytes;
    final padded = Uint8List(length);
    padded.setRange(0, bytes.length, bytes);
    return padded;
  }

  static Uint8List bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List(0);
    if (value.isNegative) {
      throw ArgumentError('bigIntToBytes only supports unsigned values, got $value');
    }
    var hex = value.toRadixString(16);
    if (hex.length.isOdd) hex = '0$hex';
    return hexToBytes(hex);
  }

  static BigInt toBigInt(Object value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      if (value.startsWith('0x') || value.startsWith('0X')) {
        return BigInt.parse(value.substring(2), radix: 16);
      }
      return BigInt.parse(value);
    }
    throw ArgumentError('Cannot convert $value (${value.runtimeType}) to BigInt');
  }
}
