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

  static TreasuryActionStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return TreasuryActionStatus.pending;
      case 'APPROVED':
        return TreasuryActionStatus.approved;
      case 'EXECUTED':
        return TreasuryActionStatus.executed;
      case 'REJECTED':
      case 'BLOCKED':
        return TreasuryActionStatus.rejected;
      case 'EXPIRED':
        return TreasuryActionStatus.expired;
      default:
        return TreasuryActionStatus.pending;
    }
  }

  String toServerString() {
    switch (this) {
      case TreasuryActionStatus.pending:
        return 'PENDING';
      case TreasuryActionStatus.approved:
        return 'APPROVED';
      case TreasuryActionStatus.executed:
        return 'EXECUTED';
      case TreasuryActionStatus.rejected:
        return 'REJECTED';
      case TreasuryActionStatus.expired:
        return 'EXPIRED';
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

  factory TreasuryAction.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount']?.toString() ?? '0';
    final parsedUnits = BigInt.tryParse(rawAmount) ?? BigInt.zero;
    final displayUsdc = json['amountDisplayUsdc'] != null
        ? (json['amountDisplayUsdc'] as num).toDouble()
        : (parsedUnits.toDouble() / 1e6);

    return TreasuryAction(
      actionId: (json['actionId'] ?? json['id'] ?? '') as String,
      agentAddress: (json['agentAddress'] ?? json['agent'] ?? '') as String,
      recipientAddress: (json['recipientAddress'] ?? json['recipient'] ?? '') as String,
      tokenAddress: (json['tokenAddress'] ?? json['token'] ?? '') as String,
      amountUnits: parsedUnits,
      amountDisplayUsdc: displayUsdc,
      status: TreasuryActionStatus.fromString(json['status']?.toString() ?? 'PENDING'),
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      purpose: (json['purpose'] ?? json['justification'] ?? '') as String,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      nonce: (json['nonce'] as num?)?.toInt(),
      txHash: json['txHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': actionId,
      'actionId': actionId,
      'agentAddress': agentAddress,
      'recipient': recipientAddress,
      'recipientAddress': recipientAddress,
      'token': tokenAddress,
      'tokenAddress': tokenAddress,
      'amount': amountUnits.toString(),
      'amountDisplayUsdc': amountDisplayUsdc,
      'status': status.toServerString(),
      'riskScore': riskScore,
      'justification': purpose,
      'purpose': purpose,
      'timestamp': timestamp.toIso8601String(),
      if (nonce != null) 'nonce': nonce,
      if (txHash != null) 'txHash': txHash,
    };
  }

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
