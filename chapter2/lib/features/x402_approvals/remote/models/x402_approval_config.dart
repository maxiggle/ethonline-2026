import 'package:equatable/equatable.dart';

/// `GET /x402/approvals/config` response: the Ledger address the backend
/// will accept approval/rejection signatures from, plus the network and
/// USDC contract the escalated payments settle on.
class X402ApprovalConfig extends Equatable {
  const X402ApprovalConfig({
    required this.approverAddress,
    required this.network,
    required this.usdcAddress,
  });

  final String approverAddress;
  final String network;
  final String usdcAddress;

  factory X402ApprovalConfig.fromJson(Map<String, dynamic> json) {
    return X402ApprovalConfig(
      approverAddress: json['approverAddress'] as String,
      network: json['network'] as String,
      usdcAddress: json['usdcAddress'] as String,
    );
  }

  @override
  List<Object?> get props => [approverAddress, network, usdcAddress];
}
