import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_signer.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

/// The subset of `ledger_flutter_plus`'s BLE surface the cubit needs, behind
/// an interface this app owns.
///
/// `LedgerInterface` itself is `sealed`, so it cannot be faked from outside
/// the package — this seam is what lets [X402ApprovalsCubit] be unit-tested
/// with a fake signer instead of a real BLE connection.
abstract class LedgerBleClient {
  Stream<LedgerDevice> scan();

  Future<void> stopScanning();

  /// Connects to [device] and returns a signer bound to that connection.
  Future<LedgerEthereumSigner> connectSigner(LedgerDevice device);

  /// Disconnects the current connection, if any.
  Future<void> disconnect();
}

class LedgerInterfaceBleClient implements LedgerBleClient {
  LedgerInterfaceBleClient(this._ledgerInterface);

  final LedgerInterface _ledgerInterface;
  LedgerConnection? _connection;

  @override
  Stream<LedgerDevice> scan() => _ledgerInterface.scan();

  @override
  Future<void> stopScanning() => _ledgerInterface.stopScanning();

  @override
  Future<LedgerEthereumSigner> connectSigner(LedgerDevice device) async {
    final connection = await _ledgerInterface.connect(device);
    _connection = connection;
    return LedgerConnectionEthereumSigner(connection);
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      await connection.disconnect();
    }
  }
}
