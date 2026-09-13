import 'dart:typed_data';

/// A Ledger APDU response carried a status word other than `0x9000`.
///
/// Carries a user-facing [message] mapped from the status word per the
/// ticket's table, falling back to a generic message that still names the
/// raw status word for anything unmapped.
class LedgerStatusWordException implements Exception {
  const LedgerStatusWordException({required this.statusWord, required this.message});

  final int statusWord;
  final String message;

  String get statusWordHex => '0x${statusWord.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  @override
  String toString() => message;
}

class LedgerStatusWords {
  const LedgerStatusWords._();

  static const int success = 0x9000;

  /// Throws a [LedgerStatusWordException] with a mapped message unless
  /// [statusWord] is `0x9000`.
  static void requireSuccess(int statusWord) {
    if (statusWord == success) return;
    throw LedgerStatusWordException(statusWord: statusWord, message: _messageFor(statusWord));
  }

  static String _messageFor(int statusWord) {
    switch (statusWord) {
      case 0x6985:
        return 'Rejected on the Ledger';
      case 0x5515:
      case 0x6982:
        return 'Unlock the Ledger';
      case 0x6D00:
      case 0x6E00:
      case 0x6511:
        return 'Open the Ethereum app';
      case 0x6A80:
        return 'Enable Blind signing in the Ethereum app settings';
      default:
        final hex = '0x${statusWord.toRadixString(16).padLeft(4, '0').toUpperCase()}';
        return 'The Ledger returned an unexpected status word ($hex)';
    }
  }
}

/// The parsed form of a raw Ledger BLE response: application payload plus the
/// trailing 2-byte status word every APDU response ends with.
class LedgerApduResponse {
  const LedgerApduResponse({required this.payload, required this.statusWord});

  final Uint8List payload;
  final int statusWord;

  /// Splits [raw] into `payload ‖ SW1 ‖ SW2` and throws
  /// [LedgerStatusWordException] if the status word is not `0x9000`.
  factory LedgerApduResponse.parse(Uint8List raw) {
    if (raw.length < 2) {
      throw ArgumentError('Ledger APDU response is too short to contain a status word: ${raw.length} bytes');
    }
    final statusWord = (raw[raw.length - 2] << 8) | raw[raw.length - 1];
    final payload = raw.sublist(0, raw.length - 2);
    LedgerStatusWords.requireSuccess(statusWord);
    return LedgerApduResponse(payload: payload, statusWord: statusWord);
  }
}
