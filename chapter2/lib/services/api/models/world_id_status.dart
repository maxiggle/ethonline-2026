import 'package:equatable/equatable.dart';

/// `GET /world/selfie/status/:signerAddress` response.
class WorldIdStatus extends Equatable {
  const WorldIdStatus({required this.signerAddress, required this.isVerified});

  final String signerAddress;
  final bool isVerified;

  factory WorldIdStatus.fromJson(Map<String, dynamic> json) {
    return WorldIdStatus(
      signerAddress: (json['signerAddress'] ?? '') as String,
      isVerified: json['isVerified'] == true,
    );
  }

  @override
  List<Object?> get props => [signerAddress, isVerified];
}
