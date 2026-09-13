import 'package:chapter2/features/x402_approvals/eip712/eip712_typed_data.dart';
import 'package:equatable/equatable.dart';

/// One entry from `GET /x402/approvals/pending`: an x402 payment the
/// Guardian escalated, awaiting a signature from the human's Ledger.
class PendingX402Approval extends Equatable {
  const PendingX402Approval({
    required this.actionId,
    required this.resourceUrl,
    required this.amountAtomicUnits,
    required this.payTo,
    required this.agentAddress,
    required this.justification,
    required this.riskScore,
    required this.reasons,
    required this.typedData,
    required this.createdAt,
  });

  final String actionId;
  final String resourceUrl;
  final String amountAtomicUnits;
  final String payTo;
  final String agentAddress;
  final String justification;
  final int riskScore;
  final List<String> reasons;
  final Eip712TypedData typedData;
  final DateTime createdAt;

  /// `message.validBefore` from [typedData], the moment the backend starts
  /// rejecting an approval for this action with `400`.
  DateTime get validBefore {
    final raw = typedData.message['validBefore'];
    final seconds = raw is num ? raw.toInt() : int.parse(raw.toString());
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  bool get isExpired => DateTime.now().toUtc().isAfter(validBefore);

  factory PendingX402Approval.fromJson(Map<String, dynamic> json) {
    return PendingX402Approval(
      actionId: json['actionId'] as String,
      resourceUrl: json['resourceUrl'] as String,
      amountAtomicUnits: json['amount'].toString(),
      payTo: json['payTo'] as String,
      agentAddress: json['agentAddress'] as String,
      justification: json['justification'] as String,
      riskScore: (json['riskScore'] as num).toInt(),
      reasons: List<String>.from(json['reasons'] as List? ?? const []),
      typedData: Eip712TypedData.fromJson(Map<String, dynamic>.from(json['typedData'] as Map)),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        actionId,
        resourceUrl,
        amountAtomicUnits,
        payTo,
        agentAddress,
        justification,
        riskScore,
        reasons,
        typedData,
        createdAt,
      ];
}
