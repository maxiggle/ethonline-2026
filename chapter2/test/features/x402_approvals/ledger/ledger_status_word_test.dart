import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/ledger/ledger_status_word.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LedgerStatusWords.requireSuccess', () {
    test('does not throw for 0x9000', () {
      expect(() => LedgerStatusWords.requireSuccess(0x9000), returnsNormally);
    });

    test('maps 0x6985 to a rejection message', () {
      expect(
        () => LedgerStatusWords.requireSuccess(0x6985),
        throwsA(
          isA<LedgerStatusWordException>().having((e) => e.message, 'message', 'Rejected on the Ledger'),
        ),
      );
    });

    for (final statusWord in [0x5515, 0x6982]) {
      test('maps 0x${statusWord.toRadixString(16)} to an unlock message', () {
        expect(
          () => LedgerStatusWords.requireSuccess(statusWord),
          throwsA(
            isA<LedgerStatusWordException>().having((e) => e.message, 'message', 'Unlock the Ledger'),
          ),
        );
      });
    }

    for (final statusWord in [0x6D00, 0x6E00, 0x6511]) {
      test('maps 0x${statusWord.toRadixString(16)} to an "open Ethereum app" message', () {
        expect(
          () => LedgerStatusWords.requireSuccess(statusWord),
          throwsA(
            isA<LedgerStatusWordException>().having((e) => e.message, 'message', 'Open the Ethereum app'),
          ),
        );
      });
    }

    test('maps 0x6A80 to a blind-signing message', () {
      expect(
        () => LedgerStatusWords.requireSuccess(0x6A80),
        throwsA(
          isA<LedgerStatusWordException>()
              .having((e) => e.message, 'message', 'Enable Blind signing in the Ethereum app settings'),
        ),
      );
    });

    test('maps anything else to a generic message that includes the hex status word', () {
      expect(
        () => LedgerStatusWords.requireSuccess(0x6F00),
        throwsA(
          isA<LedgerStatusWordException>().having((e) => e.message, 'message', contains('0x6F00')),
        ),
      );
    });
  });

  group('LedgerApduResponse.parse', () {
    test('splits payload from the trailing status word on success', () {
      final raw = Uint8List.fromList([0x01, 0x02, 0x03, 0x90, 0x00]);
      final response = LedgerApduResponse.parse(raw);
      expect(response.payload, [0x01, 0x02, 0x03]);
      expect(response.statusWord, 0x9000);
    });

    test('throws the mapped exception when the status word is not 0x9000', () {
      final raw = Uint8List.fromList([0x69, 0x85]);
      expect(() => LedgerApduResponse.parse(raw), throwsA(isA<LedgerStatusWordException>()));
    });
  });
}
