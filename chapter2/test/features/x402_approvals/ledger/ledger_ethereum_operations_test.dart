import 'dart:convert';
import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/ledger/ledger_derivation_path.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_operations.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_status_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus_dart.dart';

void main() {
  group('LedgerGetAddressOperation', () {
    test('write() sends CLA E0 INS 02 P1 00 P2 00 with the derivation path as data', () async {
      final op = LedgerGetAddressOperation();
      final packets = await op.write(ByteDataWriter());
      expect(packets, hasLength(1));

      final reader = ByteDataReader()..add(packets.single);
      expect(reader.readUint8(), 0xE0);
      expect(reader.readUint8(), 0x02);
      expect(reader.readUint8(), 0x00);
      expect(reader.readUint8(), 0x00);
      expect(reader.readUint8(), LedgerDerivationPath.ethereumDefault.length);
      expect(reader.read(reader.remainingLength), LedgerDerivationPath.ethereumDefault);
    });

    test('read() parses pubkey/address fields and checksums the address, well-known EIP-55 vector', () async {
      // https://eips.ethereum.org/EIPS/eip-55 test vector.
      const addressAsciiHex = '5aaeb6053f3e94c9b9a09f33669435e7ef1beaed';
      const expectedChecksummed = '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed';

      final publicKey = Uint8List.fromList(List.generate(65, (i) => i));
      final addressAscii = ascii.encode(addressAsciiHex);

      final response = BytesBuilder()
        ..addByte(publicKey.length)
        ..add(publicKey)
        ..addByte(addressAscii.length)
        ..add(addressAscii)
        ..add([0x90, 0x00]);

      final reader = ByteDataReader()..add(response.toBytes());
      final address = await LedgerGetAddressOperation().read(reader);
      expect(address, expectedChecksummed);
    });

    test('read() surfaces the mapped status-word error when the device rejects the request', () async {
      final reader = ByteDataReader()..add([0x69, 0x85]);
      expect(
        () => LedgerGetAddressOperation().read(reader),
        throwsA(isA<LedgerStatusWordException>().having((e) => e.message, 'message', 'Rejected on the Ledger')),
      );
    });
  });

  group('LedgerSignEip712HashedOperation', () {
    final domainSeparator = Uint8List.fromList(List.filled(32, 0x11));
    final messageHash = Uint8List.fromList(List.filled(32, 0x22));

    test('write() sends CLA E0 INS 0C with path ‖ domainSeparator(32) ‖ hashStruct(32)', () async {
      final op = LedgerSignEip712HashedOperation(domainSeparator: domainSeparator, messageHash: messageHash);
      final packets = await op.write(ByteDataWriter());
      expect(packets, hasLength(1));

      final reader = ByteDataReader()..add(packets.single);
      expect(reader.readUint8(), 0xE0);
      expect(reader.readUint8(), 0x0C);
      expect(reader.readUint8(), 0x00);
      expect(reader.readUint8(), 0x00);

      final path = LedgerDerivationPath.ethereumDefault;
      expect(reader.readUint8(), path.length + 32 + 32);
      expect(reader.read(path.length), path);
      expect(reader.read(32), domainSeparator);
      expect(reader.read(32), messageHash);
    });

    test('requires 32-byte domainSeparator and messageHash', () {
      expect(
        () => LedgerSignEip712HashedOperation(domainSeparator: Uint8List(31), messageHash: messageHash),
        throwsArgumentError,
      );
      expect(
        () => LedgerSignEip712HashedOperation(domainSeparator: domainSeparator, messageHash: Uint8List(31)),
        throwsArgumentError,
      );
    });

    test('read() parses v‖r‖s and normalizes v=0/1 to 27/28', () async {
      final r = Uint8List.fromList(List.filled(32, 0xAA));
      final s = Uint8List.fromList(List.filled(32, 0xBB));

      for (final entry in {0: 27, 1: 28, 27: 27, 28: 28}.entries) {
        final response = BytesBuilder()
          ..addByte(entry.key)
          ..add(r)
          ..add(s)
          ..add([0x90, 0x00]);
        final reader = ByteDataReader()..add(response.toBytes());

        final op = LedgerSignEip712HashedOperation(domainSeparator: domainSeparator, messageHash: messageHash);
        final signature = await op.read(reader);

        expect(signature.v, entry.value, reason: 'raw v=${entry.key} should normalize to ${entry.value}');
        expect(signature.r, r);
        expect(signature.s, s);
      }
    });
  });

  group('LedgerSignPersonalMessageOperation', () {
    test('chunks a message longer than 255 bytes across a first (P1=00) and continuation (P1=80) APDU', () async {
      final message = Uint8List.fromList(List.filled(300, 0xAB));
      final op = LedgerSignPersonalMessageOperation(message: message);

      final r = Uint8List.fromList(List.filled(32, 0xCC));
      final s = Uint8List.fromList(List.filled(32, 0xDD));
      final finalResponse = BytesBuilder()
        ..addByte(27)
        ..add(r)
        ..add(s)
        ..add([0x90, 0x00]);

      final capturedApdus = <Uint8List>[];
      Future<Y> fakeSend<Y>(LedgerRawOperation<Y> chunkOperation) async {
        final packets = await chunkOperation.write(ByteDataWriter());
        capturedApdus.add(packets.single);

        final reader = ByteDataReader()..add(finalResponse.toBytes());
        return chunkOperation.read(reader);
      }

      final signature = await op.invoke(fakeSend);

      expect(capturedApdus, hasLength(2), reason: '300 bytes needs a first + one continuation chunk');

      final path = LedgerDerivationPath.ethereumDefault;
      final maxFirstChunkPayload = 255 - path.length - 4;

      final firstReader = ByteDataReader()..add(capturedApdus[0]);
      expect(firstReader.readUint8(), 0xE0);
      expect(firstReader.readUint8(), 0x08);
      expect(firstReader.readUint8(), 0x00, reason: 'first chunk uses P1 00');
      expect(firstReader.readUint8(), 0x00);
      final firstLc = firstReader.readUint8();
      expect(firstLc, path.length + 4 + maxFirstChunkPayload);
      expect(firstReader.read(path.length), path);
      expect(firstReader.readUint32(), message.length);
      expect(firstReader.read(maxFirstChunkPayload), message.sublist(0, maxFirstChunkPayload));

      final secondReader = ByteDataReader()..add(capturedApdus[1]);
      expect(secondReader.readUint8(), 0xE0);
      expect(secondReader.readUint8(), 0x08);
      expect(secondReader.readUint8(), 0x80, reason: 'continuation chunk uses P1 80');
      expect(secondReader.readUint8(), 0x00);
      final remaining = message.length - maxFirstChunkPayload;
      expect(secondReader.readUint8(), remaining);
      expect(secondReader.read(remaining), message.sublist(maxFirstChunkPayload));

      expect(signature.v, 27);
      expect(signature.r, r);
      expect(signature.s, s);
    });

    test('sends a single chunk for a short message', () async {
      final message = Uint8List.fromList(utf8.encode('chapter2-reject:action-123'));
      final op = LedgerSignPersonalMessageOperation(message: message);

      final r = Uint8List.fromList(List.filled(32, 0x01));
      final s = Uint8List.fromList(List.filled(32, 0x02));
      final response = BytesBuilder()
        ..addByte(28)
        ..add(r)
        ..add(s)
        ..add([0x90, 0x00]);

      var callCount = 0;
      Future<Y> fakeSend<Y>(LedgerRawOperation<Y> chunkOperation) async {
        callCount++;
        final reader = ByteDataReader()..add(response.toBytes());
        return chunkOperation.read(reader);
      }

      final signature = await op.invoke(fakeSend);
      expect(callCount, 1);
      expect(signature.v, 28);
    });

    test('surfaces the mapped status-word error when the device rejects a chunk', () async {
      final op = LedgerSignPersonalMessageOperation(message: Uint8List.fromList(utf8.encode('reject-me')));

      Future<Y> fakeSend<Y>(LedgerRawOperation<Y> chunkOperation) async {
        final reader = ByteDataReader()..add([0x69, 0x85]);
        return chunkOperation.read(reader);
      }

      expect(
        () => op.invoke(fakeSend),
        throwsA(isA<LedgerStatusWordException>().having((e) => e.message, 'message', 'Rejected on the Ledger')),
      );
    });
  });
}
