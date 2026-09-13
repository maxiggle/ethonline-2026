import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/utils/byte_utils.dart';
import 'package:equatable/equatable.dart';

/// An assembled `r ‖ s ‖ v` signature ready to send to the backend, exactly
/// as `POST /x402/approvals/:actionId/signature` and `/reject` expect it:
/// `0x` ‖ r (32 bytes) ‖ s (32 bytes) ‖ v, with v normalized to 27 or 28.
class LedgerSignature extends Equatable {
  const LedgerSignature({required this.v, required this.r, required this.s});

  final int v;
  final Uint8List r;
  final Uint8List s;

  /// Builds a [LedgerSignature] from the raw `v, r, s` the Ledger returned,
  /// normalizing a `0`/`1` recovery id to `27`/`28`.
  factory LedgerSignature.fromVrs({required int v, required Uint8List r, required Uint8List s}) {
    final normalizedV = v < 27 ? v + 27 : v;
    if (normalizedV != 27 && normalizedV != 28) {
      throw ArgumentError('Ledger returned an unexpected recovery id: $v');
    }
    return LedgerSignature(v: normalizedV, r: r, s: s);
  }

  String toHex() {
    final buffer = BytesBuilder();
    buffer.add(ByteUtils.leftPad(r, 32));
    buffer.add(ByteUtils.leftPad(s, 32));
    buffer.add([v]);
    return ByteUtils.bytesToHex(buffer.toBytes());
  }

  @override
  List<Object?> get props => [v, r, s];
}
