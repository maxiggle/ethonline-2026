import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/approval/cubit/approval_cubit.dart';
import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/approve_action_response.dart';
import 'package:chapter2/services/api/models/submit_approval_request.dart';

class MockApprovalApiService extends Chapter2ApiService {
  @override
  Future<ApproveActionResponse> approveAction(
    String actionId,
    SubmitApprovalRequest request,
  ) async {
    final action = TreasuryAction(
      actionId: actionId,
      agentAddress: '0xAgent',
      recipientAddress: '0xRecipient',
      tokenAddress: '0xToken',
      amountUnits: BigInt.from(850000000),
      amountDisplayUsdc: 850.0,
      status: TreasuryActionStatus.executed,
      riskScore: 78,
      purpose: 'Annual renewal',
      timestamp: DateTime.now(),
      txHash: '0xabc123success',
    );

    return ApproveActionResponse(
      action: action,
      encodedPayload: '0xencoded',
      signer: request.signer,
      txHash: '0xabc123success',
    );
  }
}

void main() {
  group('ApprovalCubit Tests', () {
    final payload = Eip712ApprovalPayload(
      actionId: 'act_850',
      agentAddress: '0xAgent',
      recipientAddress: '0xRecipient',
      tokenAddress: '0xToken',
      amountUnits: BigInt.from(850000000),
      nonce: 101,
      deadline: 1800000000,
      mandateHash: '0xHash',
      riskScore: 78,
    );

    test('initial state and initializeApproval', () {
      final cubit = ApprovalCubit(apiService: MockApprovalApiService());
      expect(cubit.state.status, ApprovalStepStatus.idle);

      cubit.initializeApproval(payload);
      expect(cubit.state.status, ApprovalStepStatus.ledgerClearSignReview);
      expect(cubit.state.payload, payload);
    });

    test('submitHardwareApproval transitions to approvedSuccess on valid API response', () async {
      final cubit = ApprovalCubit(apiService: MockApprovalApiService());
      cubit.initializeApproval(payload);

      await cubit.submitHardwareApproval(humanSignatureHex: '0xValidSig');
      expect(cubit.state.status, ApprovalStepStatus.approvedSuccess);
      expect(cubit.state.txHash, '0xabc123success');
    });
  });
}
