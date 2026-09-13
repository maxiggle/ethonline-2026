import 'dart:typed_data';

import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_state.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/remote/models/x402_approval_config.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/features/x402_approvals/eip712/eip712_typed_data.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_signer.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_signature.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_status_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

const _approverAddress = '0xAbc1230000000000000000000000000000000000';
const _otherLedgerAddress = '0x0000000000000000000000000000000000baDbad';

class _FakeX402ApprovalsApiService extends X402ApprovalsApiService {
  _FakeX402ApprovalsApiService() : super(apiClient: null);

  X402ApprovalConfig config = const X402ApprovalConfig(
    approverAddress: _approverAddress,
    network: 'eip155:84532',
    usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
  );
  List<PendingX402Approval> pending = [];

  String? lastApprovalActionId;
  String? lastApprovalSignature;
  String? lastRejectionActionId;
  String? lastRejectionSignature;

  @override
  Future<X402ApprovalConfig> fetchApprovalConfig() async => config;

  @override
  Future<List<PendingX402Approval>> fetchPendingApprovals() async => pending;

  @override
  Future<void> submitApprovalSignature({required String actionId, required String signature}) async {
    lastApprovalActionId = actionId;
    lastApprovalSignature = signature;
  }

  @override
  Future<void> submitRejectionSignature({required String actionId, required String signature}) async {
    lastRejectionActionId = actionId;
    lastRejectionSignature = signature;
  }
}

class _FakeLedgerEthereumSigner implements LedgerEthereumSigner {
  _FakeLedgerEthereumSigner({required this.address});

  final String address;
  LedgerSignature? eip712Signature;
  LedgerSignature? personalMessageSignature;
  Object? signingError;

  Uint8List? lastDomainSeparator;
  Uint8List? lastMessageHash;
  Uint8List? lastPersonalMessage;

  @override
  Future<String> getAddress() async => address;

  @override
  Future<LedgerSignature> signEip712Hashed({
    required Uint8List domainSeparator,
    required Uint8List messageHash,
  }) async {
    lastDomainSeparator = domainSeparator;
    lastMessageHash = messageHash;
    final error = signingError;
    if (error != null) throw error;
    return eip712Signature!;
  }

  @override
  Future<LedgerSignature> signPersonalMessage(Uint8List message) async {
    lastPersonalMessage = message;
    final error = signingError;
    if (error != null) throw error;
    return personalMessageSignature!;
  }
}

class _FakeLedgerBleClient implements LedgerBleClient {
  _FakeLedgerBleClient(this.signer);

  final LedgerEthereumSigner signer;
  bool disconnected = false;

  @override
  Stream<LedgerDevice> scan() => const Stream.empty();

  @override
  Future<void> stopScanning() async {}

  @override
  Future<LedgerEthereumSigner> connectSigner(LedgerDevice device) async => signer;

  @override
  Future<void> disconnect() async => disconnected = true;
}

PendingX402Approval _buildPendingApproval({String actionId = 'action-1'}) {
  final validBefore = (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000).toString();
  return PendingX402Approval(
    actionId: actionId,
    resourceUrl: 'https://example.com/resource',
    amountAtomicUnits: '2000000',
    payTo: '0x1111111111111111111111111111111111111111',
    agentAddress: '0x2222222222222222222222222222222222222222',
    justification: 'x402: https://example.com/resource | test',
    riskScore: 62,
    reasons: const ['Exceeds autonomous limit'],
    typedData: Eip712TypedData(
      domain: const {
        'name': 'USDC',
        'version': '2',
        'chainId': 84532,
        'verifyingContract': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      },
      types: const {
        'TransferWithAuthorization': [
          Eip712FieldType(name: 'from', type: 'address'),
          Eip712FieldType(name: 'to', type: 'address'),
          Eip712FieldType(name: 'value', type: 'uint256'),
          Eip712FieldType(name: 'validAfter', type: 'uint256'),
          Eip712FieldType(name: 'validBefore', type: 'uint256'),
          Eip712FieldType(name: 'nonce', type: 'bytes32'),
        ],
      },
      primaryType: 'TransferWithAuthorization',
      message: {
        'from': _approverAddress,
        'to': '0x1111111111111111111111111111111111111111',
        'value': '2000000',
        'validAfter': '0',
        'validBefore': validBefore,
        'nonce': '0x2f4f8f0e4b1d3a1c6e5f7a8b9c0d1e2f3a4b5c6d7e8f90112233445566778899',
      },
    ),
    createdAt: DateTime.now(),
  );
}

const _testDevice = LedgerDevice(
  id: 'test-device',
  name: 'Nano X',
  connectionType: ConnectionType.ble,
  deviceInfo: LedgerDeviceType.nanoX,
);

