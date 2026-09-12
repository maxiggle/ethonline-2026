import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/bills/models/company_bill.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/models/models.dart';

class Chapter2ApiService {
  Chapter2ApiService({ApiClient? apiClient, String? baseUrl})
    : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<List<TreasuryAction>> fetchActions({
    TreasuryActionStatus? status,
  }) async {
    final query = status != null ? {'status': status.toServerString()} : null;
    final data = await _client.get('/actions', queryParameters: query);
    if (data is List) {
      return data
          .map((item) => TreasuryAction.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<TreasuryAction?> fetchActionById(String actionId) async {
    final data = await _client.get('/actions/$actionId');
    if (data is Map<String, dynamic>) {
      return TreasuryAction.fromJson(data);
    }
    return null;
  }

  Future<ProposeActionResponse> proposeAction(
    ProposeActionRequest request,
  ) async {
    final data = await _client.post('/actions/propose', data: request.toJson());
    return ProposeActionResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<ApproveActionResponse> approveAction(
    String actionId,
    SubmitApprovalRequest request,
  ) async {
    final data = await _client.post(
      '/actions/$actionId/approve',
      data: request.toJson(),
    );
    return ApproveActionResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<TreasuryAction> rejectAction(
    String actionId,
    RejectActionRequest request,
  ) async {
    final data = await _client.post(
      '/actions/$actionId/reject',
      data: request.toJson(),
    );
    return TreasuryAction.fromJson(data as Map<String, dynamic>);
  }

  Future<TreasuryMandate> fetchMandate() async {
    final data = await _client.get('/mandates/active');
    return TreasuryMandate.fromJson(data as Map<String, dynamic>);
  }

  Future<VerifySelfieResponse> verifyWorldIdSelfie(
    VerifySelfieRequest request,
  ) async {
    final data = await _client.post(
      '/world/verify-selfie',
      data: request.toJson(),
    );
    return VerifySelfieResponse.fromJson(data as Map<String, dynamic>);
  }

  // --- Corporate Connected Accounts ---
  Future<List<ConnectedAccount>> fetchConnectedAccounts() async {
    final data = await _client.get('/vendor/accounts');
    if (data is List) {
      return data
          .map((e) => ConnectedAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ConnectedAccount> connectAccount({
    required String provider,
    required String name,
    required String organization,
    required String accountId,
    List<String>? projects,
  }) async {
    final data = await _client.post(
      '/vendor/accounts/connect',
      data: {
        'provider': provider,
        'name': name,
        'organization': organization,
        'accountId': accountId,
        'projects': ?projects,
      },
    );
    return ConnectedAccount.fromJson(data as Map<String, dynamic>);
  }

  // --- Company Invoices & x402 Bills ---
  Future<List<CompanyBill>> fetchCompanyBills() async {
    final data = await _client.get('/vendor/bills');
    if (data is List) {
      return data
          .map((e) => CompanyBill.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CompanyBill> fetchBillById(String billId) async {
    final data = await _client.get('/vendor/bills/$billId');
    return CompanyBill.fromJson(data as Map<String, dynamic>);
  }

  Future<PayBillResponse> payCompanyBill(
    String billId, {
    String? agentAddress,
  }) async {
    final data = await _client.post(
      '/vendor/bills/$billId/pay',
      data: {'agentAddress': ?agentAddress},
    );
    return PayBillResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<List<BazaarResource>> fetchBazaarResources() async {
    final data = await _client.get('/discovery/resources');
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => BazaarResource.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<BazaarResource>> searchBazaarResources({
    required String query,
    String? type,
  }) async {
    final queryParams = <String, dynamic>{'query': query};
    if (type != null) {
      queryParams['type'] = type;
    }
    final data = await _client.get(
      '/discovery/search',
      queryParameters: queryParams,
    );
    if (data is Map<String, dynamic> && data['resources'] is List) {
      return (data['resources'] as List)
          .map((e) => BazaarResource.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<BazaarInvocationResult> invokeBazaarService({
    required String resourceUrl,
    String? method,
    Map<String, dynamic>? params,
    String? agentAddress,
  }) async {
    final data = await _client.post(
      '/discovery/call',
      data: {
        'resourceUrl': resourceUrl,
        'method': method ?? 'GET',
        'params': ?params,
        'agentAddress': ?agentAddress,
      },
    );
    return BazaarInvocationResult.fromJson(data as Map<String, dynamic>);
  }
}
