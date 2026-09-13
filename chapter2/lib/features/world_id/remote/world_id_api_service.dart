import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_approver_status.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';

class WorldIdApiService {
  WorldIdApiService({ApiClient? apiClient, String? baseUrl})
      : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<WorldIdApproverStatus> fetchApproverStatus() async {
    final data = await _client.get('/world/approver/status');
    return WorldIdApproverStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WorldIdOrbVerification> startOrbVerification() async {
    final data = await _client.post('/world/approver/orb-verifications');
    return WorldIdOrbVerification.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WorldIdOrbVerification> fetchOrbVerification(String requestId) async {
    final data = await _client.get('/world/approver/orb-verifications/$requestId');
    return WorldIdOrbVerification.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<WorldIdApproverStatus> bindLedgerApprover({
    required String requestId,
    required String signature,
  }) async {
    final data = await _client.post(
      '/world/approver/orb-verifications/$requestId/bind',
      data: {'signature': signature},
    );
    return WorldIdApproverStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
