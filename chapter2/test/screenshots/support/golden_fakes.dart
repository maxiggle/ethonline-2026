import 'dart:typed_data';

import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_approver_status.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
import 'package:chapter2/features/x402_approvals/eip712/eip712_typed_data.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ethereum_signer.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_signature.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/remote/models/x402_approval_config.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/world_id_status.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';

/// Fixture data and fakes for screenshot goldens. Fake data here is fine —
/// it never ships in `lib/`, only in this test fixture.
const kFixtureApproverAddress = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';
const kFixtureAgentAddress = '0x1111111111111111111111111111111111111111';
const kFixtureSafeAddress = '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6';
const kFixtureGuardAddress = '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3';

final kFixtureAgent = AgentModel(
  id: 'agent_1',
  userId: 'user_1',
  agentAddress: kFixtureAgentAddress,
  name: 'Treasury Worker #1',
  safeAddress: kFixtureSafeAddress,
  guardAddress: kFixtureGuardAddress,
  status: 'ACTIVE',
);

List<TreasuryAction> buildFixtureActions() {
  final now = DateTime.now();
  return [
    TreasuryAction(
      actionId: 'act_1',
      agentAddress: kFixtureAgentAddress,
      recipientAddress: '0x82f6c1a1b8e2f3a4b5c6d7e8f9012345671f90aa',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(25000000),
      amountDisplayUsdc: 25.0,
      status: TreasuryActionStatus.executed,
      riskScore: 8,
      purpose: 'Alchemy RPC node infrastructure',
      timestamp: now.subtract(const Duration(minutes: 5)),
      txHash: '0xabc123',
    ),
    TreasuryAction(
      actionId: 'act_2',
      agentAddress: kFixtureAgentAddress,
      recipientAddress: '0x429876543210fedcba9876543210fedcba98765',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(120000000),
      amountDisplayUsdc: 120.0,
      status: TreasuryActionStatus.pending,
      riskScore: 62,
      purpose: 'Dedicated cloud security cluster renewal',
      timestamp: now.subtract(const Duration(minutes: 20)),
    ),
    TreasuryAction(
      actionId: 'act_3',
      agentAddress: kFixtureAgentAddress,
      recipientAddress: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(5000000000),
      amountDisplayUsdc: 5000.0,
      status: TreasuryActionStatus.rejected,
      riskScore: 99,
      purpose: 'Unrecognized transfer request',
      timestamp: now.subtract(const Duration(hours: 1)),
    ),
    TreasuryAction(
      actionId: 'act_4',
      agentAddress: kFixtureAgentAddress,
      recipientAddress: '0x91234567890abcdef1234567890abcdef123456',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(9000000),
      amountDisplayUsdc: 9.0,
      status: TreasuryActionStatus.executed,
      riskScore: 4,
      purpose: 'OpenAI platform API credits',
      timestamp: now.subtract(const Duration(hours: 2)),
      txHash: '0xdef456',
    ),
    TreasuryAction(
      actionId: 'act_5',
      agentAddress: kFixtureAgentAddress,
      recipientAddress: '0x5566778899aabbccddeeff001122334455667788',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(15000000),
      amountDisplayUsdc: 15.0,
      status: TreasuryActionStatus.executed,
      riskScore: 11,
      purpose: 'AWS compute reservation',
      timestamp: now.subtract(const Duration(hours: 3)),
      txHash: '0x789abc',
    ),
  ];
}

PendingX402Approval buildFixturePendingApproval({String actionId = 'action-golden-1'}) {
  final validBefore = (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000).toString();
  return PendingX402Approval(
    actionId: actionId,
    resourceUrl: 'https://api.example.com/v1/weather',
    amountAtomicUnits: '2500000',
    payTo: '0x1111111111111111111111111111111111111111',
    agentAddress: kFixtureAgentAddress,
    justification: 'x402: https://api.example.com/v1/weather | exceeds autonomous cap',
    riskScore: 64,
    reasons: const ['Exceeds per-payment autonomous limit'],
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
        'from': kFixtureApproverAddress,
        'to': '0x1111111111111111111111111111111111111111',
        'value': '2500000',
        'validAfter': '0',
        'validBefore': validBefore,
        'nonce': '0x2f4f8f0e4b1d3a1c6e5f7a8b9c0d1e2f3a4b5c6d7e8f90112233445566778899',
      },
    ),
    createdAt: DateTime.now(),
  );
}

/// A [Chapter2ApiService] fake for goldens: returns fixture data instead of
/// calling the network.
class GoldenChapter2ApiService extends Chapter2ApiService {
  GoldenChapter2ApiService({
    this.actions = const [],
    this.mandate,
    this.worldIdVerified = false,
  });

