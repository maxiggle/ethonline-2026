import 'package:equatable/equatable.dart';

class SubmitApprovalRequest extends Equatable {
  const SubmitApprovalRequest({
    required this.actionId,
    required this.signature,
    required this.signer,
    this.biometricVerified = false,
  });

  final String actionId;
  final String signature;
  final String signer;
  final bool biometricVerified;

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'signature': signature,
      'signer': signer,
      'biometricVerified': biometricVerified,
    };
  }

  factory SubmitApprovalRequest.fromJson(Map<String, dynamic> json) {
    return SubmitApprovalRequest(
      actionId: (json['actionId'] ?? '') as String,
      signature: (json['signature'] ?? '') as String,
      signer: (json['signer'] ?? '') as String,
      biometricVerified: json['biometricVerified'] == true,
    );
  }

  @override
  List<Object?> get props => [actionId, signature, signer, biometricVerified];
}
