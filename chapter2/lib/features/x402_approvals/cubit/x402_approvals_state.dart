import 'package:chapter2/features/x402_approvals/remote/models/pending_x402_approval.dart';
import 'package:chapter2/features/x402_approvals/remote/models/x402_approval_config.dart';
import 'package:equatable/equatable.dart';

enum X402ApprovalsStatus {
  idle,
  connecting,
  connected,
  awaitingDevice,
  success,
  failure,
}

class X402ApprovalsState extends Equatable {
  const X402ApprovalsState({
    this.status = X402ApprovalsStatus.idle,
    this.config,
    this.pendingApprovals = const [],
    this.connectedAddress,
    this.matchesApprover = false,
    this.awaitingActionId,
    this.awaitingMessage,
    this.errorMessage,
    this.lastCompletedActionId,
  });

  final X402ApprovalsStatus status;
  final X402ApprovalConfig? config;
  final List<PendingX402Approval> pendingApprovals;
  final String? connectedAddress;
  final bool matchesApprover;
  final String? awaitingActionId;
  final String? awaitingMessage;
  final String? errorMessage;
  final String? lastCompletedActionId;

  bool get isLedgerReady => connectedAddress != null && matchesApprover;

  X402ApprovalsState copyWith({
    X402ApprovalsStatus? status,
    X402ApprovalConfig? config,
    List<PendingX402Approval>? pendingApprovals,
    String? connectedAddress,
    bool? matchesApprover,
    String? awaitingActionId,
    bool clearAwaitingActionId = false,
    String? awaitingMessage,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? lastCompletedActionId,
  }) {
    return X402ApprovalsState(
      status: status ?? this.status,
      config: config ?? this.config,
      pendingApprovals: pendingApprovals ?? this.pendingApprovals,
      connectedAddress: connectedAddress ?? this.connectedAddress,
      matchesApprover: matchesApprover ?? this.matchesApprover,
      awaitingActionId: clearAwaitingActionId ? null : (awaitingActionId ?? this.awaitingActionId),
      awaitingMessage: awaitingMessage ?? this.awaitingMessage,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      lastCompletedActionId: lastCompletedActionId ?? this.lastCompletedActionId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        config,
        pendingApprovals,
        connectedAddress,
        matchesApprover,
        awaitingActionId,
        awaitingMessage,
        errorMessage,
        lastCompletedActionId,
      ];
}
