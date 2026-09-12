import 'package:chapter2/features/approval/models/eip712_payload.dart';
import 'package:chapter2/features/guardian_alert/models/guardian_decision.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:equatable/equatable.dart';

class ProposeActionResponse extends Equatable {
  const ProposeActionResponse({
    required this.action,
    required this.decision,
    this.typedData,
  });

  final TreasuryAction action;
  final GuardianDecision decision;
  final Eip712ApprovalPayload? typedData;

  factory ProposeActionResponse.fromJson(Map<String, dynamic> json) {
    final actionData = json['action'] is Map<String, dynamic>
        ? json['action'] as Map<String, dynamic>
        : json;
    final decisionData = json['decision'] is Map<String, dynamic>
        ? json['decision'] as Map<String, dynamic>
        : <String, dynamic>{};
    final typedDataRaw = json['typedData'] as Map<String, dynamic>?;

    return ProposeActionResponse(
      action: TreasuryAction.fromJson(actionData),
      decision: GuardianDecision.fromJson(decisionData),
      typedData: typedDataRaw != null ? Eip712ApprovalPayload.fromJson(typedDataRaw) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.toJson(),
      'decision': decision.toJson(),
      if (typedData != null) 'typedData': typedData!.toMap(),
    };
  }

  @override
  List<Object?> get props => [action, decision, typedData];
}
