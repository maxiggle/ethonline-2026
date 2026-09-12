import 'package:equatable/equatable.dart';

class VerifySelfieRequest extends Equatable {
  const VerifySelfieRequest({
    required this.proof,
    required this.signerAddress,
  });

  final Map<String, dynamic> proof;
  final String signerAddress;

  Map<String, dynamic> toJson() => {
        'proof': proof,
        'signerAddress': signerAddress,
      };

  factory VerifySelfieRequest.fromJson(Map<String, dynamic> json) {
    return VerifySelfieRequest(
      proof: (json['proof'] as Map<String, dynamic>?) ?? {},
      signerAddress: (json['signerAddress'] ?? '') as String,
    );
  }

  @override
  List<Object?> get props => [proof, signerAddress];
}