void main() {
  group('X402ApprovalsCubit', () {
    test('connecting a Ledger whose address does not match the approver blocks approval', () async {
      final api = _FakeX402ApprovalsApiService();
      final signer = _FakeLedgerEthereumSigner(address: _otherLedgerAddress);
      final cubit = X402ApprovalsCubit(apiService: api, ledgerBleClient: _FakeLedgerBleClient(signer));

      await cubit.loadConfig();
      await cubit.connectLedger(_testDevice);

      expect(cubit.state.status, X402ApprovalsStatus.connected);
      expect(cubit.state.matchesApprover, isFalse);
      expect(cubit.state.isLedgerReady, isFalse);
      expect(cubit.state.errorMessage, contains('is not the configured approver'));

      api.pending = [_buildPendingApproval()];
      await cubit.refreshPendingApprovals();
      await cubit.approve('action-1');

      expect(cubit.state.status, X402ApprovalsStatus.failure);
      expect(cubit.state.errorMessage, contains('Connect a matching Ledger'));
      expect(api.lastApprovalActionId, isNull);

      await cubit.close();
    });

    test('approve() signs the EIP-712 hashes on the device and posts the assembled signature', () async {
      final api = _FakeX402ApprovalsApiService()..pending = [_buildPendingApproval()];
      final signer = _FakeLedgerEthereumSigner(address: _approverAddress)
        ..eip712Signature = LedgerSignature(
          v: 27,
          r: Uint8List.fromList(List.filled(32, 0xAA)),
          s: Uint8List.fromList(List.filled(32, 0xBB)),
        );
      final cubit = X402ApprovalsCubit(apiService: api, ledgerBleClient: _FakeLedgerBleClient(signer));

      await cubit.loadConfig();
      await cubit.connectLedger(_testDevice);
      expect(cubit.state.matchesApprover, isTrue);
      await cubit.refreshPendingApprovals();

      await cubit.approve('action-1');

      expect(cubit.state.status, X402ApprovalsStatus.success);
      expect(cubit.state.lastCompletedActionId, 'action-1');
      expect(signer.lastDomainSeparator, isNotNull);
      expect(signer.lastMessageHash, isNotNull);
      expect(api.lastApprovalActionId, 'action-1');
      expect(
        api.lastApprovalSignature,
        '0x'
        '${'aa' * 32}'
        '${'bb' * 32}'
        '1b',
      );

      await cubit.close();
    });

    test('reject() personal-signs chapter2-reject:<actionId> and posts that signature', () async {
      final api = _FakeX402ApprovalsApiService()..pending = [_buildPendingApproval()];
      final signer = _FakeLedgerEthereumSigner(address: _approverAddress)
        ..personalMessageSignature = LedgerSignature(
          v: 28,
          r: Uint8List.fromList(List.filled(32, 0x01)),
          s: Uint8List.fromList(List.filled(32, 0x02)),
        );
      final cubit = X402ApprovalsCubit(apiService: api, ledgerBleClient: _FakeLedgerBleClient(signer));

      await cubit.loadConfig();
      await cubit.connectLedger(_testDevice);
      await cubit.refreshPendingApprovals();

      await cubit.reject('action-1');

      expect(cubit.state.status, X402ApprovalsStatus.success);
      expect(signer.lastPersonalMessage, isNotNull);
      expect(String.fromCharCodes(signer.lastPersonalMessage!), 'chapter2-reject:action-1');
      expect(api.lastRejectionActionId, 'action-1');
      expect(
        api.lastRejectionSignature,
        '0x'
        '${'01' * 32}'
        '${'02' * 32}'
        '1c',
      );

      await cubit.close();
    });

    test('a device rejection (0x6985) surfaces the mapped "Rejected on the Ledger" error', () async {
      final api = _FakeX402ApprovalsApiService()..pending = [_buildPendingApproval()];
      final signer = _FakeLedgerEthereumSigner(address: _approverAddress)
        ..signingError = const LedgerStatusWordException(statusWord: 0x6985, message: 'Rejected on the Ledger');
      final cubit = X402ApprovalsCubit(apiService: api, ledgerBleClient: _FakeLedgerBleClient(signer));

      await cubit.loadConfig();
      await cubit.connectLedger(_testDevice);
      await cubit.refreshPendingApprovals();

      await cubit.approve('action-1');

      expect(cubit.state.status, X402ApprovalsStatus.failure);
      expect(cubit.state.errorMessage, 'Rejected on the Ledger');
      expect(api.lastApprovalActionId, isNull);

      await cubit.close();
    });
  });
}
