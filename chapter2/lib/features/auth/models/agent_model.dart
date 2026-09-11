import 'package:equatable/equatable.dart';

class AgentModel extends Equatable {
  const AgentModel({
    required this.id,
    required this.userId,
    required this.agentAddress,
    required this.name,
    this.purpose,
    required this.safeAddress,
    required this.guardAddress,
    this.chainId = 84532,
    this.status = 'ACTIVE',
  });

  final String id;
  final String userId;
  final String agentAddress;
  final String name;
  final String? purpose;
  final String safeAddress;
  final String guardAddress;
  final int chainId;
  final String status;

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      agentAddress: json['agentAddress'] as String? ?? json['agent_address'] as String? ?? '',
      name: json['name'] as String? ?? 'Autonomous Agent',
      purpose: json['purpose'] as String?,
      safeAddress: json['safeAddress'] as String? ?? json['safe_address'] as String? ?? '',
      guardAddress: json['guardAddress'] as String? ?? json['guard_address'] as String? ?? '',
      chainId: json['chainId'] as int? ?? json['chain_id'] as int? ?? 84532,
      status: json['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'agentAddress': agentAddress,
        'name': name,
        'purpose': purpose,
        'safeAddress': safeAddress,
        'guardAddress': guardAddress,
        'chainId': chainId,
        'status': status,
      };

  @override
  List<Object?> get props => [
        id,
        userId,
        agentAddress,
        name,
        purpose,
        safeAddress,
        guardAddress,
        chainId,
        status,
      ];
}
