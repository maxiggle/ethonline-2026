import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:equatable/equatable.dart';

enum ApprovalStepStatus {
  idle,
  biometricsPrompt,
  biometricsVerified,
  ledgerClearSignReview,
  signing,
  approvedSuccess,
  failure,
}

class ApprovalState extends Equatable {
  const ApprovalState({
    this.status = ApprovalStepStatus.idle,
    this.payload,
    this.txHash,
    this.errorMessage,
  });

  final ApprovalStepStatus status;
  final Eip712ApprovalPayload? payload;
  final String? txHash;
  final String? errorMessage;

  ApprovalState copyWith({
    ApprovalStepStatus? status,
    Eip712ApprovalPayload? payload,
    String? txHash,
    String? errorMessage,
  }) {
    return ApprovalState(
      status: status ?? this.status,
      payload: payload ?? this.payload,
      txHash: txHash ?? this.txHash,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, payload, txHash, errorMessage];
}