  final List<TreasuryAction> actions;
  final TreasuryMandate? mandate;
  final bool worldIdVerified;

  @override
  Future<List<TreasuryAction>> fetchActions({TreasuryActionStatus? status}) async => actions;

  @override
  Future<TreasuryMandate> fetchMandate() async {
    return mandate ??
        const TreasuryMandate(
          maxAutonomousAmountUsdc: 100.0,
          dailyAutonomousLimitUsdc: 500.0,
          currentDailySpentUsdc: 40.0,
          approvedRecipients: [],
          approvedTokens: [],
          safeAddress: kFixtureSafeAddress,
          guardAddress: kFixtureGuardAddress,
        );
  }

  @override
  Future<WorldIdStatus> fetchWorldIdStatus(String walletAddress) async {
    return WorldIdStatus(signerAddress: walletAddress, isVerified: worldIdVerified);
  }
}

/// An [X402ApprovalsApiService] fake for goldens.
class GoldenX402ApprovalsApiService extends X402ApprovalsApiService {
  GoldenX402ApprovalsApiService({List<PendingX402Approval>? pending})
      : pending = pending ?? [],
        super(apiClient: null);

  final List<PendingX402Approval> pending;

  @override
  Future<X402ApprovalConfig> fetchApprovalConfig() async => const X402ApprovalConfig(
        approverAddress: kFixtureApproverAddress,
        network: 'eip155:84532',
        usdcAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      );

  @override
  Future<List<PendingX402Approval>> fetchPendingApprovals() async => pending;

  @override
  Future<void> submitApprovalSignature({required String actionId, required String signature}) async {}

  @override
  Future<void> submitRejectionSignature({required String actionId, required String signature}) async {}
}

class GoldenLedgerEthereumSigner implements LedgerEthereumSigner {
  GoldenLedgerEthereumSigner({required this.address});

  final String address;

  @override
  Future<String> getAddress() async => address;

  @override
  Future<LedgerSignature> signEip712Hashed({
    required Uint8List domainSeparator,
    required Uint8List messageHash,
  }) async {
    throw UnimplementedError('Not exercised by screenshot goldens');
  }

  @override
  Future<LedgerSignature> signPersonalMessage(Uint8List message) async {
    throw UnimplementedError('Not exercised by screenshot goldens');
  }
}

/// A [LedgerBleClient] fake that "connects" instantly to a fixed signer, so
/// goldens can show a matching, connected Ledger without real Bluetooth.
class GoldenLedgerBleClient implements LedgerBleClient {
  GoldenLedgerBleClient(this.signer);

  final LedgerEthereumSigner signer;

  @override
  Stream<LedgerDevice> scan() => const Stream.empty();

  @override
  Future<void> stopScanning() async {}

  @override
  Future<LedgerEthereumSigner> connectSigner(LedgerDevice device) async => signer;

  @override
  Future<void> disconnect() async {}
}

const goldenLedgerDevice = LedgerDevice(
  id: 'golden-device',
  name: 'Nano X',
  connectionType: ConnectionType.ble,
  deviceInfo: LedgerDeviceType.nanoX,
);

// Services tab fixtures, shaped like the live `GET /discovery/resources`
// catalog (see TICKET-MOBILE-003).

const kFixtureWeatherService = BazaarService(
  resourceUrl: 'https://chapter2-backend.onrender.com/x402/weather',
  serviceName: 'Open-Meteo Weather Oracle',
  description: 'Real-time weather telemetry from Open-Meteo for a given city',
  tags: ['weather', 'climate', 'oracle', 'open-meteo'],
  method: 'GET',
  queryParams: {'city': 'Lagos'},
  outputExample: {
    'city': 'Lagos',
    'temperatureC': 29.4,
    'humidity': 77,
    'windSpeedKph': 11.2,
    'source': 'open-meteo.com',
  },
  priceAtomicUnits: '10000',
  payTo: '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
  network: 'eip155:84532',
);

const kFixtureChainReportService = BazaarService(
  resourceUrl: 'https://chapter2-backend.onrender.com/x402/chain-report',
  serviceName: 'Base Sepolia Chain Report',
  description: 'Live Base Sepolia chain report: latest block, fee data and USDC supply',
  tags: ['chain', 'base-sepolia', 'rpc', 'usdc'],
  method: 'GET',
  queryParams: {},
  outputExample: {
    'network': 'eip155:84532',
    'blockNumber': 12345678,
  },
  priceAtomicUnits: '2000000',
  payTo: '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
  network: 'eip155:84532',
);

