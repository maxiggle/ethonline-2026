import 'package:equatable/equatable.dart';

class Eip712ApprovalPayload extends Equatable {
  const Eip712ApprovalPayload({
    required this.actionId,
    required this.agentAddress,
    required this.recipientAddress,
    required this.tokenAddress,
    required this.amountUnits,
    required this.nonce,
    required this.deadline,
    required this.mandateHash,
    required this.riskScore,
    this.signatureHex,
  });

  final String actionId;
  final String agentAddress;
  final String recipientAddress;
  final String tokenAddress;
  final BigInt amountUnits;
  final int nonce;
  final int deadline;
  final String mandateHash;
  final int riskScore;
  final String? signatureHex;

  factory Eip712ApprovalPayload.fromJson(Map<String, dynamic> json) {
    return Eip712ApprovalPayload(
      actionId: (json['actionId'] ?? '') as String,
      agentAddress: (json['agent'] ?? json['agentAddress'] ?? '') as String,
      recipientAddress: (json['recipient'] ?? json['recipientAddress'] ?? '') as String,
      tokenAddress: (json['token'] ?? json['tokenAddress'] ?? '') as String,
      amountUnits: BigInt.parse(json['amount']?.toString() ?? '0'),
      nonce: (json['nonce'] as num?)?.toInt() ?? 0,
      deadline: (json['deadline'] as num?)?.toInt() ?? 0,
      mandateHash: (json['mandateHash'] ?? '') as String,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      signatureHex: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actionId': actionId,
      'agent': agentAddress,
      'recipient': recipientAddress,
      'token': tokenAddress,
      'amount': amountUnits.toString(),
      'nonce': nonce,
      'deadline': deadline,
      'mandateHash': mandateHash,
      'riskScore': riskScore,
      if (signatureHex != null) 'signature': signatureHex,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  List<Object?> get props => [
        actionId,
        agentAddress,
        recipientAddress,
        tokenAddress,
        amountUnits,
        nonce,
        deadline,
        mandateHash,
        riskScore,
        signatureHex,
      ];
}
