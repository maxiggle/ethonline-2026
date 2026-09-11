import 'package:equatable/equatable.dart';

enum TreasuryActionStatus {
  pending,
  approved,
  executed,
  rejected,
  expired;

  String get displayName {
    switch (this) {
      case TreasuryActionStatus.pending:
        return 'Pending Review';
      case TreasuryActionStatus.approved:
        return 'Approved';
      case TreasuryActionStatus.executed:
        return 'Executed On-Chain';
      case TreasuryActionStatus.rejected:
        return 'Blocked by Guardian';
      case TreasuryActionStatus.expired:
        return 'Expired';
    }
  }
}

class TreasuryAction extends Equatable {
  const TreasuryAction({
    required this.actionId,
    required this.agentAddress,
    required this.recipientAddress,
    required this.tokenAddress,
    required this.amountUnits,
    required this.amountDisplayUsdc,
    required this.status,
    required this.riskScore,
    required this.purpose,
    required this.timestamp,
    this.nonce,
    this.txHash,
  });

  final String actionId;
  final String agentAddress;
  final String recipientAddress;
  final String tokenAddress;
  final BigInt amountUnits;
  final double amountDisplayUsdc;
  final TreasuryActionStatus status;
  final int riskScore;
  final String purpose;
  final DateTime timestamp;
  final int? nonce;
  final String? txHash;

  bool get requiresEscalation => amountDisplayUsdc > 100.0 || riskScore >= 50;

  @override
  List<Object?> get props => [
        actionId,
        agentAddress,
        recipientAddress,
        tokenAddress,
        amountUnits,
        amountDisplayUsdc,
        status,
        riskScore,
        purpose,
        timestamp,
        nonce,
        txHash,
      ];
}
