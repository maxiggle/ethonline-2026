import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/services/models/bazaar_service.dart';
import 'package:chapter2/features/services/models/purchase_request.dart';

/// Client for the Services tab's two data sources: the public x402 catalog
/// (`GET /discovery/resources`) and the Privy-authenticated purchase-request
/// routes fixed by X402-004's API contract. Uses the shared [ApiClient], so
/// requests carry the Privy bearer token [AuthService] already attaches.
class ServicesApiService {
  ServicesApiService({ApiClient? apiClient, String? baseUrl}) : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<List<BazaarService>> fetchCatalog() async {
    final data = await _client.get('/discovery/resources');
    final items = data is Map ? data['items'] as List<dynamic>? ?? const [] : const [];
    return items
        .map((item) => BazaarService.fromCatalogItem(Map<String, dynamic>.from(item as Map)))
        .whereType<BazaarService>()
        .toList();
  }

  Future<PurchaseRequest> createPurchaseRequest({
    required String agentAddress,
    required String resourceUrl,
    required Map<String, String> queryParams,
    required String justification,
  }) async {
    final data = await _client.post(
      '/x402/purchase-requests',
      data: {
        'agentAddress': agentAddress,
        'resourceUrl': resourceUrl,
        'queryParams': queryParams,
        'justification': justification,
      },
    );
    return PurchaseRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PurchaseRequest>> fetchPurchaseRequests() async {
    final data = await _client.get('/x402/purchase-requests');
    if (data is List) {
      return data.map((item) => PurchaseRequest.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    }
    return [];
  }

  Future<PurchaseRequest> fetchPurchaseRequest(String id) async {
    final data = await _client.get('/x402/purchase-requests/$id');
    return PurchaseRequest.fromJson(data as Map<String, dynamic>);
  }
}
