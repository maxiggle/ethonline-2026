import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/submit_approval_request.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ApprovalCubit extends Cubit<ApprovalState> {
  ApprovalCubit({required Chapter2ApiService apiService})
      : _apiService = apiService,
        super(const ApprovalState());

  final Chapter2ApiService _apiService;

  void initializeApproval(Eip712ApprovalPayload payload) {
    emit(state.copyWith(
      status: ApprovalStepStatus.ledgerClearSignReview,
      payload: payload,
    ));
  }

  Future<void> confirmBiometricChallenge() async {
    emit(state.copyWith(status: ApprovalStepStatus.biometricsPrompt));
    emit(state.copyWith(status: ApprovalStepStatus.biometricsVerified));
  }

  Future<void> submitHardwareApproval({
    required String humanSignatureHex,
    String? signerAddress,
  }) async {
    final currentPayload = state.payload;
    if (currentPayload == null) {
      emit(state.copyWith(
        status: ApprovalStepStatus.failure,
        errorMessage: 'Missing approval payload',
      ));
      return;
    }

    emit(state.copyWith(status: ApprovalStepStatus.signing));
    try {
      final request = SubmitApprovalRequest(
        actionId: currentPayload.actionId,
        signature: humanSignatureHex,
        signer: signerAddress ?? '0x0000000000000000000000000000000000041c4e',
        biometricVerified: true,
      );

      final result = await _apiService.approveAction(currentPayload.actionId, request);
      emit(state.copyWith(
        status: ApprovalStepStatus.approvedSuccess,
        txHash: result.txHash ?? '0xMockTxHashExecutionSuccess',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ApprovalStepStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
