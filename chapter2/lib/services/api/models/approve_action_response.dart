import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:equatable/equatable.dart';

class ApproveActionResponse extends Equatable {
  const ApproveActionResponse({
    required this.action,
    required this.encodedPayload,
    required this.signer,
    this.txHash,
  });

  final TreasuryAction action;
  final String encodedPayload;
  final String signer;
  final String? txHash;

  factory ApproveActionResponse.fromJson(Map<String, dynamic> json) {
    final actionData = json['action'] is Map<String, dynamic>
        ? json['action'] as Map<String, dynamic>
        : json;

    return ApproveActionResponse(
      action: TreasuryAction.fromJson(actionData),
      encodedPayload: (json['encodedPayload'] ?? '') as String,
      signer: (json['signer'] ?? '') as String,
      txHash: json['txHash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action.toJson(),
      'encodedPayload': encodedPayload,
      'signer': signer,
      if (txHash != null) 'txHash': txHash,
    };
  }

  @override
  List<Object?> get props => [action, encodedPayload, signer, txHash];
}
