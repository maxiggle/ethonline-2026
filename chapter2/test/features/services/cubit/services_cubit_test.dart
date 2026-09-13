import 'package:chapter2/features/services/cubit/services_cubit.dart';
import 'package:chapter2/features/services/cubit/services_state.dart';
import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';
import 'package:chapter2/features/services/remote/services_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _weatherService = BazaarService(
  resourceUrl: 'https://chapter2-backend.onrender.com/x402/weather',
  serviceName: 'Open-Meteo Weather Oracle',
  description: 'Real-time weather telemetry from Open-Meteo for a given city',
  tags: ['weather', 'climate', 'oracle', 'open-meteo'],
  method: 'GET',
  queryParams: {'city': 'Lagos'},
  outputExample: {'city': 'Lagos', 'temperatureC': 29.4},
  priceAtomicUnits: '10000',
  payTo: '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
  network: 'eip155:84532',
);

const _chainReportService = BazaarService(
  resourceUrl: 'https://chapter2-backend.onrender.com/x402/chain-report',
  serviceName: 'Base Sepolia Chain Report',
  description: 'Live Base Sepolia chain report: latest block, fee data and USDC supply',
  tags: ['chain', 'base-sepolia', 'rpc', 'usdc'],
  method: 'GET',
  queryParams: {},
  outputExample: {'blockNumber': 12345678},
  priceAtomicUnits: '2000000',
  payTo: '0xD11dBAA787f8a51F22EC72c4d9D497F6a127e76f',
  network: 'eip155:84532',
);

PurchaseRequest _purchaseRequest({String id = 'pr_1', String status = 'QUEUED'}) {
  return PurchaseRequest.fromJson({
    'id': id,
    'agentAddress': '0x1111111111111111111111111111111111111111',
    'serviceName': _weatherService.serviceName,
    'resourceUrl': _weatherService.resourceUrl,
    'queryParams': {'city': 'Lagos'},
    'justification': 'Purchase weather data for company use',
    'amount': _weatherService.priceAtomicUnits,
    'status': status,
    'actionId': null,
    'decision': null,
    'reasons': <String>[],
    'transactionHash': null,
    'response': null,
    'error': null,
    'createdAt': '2026-09-13T06:00:00.000Z',
    'updatedAt': '2026-09-13T06:00:00.000Z',
  });
}

class _FakeServicesApiService extends ServicesApiService {
  _FakeServicesApiService() : super(apiClient: null);

  List<BazaarService> catalog = [_weatherService, _chainReportService];
  Object? catalogError;
  int fetchCatalogCallCount = 0;

  List<PurchaseRequest> purchases = [];
  int fetchPurchaseRequestsCallCount = 0;

  PurchaseRequest? createResult;
  Object? createError;
  Map<String, dynamic>? lastCreateCall;

  @override
  Future<List<BazaarService>> fetchCatalog() async {
    fetchCatalogCallCount++;
    final error = catalogError;
    if (error != null) throw error;
    return catalog;
  }

  @override
  Future<List<PurchaseRequest>> fetchPurchaseRequests() async {
    fetchPurchaseRequestsCallCount++;
    return purchases;
  }

  @override
  Future<PurchaseRequest> createPurchaseRequest({
    required String agentAddress,
    required String resourceUrl,
    required Map<String, String> queryParams,
    required String justification,
  }) async {
    lastCreateCall = {
      'agentAddress': agentAddress,
      'resourceUrl': resourceUrl,
      'queryParams': queryParams,
      'justification': justification,
    };
    final error = createError;
    if (error != null) throw error;
    return createResult!;
  }

  @override
  Future<PurchaseRequest> fetchPurchaseRequest(String id) async {
    throw UnimplementedError('Not exercised by ServicesCubit tests');
  }
}

