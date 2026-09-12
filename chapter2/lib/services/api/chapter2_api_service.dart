import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/models/models.dart';

class Chapter2ApiService {
  Chapter2ApiService({ApiClient? apiClient, String? baseUrl})
      : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<List<TreasuryAction>> fetchActions({TreasuryActionStatus? status}) async {
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

  Future<ProposeActionResponse> proposeAction(ProposeActionRequest request) async {
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

  Future<VerifySelfieResponse> verifyWorldIdSelfie(VerifySelfieRequest request) async {
    final data = await _client.post('/world/verify-selfie', data: request.toJson());
    return VerifySelfieResponse.fromJson(data as Map<String, dynamic>);
  }
}
