import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/remote/models/x402_approval_config.dart';

/// Client for the Ledger approval-console routes of the Guardian-gated x402
/// payments API (`backend/src/x402/x402-payments.controller.ts`). Every route
/// here is a public read plus a Ledger-signature-gated write, so — unlike
/// [Chapter2ApiService] — no auth header is attached.
class X402ApprovalsApiService {
  X402ApprovalsApiService({ApiClient? apiClient, String? baseUrl}) : _client = apiClient ?? ApiClient(baseUrl: baseUrl);

  final ApiClient _client;

  Future<X402ApprovalConfig> fetchApprovalConfig() async {
    final data = await _client.get('/x402/approvals/config');
    return X402ApprovalConfig.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PendingX402Approval>> fetchPendingApprovals() async {
    final data = await _client.get('/x402/approvals/pending');
    if (data is List) {
      return data
          .map((item) => PendingX402Approval.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  Future<void> submitApprovalSignature({required String actionId, required String signature}) async {
    await _client.post('/x402/approvals/$actionId/signature', data: {'signature': signature});
  }

  Future<void> submitRejectionSignature({required String actionId, required String signature}) async {
    await _client.post('/x402/approvals/$actionId/reject', data: {'signature': signature});
  }
}
