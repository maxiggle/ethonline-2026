import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/bills/cubit/bills_cubit.dart';
import 'package:chapter2/features/bills/cubit/bills_state.dart';
import 'package:chapter2/features/bills/models/company_bill.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';

class MockBillsApiService extends Chapter2ApiService {
  @override
  Future<List<ConnectedAccount>> fetchConnectedAccounts() async {
    return const [
      ConnectedAccount(
        id: 'acc_gcp_1',
        provider: 'google_cloud',
        name: 'Google Cloud Platform',
        organization: 'Acme Corp',
        accountId: 'billingAccounts/01A2B3-456C7D',
        status: 'CONNECTED',
        connectedAt: '2026-09-12T00:00:00Z',
      ),
    ];
  }

  @override
  Future<List<CompanyBill>> fetchCompanyBills() async {
    return const [
      CompanyBill(
        id: 'bill_gcp_001',
        provider: 'google_cloud',
        serviceName: 'Compute Engine',
        accountId: 'billingAccounts/01A2B3-456C7D',
        organization: 'Acme Corp',
        invoiceNumber: 'INV-GCP-8812',
        amount: '40000000',
        amountUsdc: 40.0,
        description: 'H100 GPU Cluster Compute',
        paymentIdentifier: 'gcp_01a2b3_inv_8812',
        dueDate: '2026-09-30',
        status: 'UNPAID_402',
      ),
    ];
  }

  @override
  Future<List<BazaarResource>> fetchBazaarResources() async {
    return const [
      BazaarResource(
        resource: '/vendor/rpc',
        type: 'http',
        serviceName: 'Alchemy Enhanced RPC Endpoint',
        description: 'High-throughput Base Sepolia archive RPC node',
        priceUsdc: 25.0,
        payTo: '0x0000000000000000000000000000000000000001',
        paymentIdentifier: 'alchemy_sub_9921_rec',
        tags: ['rpc', 'base-sepolia'],
      ),
    ];
  }

  @override
  Future<PayBillResponse> payCompanyBill(
    String billId, {
    String? agentAddress,
  }) async {
    return PayBillResponse(
      bill: const CompanyBill(
        id: 'bill_gcp_001',
        provider: 'google_cloud',
        serviceName: 'Compute Engine',
        accountId: 'billingAccounts/01A2B3-456C7D',
        organization: 'Acme Corp',
        invoiceNumber: 'INV-GCP-8812',
        amount: '40000000',
        amountUsdc: 40.0,
        description: 'H100 GPU Cluster Compute',
        paymentIdentifier: 'gcp_01a2b3_inv_8812',
        dueDate: '2026-09-30',
        status: 'SETTLED_200',
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      ),
      action: TreasuryAction(
        actionId: 'action_99',
        agentAddress: '0xAgent',
        recipientAddress: '0xRecipient',
        tokenAddress: '0xToken',
        amountUnits: BigInt.from(40000000),
        amountDisplayUsdc: 40.0,
        status: TreasuryActionStatus.executed,
        riskScore: 5,
        purpose: 'Settled GCP Invoice',
        timestamp: DateTime.now(),
        txHash: '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      ),
      decision: const {'decision': 'ALLOW', 'requiresHumanApproval': false},
    );
  }

  @override
  Future<BazaarInvocationResult> invokeBazaarService({
    required String resourceUrl,
    String? method,
    Map<String, dynamic>? params,
    String? agentAddress,
  }) async {
    return const BazaarInvocationResult(
      status: 'SUCCESS',
      serviceName: 'AccuWeather & Climate Intelligence Oracle',
      resourceUrl: '/vendor/weather',
      costUsdc: 1.0,
      decision: 'ALLOW',
      executionTimestamp: '2026-09-12T12:00:00Z',
      txHash: '0x9999567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      data: {
        'city': 'San Francisco',
        'temperatureC': 18.5,
        'conditions': 'Partly Cloudy',
      },
    );
  }
}

void main() {
  group('BillsCubit Tests', () {
    test('initial state is correct', () {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      expect(cubit.state.status, BillsStatus.initial);
      expect(cubit.state.bills, isEmpty);
      expect(cubit.state.accounts, isEmpty);
      expect(cubit.state.bazaarResources, isEmpty);
      expect(cubit.state.searchQuery, '');
      expect(cubit.state.selectedCategory, 'ALL');
    });

    test('loadAll emits success with accounts, bills, and bazaar resources', () async {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      await cubit.loadAll();

      expect(cubit.state.status, BillsStatus.success);
      expect(cubit.state.accounts.length, 1);
      expect(cubit.state.accounts.first.provider, 'google_cloud');
      expect(cubit.state.bills.length, 1);
      expect(cubit.state.bills.first.amountUsdc, 40.0);
      expect(cubit.state.bazaarResources.length, 1);
      expect(cubit.state.bazaarResources.first.serviceName, 'Alchemy Enhanced RPC Endpoint');
    });

    test('payBill triggers proposal and sets notification notice', () async {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      await cubit.loadAll();

      await cubit.payBill('bill_gcp_001');
      expect(cubit.state.lastPaymentNotice, contains('ALLOWED & Paid'));
      expect(cubit.state.lastPaymentNotice, contains('INV-GCP-8812'));
    });

    test('searchBazaar filters displayedBazaarResources correctly', () async {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      await cubit.loadAll();

      cubit.searchBazaar('alchemy');
      expect(cubit.state.displayedBazaarResources.length, 1);

      cubit.searchBazaar('nonexistent query');
      expect(cubit.state.displayedBazaarResources, isEmpty);

      cubit.searchBazaar('');
      expect(cubit.state.displayedBazaarResources.length, 1);
    });

    test('setBazaarCategory filters by category correctly', () async {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      await cubit.loadAll();

      cubit.setBazaarCategory('RPC');
      expect(cubit.state.displayedBazaarResources.length, 1);

      cubit.setBazaarCategory('WEATHER');
      expect(cubit.state.displayedBazaarResources, isEmpty);
    });

    test('invokeBazaarService settles x402 on-chain and returns result', () async {
      final cubit = BillsCubit(apiService: MockBillsApiService());
      await cubit.loadAll();

      const weatherResource = BazaarResource(
        resource: '/vendor/weather',
        type: 'http',
        serviceName: 'AccuWeather & Climate Intelligence Oracle',
        description: 'Weather oracle',
        priceUsdc: 1.0,
        payTo: '0xPayTo',
        paymentIdentifier: 'weather_inv_01',
      );

      await cubit.invokeBazaarService(weatherResource, params: {'city': 'San Francisco'});

      expect(cubit.state.isInvokingService, false);
      expect(cubit.state.lastInvocationResult, isNotNull);
      expect(cubit.state.lastInvocationResult?.status, 'SUCCESS');
      expect(cubit.state.lastInvocationResult?.data?['city'], 'San Francisco');
      expect(cubit.state.lastPaymentNotice, contains('x402 challenge settled'));
    });
  });
}
