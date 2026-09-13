import 'package:equatable/equatable.dart';

class WorldIdApproverStatus extends Equatable {
  const WorldIdApproverStatus({
    required this.approverAddress,
    required this.isWorldIdRequired,
    required this.isWorldIdConfigured,
    this.environment,
    required this.isVerified,
    this.credential,
    this.boundAt,
    this.expiresAt,
  });

  final String approverAddress;
  final bool isWorldIdRequired;
  final bool isWorldIdConfigured;
  final String? environment;
  final bool isVerified;
  final String? credential;
  final DateTime? boundAt;
  final DateTime? expiresAt;

  factory WorldIdApproverStatus.fromJson(Map<String, dynamic> json) {
    return WorldIdApproverStatus(
      approverAddress: json['approverAddress'] as String,
      isWorldIdRequired: json['isWorldIdRequired'] as bool,
      isWorldIdConfigured: json['isWorldIdConfigured'] as bool,
      environment: json['environment'] as String?,
      isVerified: json['isVerified'] as bool,
      credential: json['credential'] as String?,
      boundAt: json['boundAt'] != null ? DateTime.parse(json['boundAt'] as String) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [
        approverAddress,
        isWorldIdRequired,
        isWorldIdConfigured,
        environment,
        isVerified,
        credential,
        boundAt,
        expiresAt,
      ];
}
