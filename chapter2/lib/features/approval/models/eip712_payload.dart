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
