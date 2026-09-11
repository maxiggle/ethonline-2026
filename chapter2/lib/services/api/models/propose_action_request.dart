import 'package:equatable/equatable.dart';

class ProposeActionRequest extends Equatable {
  const ProposeActionRequest({
    required this.target,
    required this.value,
    required this.data,
    required this.token,
    required this.recipient,
    required this.amount,
    required this.agentAddress,
    required this.justification,
    this.worldIdProof,
  });

  final String target;
  final String value;
  final String data;
  final String token;
  final String recipient;
  final String amount;
  final String agentAddress;
  final String justification;
  final Map<String, dynamic>? worldIdProof;

  Map<String, dynamic> toJson() {
    return {
      'target': target,
      'value': value,
      'data': data,
      'token': token,
      'recipient': recipient,
      'amount': amount,
      'agentAddress': agentAddress,
      'justification': justification,
      if (worldIdProof != null) 'worldIdProof': worldIdProof,
    };
  }

  factory ProposeActionRequest.fromJson(Map<String, dynamic> json) {
    return ProposeActionRequest(
      target: json['target'] as String? ?? '',
      value: json['value'] as String? ?? '0',
      data: json['data'] as String? ?? '0x',
      token: json['token'] as String? ?? '',
      recipient: json['recipient'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      agentAddress: json['agentAddress'] as String? ?? '',
      justification: json['justification'] as String? ?? '',
      worldIdProof: json['worldIdProof'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        target,
        value,
        data,
        token,
        recipient,
        amount,
        agentAddress,
        justification,
        worldIdProof,
      ];
}
