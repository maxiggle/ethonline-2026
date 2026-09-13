import 'package:equatable/equatable.dart';

enum WorldIdOrbVerificationStatus {
  waitingForWorldApp('WAITING_FOR_WORLD_APP'),
  awaitingConfirmation('AWAITING_CONFIRMATION'),
  verified('VERIFIED'),
  bound('BOUND'),
  failed('FAILED'),
  expired('EXPIRED');

  const WorldIdOrbVerificationStatus(this.value);
  final String value;

  static WorldIdOrbVerificationStatus fromString(String raw) {
    for (final status in values) {
      if (status.value == raw) return status;
    }
    throw FormatException('Unknown WorldIdOrbVerificationStatus: "$raw"');
  }
}

class WorldIdOrbVerification extends Equatable {
  const WorldIdOrbVerification({
    required this.requestId,
    required this.status,
    this.connectorUrl,
    required this.expiresAt,
    this.bindMessage,
    this.errorMessage,
  });

  final String requestId;
  final WorldIdOrbVerificationStatus status;
  final String? connectorUrl;
  final DateTime expiresAt;
  final String? bindMessage;
  final String? errorMessage;

  factory WorldIdOrbVerification.fromJson(Map<String, dynamic> json) {
    return WorldIdOrbVerification(
      requestId: json['requestId'] as String,
      status: WorldIdOrbVerificationStatus.fromString(json['status'] as String),
      connectorUrl: json['connectorUrl'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      bindMessage: json['bindMessage'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        requestId,
        status,
        connectorUrl,
        expiresAt,
        bindMessage,
        errorMessage,
      ];
}
