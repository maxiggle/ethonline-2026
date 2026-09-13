import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_operations.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_signature.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

/// The Ledger Ethereum operations the cubit needs, abstracted so tests can
/// substitute a fake signer instead of driving a real BLE connection.
abstract class LedgerEthereumSigner {
  Future<String> getAddress();

  Future<LedgerSignature> signEip712Hashed({
    required Uint8List domainSeparator,
    required Uint8List messageHash,
  });

  Future<LedgerSignature> signPersonalMessage(Uint8List message);
}

/// Drives the three Ethereum-app operations over a live [LedgerConnection].
class LedgerConnectionEthereumSigner implements LedgerEthereumSigner {
  LedgerConnectionEthereumSigner(this._connection);

  final LedgerConnection _connection;

  @override
  Future<String> getAddress() {
    return _connection.sendOperation<String>(LedgerGetAddressOperation());
  }

  @override
  Future<LedgerSignature> signEip712Hashed({
    required Uint8List domainSeparator,
    required Uint8List messageHash,
  }) {
    return _connection.sendOperation<LedgerSignature>(
      LedgerSignEip712HashedOperation(domainSeparator: domainSeparator, messageHash: messageHash),
    );
  }

  @override
  Future<LedgerSignature> signPersonalMessage(Uint8List message) {
    return _connection.sendOperation<LedgerSignature>(
      LedgerSignPersonalMessageOperation(message: message),
    );
  }
}
