import 'package:chapter2/features/world_id/remote/models/world_id_approver_status.dart';
import 'package:chapter2/features/world_id/remote/models/world_id_orb_verification.dart';
import 'package:equatable/equatable.dart';

enum WorldIdApproverCubitStatus {
  initial,
  loading,
  ready,
  verifying,
  binding,
  failure,
}

class WorldIdApproverState extends Equatable {
  const WorldIdApproverState({
    this.status = WorldIdApproverCubitStatus.initial,
    this.approverStatus,
    this.verification,
    this.errorMessage,
  });

  final WorldIdApproverCubitStatus status;
  final WorldIdApproverStatus? approverStatus;
  final WorldIdOrbVerification? verification;
  final String? errorMessage;

  bool get isVerified => approverStatus?.isVerified ?? false;
  bool get isWorldIdRequired => approverStatus?.isWorldIdRequired ?? false;
  bool get isWorldIdConfigured => approverStatus?.isWorldIdConfigured ?? false;

  WorldIdApproverState copyWith({
    WorldIdApproverCubitStatus? status,
    WorldIdApproverStatus? approverStatus,
    WorldIdOrbVerification? verification,
    bool clearVerification = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return WorldIdApproverState(
      status: status ?? this.status,
      approverStatus: approverStatus ?? this.approverStatus,
      verification: clearVerification ? null : (verification ?? this.verification),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, approverStatus, verification, errorMessage];
}
