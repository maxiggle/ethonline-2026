import 'dart:convert';
import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/ledger/ethereum_checksum_address.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_derivation_path.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_signature.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_status_word.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus_dart.dart';

/// `GET ADDRESS`: CLA `E0`, INS `02`, P1 `00`, P2 `00`, data = the fixed
/// `44'/60'/0'/0/0` path. The response is `pubkeyLen ‖ pubkey ‖ addressLen ‖
/// asciiHexAddress` ‖ SW1SW2; only the checksummed address is surfaced.
class LedgerGetAddressOperation extends LedgerRawOperation<String> {
  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async {
    final path = LedgerDerivationPath.ethereumDefault;
    writer.writeUint8(0xE0);
    writer.writeUint8(0x02);
    writer.writeUint8(0x00);
    writer.writeUint8(0x00);
    writer.writeUint8(path.length);
    writer.write(path);
    return [writer.toBytes()];
  }

  @override
  Future<String> read(ByteDataReader reader) async {
    final response = LedgerApduResponse.parse(reader.read(reader.remainingLength));
    final payload = response.payload;
    if (payload.isEmpty) {
      throw StateError('Ledger get-address response was empty');
    }

    var offset = 0;
    final publicKeyLength = payload[offset];
    offset += 1 + publicKeyLength;
    if (offset >= payload.length) {
      throw StateError('Ledger get-address response is missing the address field');
    }

    final addressLength = payload[offset];
    offset += 1;
    if (offset + addressLength > payload.length) {
      throw StateError('Ledger get-address response is truncated');
    }

    final addressAsciiHex = ascii.decode(payload.sublist(offset, offset + addressLength));
    return EthereumChecksumAddress.encode(addressAsciiHex);
  }
}

/// `SIGN EIP-712, v0 (HASHED)`: CLA `E0`, INS `0C`, P1 `00`, P2 `00`, data =
/// path ‖ domainSeparator (32 bytes) ‖ hashStruct(message) (32 bytes). The
/// response is `v ‖ r ‖ s` ‖ SW1SW2.
class LedgerSignEip712HashedOperation extends LedgerRawOperation<LedgerSignature> {
  LedgerSignEip712HashedOperation({required this.domainSeparator, required this.messageHash}) {
    if (domainSeparator.length != 32) {
      throw ArgumentError('domainSeparator must be 32 bytes, got ${domainSeparator.length}');
    }
    if (messageHash.length != 32) {
      throw ArgumentError('messageHash must be 32 bytes, got ${messageHash.length}');
    }
  }

  final Uint8List domainSeparator;
  final Uint8List messageHash;

  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async {
    final path = LedgerDerivationPath.ethereumDefault;
    final data = BytesBuilder()
      ..add(path)
      ..add(domainSeparator)
      ..add(messageHash);
    final dataBytes = data.toBytes();

    writer.writeUint8(0xE0);
    writer.writeUint8(0x0C);
    writer.writeUint8(0x00);
    writer.writeUint8(0x00);
    writer.writeUint8(dataBytes.length);
    writer.write(dataBytes);
    return [writer.toBytes()];
  }

  @override
  Future<LedgerSignature> read(ByteDataReader reader) async {
    final response = LedgerApduResponse.parse(reader.read(reader.remainingLength));
    final payload = response.payload;
    if (payload.length != 65) {
      throw StateError('Expected a 65-byte v‖r‖s response, got ${payload.length} bytes');
    }
    return LedgerSignature.fromVrs(
      v: payload[0],
      r: payload.sublist(1, 33),
      s: payload.sublist(33, 65),
    );
  }
}

/// `SIGN PERSONAL MESSAGE`: CLA `E0`, INS `08`, P2 `00`, chunked across
/// multiple APDUs of at most 255 bytes of data each. The first chunk carries
/// P1 `00` and `path ‖ messageLength(4, BE) ‖ firstChunk`; subsequent chunks
/// carry P1 `80` and just their bytes. Only the final chunk's response holds
/// `v ‖ r ‖ s`.
///
/// Implemented as a [LedgerComplexOperation] so each chunk is written and its
/// response read in turn, rather than firing every chunk before any reply —
/// `ledger_flutter_plus`'s [LedgerRawOperation.write] can return multiple raw
/// APDUs, but they'd all be sent back-to-back with only one final `read()`,
/// which does not match how the Ethereum app's multi-APDU exchange for
/// `SIGN PERSONAL MESSAGE` behaves.
class LedgerSignPersonalMessageOperation extends LedgerComplexOperation<LedgerSignature> {
  LedgerSignPersonalMessageOperation({required this.message});

  final Uint8List message;

  static const int _maxApduDataLength = 255;

  @override
  Future<LedgerSignature> invoke(LedgerSendFct send) async {
    Uint8List? lastPayload;
    for (final chunk in _buildChunks()) {
      lastPayload = await send(_PersonalMessageChunkOperation(p1: chunk.p1, data: chunk.data));
    }
    if (lastPayload == null || lastPayload.length != 65) {
      throw StateError(
        'Expected a 65-byte v‖r‖s response from the final personal_sign chunk, '
        'got ${lastPayload?.length ?? 0} bytes',
      );
    }
    return LedgerSignature.fromVrs(
      v: lastPayload[0],
      r: lastPayload.sublist(1, 33),
      s: lastPayload.sublist(33, 65),
    );
  }

  List<_PersonalMessageChunk> _buildChunks() {
    final path = LedgerDerivationPath.ethereumDefault;
    final chunks = <_PersonalMessageChunk>[];
    var offset = 0;
    var isFirst = true;

    do {
      final builder = BytesBuilder();
      final int maxChunkPayloadLength;
      if (isFirst) {
        builder.add(path);
        final lengthPrefix = ByteData(4)..setUint32(0, message.length, Endian.big);
        builder.add(lengthPrefix.buffer.asUint8List());
        maxChunkPayloadLength = _maxApduDataLength - path.length - 4;
      } else {
        maxChunkPayloadLength = _maxApduDataLength;
      }

      final remaining = message.length - offset;
      final take = remaining < maxChunkPayloadLength ? remaining : maxChunkPayloadLength;
      if (take > 0) {
        builder.add(message.sublist(offset, offset + take));
      }

      chunks.add(_PersonalMessageChunk(p1: isFirst ? 0x00 : 0x80, data: builder.toBytes()));
      offset += take;
      isFirst = false;
    } while (offset < message.length);

    return chunks;
  }
}

class _PersonalMessageChunk {
  const _PersonalMessageChunk({required this.p1, required this.data});

  final int p1;
  final Uint8List data;
}

class _PersonalMessageChunkOperation extends LedgerRawOperation<Uint8List> {
  _PersonalMessageChunkOperation({required this.p1, required this.data});

  final int p1;
  final Uint8List data;

  @override
  Future<List<Uint8List>> write(ByteDataWriter writer) async {
    writer.writeUint8(0xE0);
    writer.writeUint8(0x08);
    writer.writeUint8(p1);
    writer.writeUint8(0x00);
    writer.writeUint8(data.length);
    writer.write(data);
    return [writer.toBytes()];
  }

  @override
  Future<Uint8List> read(ByteDataReader reader) async {
    final response = LedgerApduResponse.parse(reader.read(reader.remainingLength));
    return response.payload;
  }
}