void main() {
  group('ServicesCubit', () {
    test('loadCatalogOnce fetches the catalog exactly once across repeated calls', () async {
      final api = _FakeServicesApiService();
      final cubit = ServicesCubit(apiService: api);

      await cubit.loadCatalogOnce();
      await cubit.loadCatalogOnce();
      await cubit.loadCatalogOnce();

      expect(api.fetchCatalogCallCount, 1);
      expect(cubit.state.catalogStatus, ServicesCatalogStatus.success);
      expect(cubit.state.catalog, [_weatherService, _chainReportService]);

      await cubit.close();
    });

    test('refreshCatalog always refetches, for pull-to-refresh', () async {
      final api = _FakeServicesApiService();
      final cubit = ServicesCubit(apiService: api);

      await cubit.loadCatalogOnce();
      await cubit.refreshCatalog();

      expect(api.fetchCatalogCallCount, 2);

      await cubit.close();
    });

    test('search filters the already-fetched catalog locally with no extra API calls', () async {
      final api = _FakeServicesApiService();
      final cubit = ServicesCubit(apiService: api);
      await cubit.loadCatalogOnce();

      cubit.updateSearchQuery('weather');
      expect(cubit.state.filteredCatalog, [_weatherService]);

      cubit.updateSearchQuery('BASE-SEPOLIA');
      expect(cubit.state.filteredCatalog, [_chainReportService]);

      cubit.updateSearchQuery('oracle');
      expect(cubit.state.filteredCatalog, [_weatherService]);

      // No network call was made for any keystroke above.
      expect(api.fetchCatalogCallCount, 1);

      await cubit.close();
    });

    test('an unmatched search shows the empty-result state', () async {
      final api = _FakeServicesApiService();
      final cubit = ServicesCubit(apiService: api);
      await cubit.loadCatalogOnce();

      cubit.updateSearchQuery('zzz-nonexistent');

      expect(cubit.state.filteredCatalog, isEmpty);
      expect(cubit.state.isSearching, isTrue);

      cubit.clearSearchQuery();
      expect(cubit.state.filteredCatalog, [_weatherService, _chainReportService]);
      expect(cubit.state.isSearching, isFalse);

      await cubit.close();
    });

    test('a catalog failure surfaces the error and Retry recovers', () async {
      final api = _FakeServicesApiService()..catalogError = Exception('network down');
      final cubit = ServicesCubit(apiService: api);

      await cubit.loadCatalogOnce();
      expect(cubit.state.catalogStatus, ServicesCatalogStatus.failure);
      expect(cubit.state.catalogError, contains('network down'));

      api.catalogError = null;
      await cubit.refreshCatalog();

      expect(cubit.state.catalogStatus, ServicesCatalogStatus.success);
      expect(cubit.state.catalogError, isNull);
      expect(cubit.state.catalog, isNotEmpty);

      await cubit.close();
    });

    test('createPurchaseRequest success updates state and refreshes purchases', () async {
      final created = _purchaseRequest();
      final api = _FakeServicesApiService()
        ..createResult = created
        ..purchases = [created];
      final cubit = ServicesCubit(apiService: api);

      final result = await cubit.createPurchaseRequest(
        agentAddress: '0x1111111111111111111111111111111111111111',
        resourceUrl: _weatherService.resourceUrl,
        queryParams: {'city': 'Lagos'},
        justification: 'Purchase weather data for company use',
      );

      expect(result, created);
      expect(cubit.state.createStatus, ServicesCreateStatus.success);
      expect(api.lastCreateCall?['resourceUrl'], _weatherService.resourceUrl);

      // refreshPurchases() is fired-and-forgotten on success; let it settle.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.purchases, [created]);

      await cubit.close();
    });

    test('createPurchaseRequest failure surfaces the backend error and returns null', () async {
      final api = _FakeServicesApiService()..createError = Exception('justification too long');
      final cubit = ServicesCubit(apiService: api);

      final result = await cubit.createPurchaseRequest(
        agentAddress: '0x1111111111111111111111111111111111111111',
        resourceUrl: _weatherService.resourceUrl,
        queryParams: {'city': 'Lagos'},
        justification: 'x' * 300,
      );

      expect(result, isNull);
      expect(cubit.state.createStatus, ServicesCreateStatus.failure);
      expect(cubit.state.createError, contains('justification too long'));

      await cubit.close();
    });

    test('purchases polling fetches immediately and stops on stopPurchasesPolling', () async {
      final api = _FakeServicesApiService()..purchases = [_purchaseRequest()];
      final cubit = ServicesCubit(apiService: api);

      cubit.startPurchasesPolling();
      await Future<void>.delayed(Duration.zero);
      expect(api.fetchPurchaseRequestsCallCount, 1);
      expect(cubit.state.purchases, hasLength(1));

      cubit.stopPurchasesPolling();

      await cubit.close();
    });
  });
}