const kFixturePartnerFeedService = BazaarService(
  resourceUrl: 'https://chapter2-backend.onrender.com/x402/partner-feed',
  serviceName: 'Partner Chain Feed',
  description: 'Partner chain data feed (demo: unapproved payee, expected to BLOCK)',
  tags: ['chain', 'base-sepolia', 'partner'],
  method: 'GET',
  queryParams: {},
  outputExample: {
    'network': 'eip155:84532',
    'blockNumber': 12345678,
  },
  priceAtomicUnits: '50000',
  payTo: '0xbB3a82Db5D91c3B7a24DB7A493316302444D7cEf',
  network: 'eip155:84532',
);

List<BazaarService> buildFixtureCatalog() => const [
      kFixtureWeatherService,
      kFixtureChainReportService,
      kFixturePartnerFeedService,
    ];

PurchaseRequest buildFixturePurchaseRequestPaid() {
  final now = DateTime.now().toUtc();
  return PurchaseRequest.fromJson({
    'id': 'pr_paid_1',
    'agentAddress': kFixtureAgentAddress,
    'serviceName': kFixtureWeatherService.serviceName,
    'resourceUrl': kFixtureWeatherService.resourceUrl,
    'queryParams': {'city': 'Lagos'},
    'justification': 'Purchase Open-Meteo Weather Oracle for company use',
    'amount': kFixtureWeatherService.priceAtomicUnits,
    'status': 'PAID',
    'actionId': 'act_paid_1',
    'decision': 'ALLOW',
    'reasons': <String>[],
    'transactionHash': '0x4f7c9e2b1a6d3f8e0c5b2a9d7e4f1c8b6a3d0e9f2c5b8a1d4e7f0c3b6a9d2e5f',
    'response': {
      'city': 'Lagos',
      'temperatureC': 29.4,
      'humidity': 77,
      'windSpeedKph': 11.2,
      'source': 'open-meteo.com',
    },
    'error': null,
    'createdAt': now.subtract(const Duration(minutes: 2)).toIso8601String(),
    'updatedAt': now.toIso8601String(),
  });
}

PurchaseRequest buildFixturePurchaseRequestEscalated() {
  final now = DateTime.now().toUtc();
  return PurchaseRequest.fromJson({
    'id': 'pr_escalated_1',
    'agentAddress': kFixtureAgentAddress,
    'serviceName': kFixtureChainReportService.serviceName,
    'resourceUrl': kFixtureChainReportService.resourceUrl,
    'queryParams': <String, String>{},
    'justification': 'Purchase Base Sepolia Chain Report for company use',
    'amount': kFixtureChainReportService.priceAtomicUnits,
    'status': 'AUTHORIZED',
    'actionId': 'act_escalated_1',
    'decision': 'ESCALATE',
    'reasons': ['Exceeds per-payment autonomous limit'],
    'transactionHash': null,
    'response': null,
    'error': null,
    'createdAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
    'updatedAt': now.toIso8601String(),
  });
}

/// A [ServicesApiService] fake for goldens and widget tests: returns fixture
/// data instead of calling the network.
class GoldenServicesApiService extends ServicesApiService {
  GoldenServicesApiService({
    List<BazaarService>? catalog,
    List<PurchaseRequest>? purchases,
    PurchaseRequest? purchaseRequestById,
  })  : catalog = catalog ?? buildFixtureCatalog(),
        purchases = purchases ?? const [],
        _purchaseRequestById = purchaseRequestById,
        super(apiClient: null);

  final List<BazaarService> catalog;
  final List<PurchaseRequest> purchases;
  final PurchaseRequest? _purchaseRequestById;

  @override
  Future<List<BazaarService>> fetchCatalog() async => catalog;

  @override
  Future<List<PurchaseRequest>> fetchPurchaseRequests() async => purchases;

  @override
  Future<PurchaseRequest> fetchPurchaseRequest(String id) async {
    final request = _purchaseRequestById;
    if (request == null) throw StateError('No fixture purchase request configured for goldens');
    return request;
  }

  @override
  Future<PurchaseRequest> createPurchaseRequest({
    required String agentAddress,
    required String resourceUrl,
    required Map<String, String> queryParams,
    required String justification,
  }) async {
    throw UnimplementedError('Not exercised by screenshot goldens');
  }
}

/// A [WorldIdApiService] fake for goldens and widget tests.
class GoldenWorldIdApiService extends WorldIdApiService {
  GoldenWorldIdApiService({
    this.status = const WorldIdApproverStatus(
      approverAddress: kFixtureApproverAddress,
      isWorldIdRequired: true,
      isWorldIdConfigured: true,
      environment: 'staging',
      isVerified: true,
      credential: 'orb',
    ),
  }) : super(apiClient: null);

  final WorldIdApproverStatus status;

  @override
  Future<WorldIdApproverStatus> fetchApproverStatus() async => status;
}
