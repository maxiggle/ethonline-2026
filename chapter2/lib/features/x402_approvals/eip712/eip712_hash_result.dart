import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/utils/byte_utils.dart';
import 'package:equatable/equatable.dart';

/// The three hashes the Ledger's "sign EIP-712, v0 hashed" instruction needs,
/// plus the final digest the human ends up approving.
class Eip712HashResult extends Equatable {
  const Eip712HashResult({
    required this.domainSeparator,
    required this.messageHash,
    required this.digest,
  });

  final Uint8List domainSeparator;
  final Uint8List messageHash;
  final Uint8List digest;

  String get domainSeparatorHex => ByteUtils.bytesToHex(domainSeparator);
  String get messageHashHex => ByteUtils.bytesToHex(messageHash);
  String get digestHex => ByteUtils.bytesToHex(digest);

  @override
  List<Object?> get props => [domainSeparatorHex, messageHashHex, digestHex];
}
