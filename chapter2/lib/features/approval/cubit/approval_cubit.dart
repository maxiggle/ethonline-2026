import 'package:chapter2/features/approval/cubit/approval_state.dart';
import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
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

  Future<void> submitHardwareApproval({required String humanSignatureHex}) async {
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
      final submission = currentPayload.toMap();
      submission['signature'] = humanSignatureHex;

      final result = await _apiService.approveAction(currentPayload.actionId, submission);
      if (result != null) {
        emit(state.copyWith(
          status: ApprovalStepStatus.approvedSuccess,
          txHash: result['txHash'] as String? ?? '0xMockTxHashExecutionSuccess',
        ));
      } else {
        emit(state.copyWith(
          status: ApprovalStepStatus.failure,
          errorMessage: 'Server rejected hardware signature',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: ApprovalStepStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
