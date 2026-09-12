import 'package:equatable/equatable.dart';

class TreasuryMandate extends Equatable {
  const TreasuryMandate({
    required this.maxAutonomousAmountUsdc,
    required this.dailyAutonomousLimitUsdc,
    required this.currentDailySpentUsdc,
    required this.approvedRecipients,
    required this.approvedTokens,
    required this.safeAddress,
    required this.guardAddress,
    this.autonomousAgent = '',
    this.totalTreasuryBalanceUsdc = 10.0,
    this.treasuryEthBalance = '0.001',
  });

  final double maxAutonomousAmountUsdc;
  final double dailyAutonomousLimitUsdc;
  final double currentDailySpentUsdc;
  final List<String> approvedRecipients;
  final List<String> approvedTokens;
  final String safeAddress;
  final String guardAddress;
  final String autonomousAgent;
  final double totalTreasuryBalanceUsdc;
  final String treasuryEthBalance;

  double get remainingDailyBudgetUsdc =>
      (dailyAutonomousLimitUsdc - currentDailySpentUsdc).clamp(0.0, dailyAutonomousLimitUsdc);

  bool isRecipientApproved(String address) {
    return approvedRecipients.any((r) => r.toLowerCase() == address.toLowerCase());
  }

  factory TreasuryMandate.fromJson(Map<String, dynamic> json) {
    return TreasuryMandate(
      maxAutonomousAmountUsdc: (json['maxAutonomousAmountUsdc'] as num?)?.toDouble() ?? 100.0,
      dailyAutonomousLimitUsdc: (json['dailyAutonomousLimitUsdc'] as num?)?.toDouble() ?? 500.0,
      currentDailySpentUsdc: (json['currentDailySpentUsdc'] as num?)?.toDouble() ?? 0.0,
      totalTreasuryBalanceUsdc: (json['totalTreasuryBalanceUsdc'] as num?)?.toDouble() ?? 10.0,
      treasuryEthBalance: (json['treasuryEthBalance'] ?? '0.001').toString(),
      approvedRecipients: (json['approvedRecipients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      approvedTokens: (json['approvedTokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      safeAddress: (json['safeAddress'] ?? '') as String,
      guardAddress: (json['guardAddress'] ?? '') as String,
      autonomousAgent: (json['autonomousAgent'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxAutonomousAmountUsdc': maxAutonomousAmountUsdc,
      'dailyAutonomousLimitUsdc': dailyAutonomousLimitUsdc,
      'currentDailySpentUsdc': currentDailySpentUsdc,
      'approvedRecipients': approvedRecipients,
      'approvedTokens': approvedTokens,
      'safeAddress': safeAddress,
      'guardAddress': guardAddress,
      'autonomousAgent': autonomousAgent,
    };
  }

  @override
  List<Object?> get props => [
        maxAutonomousAmountUsdc,
        dailyAutonomousLimitUsdc,
        currentDailySpentUsdc,
        approvedRecipients,
        approvedTokens,
        safeAddress,
        guardAddress,
      ];
}
