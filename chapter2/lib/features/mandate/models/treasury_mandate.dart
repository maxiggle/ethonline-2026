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
  });

  final double maxAutonomousAmountUsdc;
  final double dailyAutonomousLimitUsdc;
  final double currentDailySpentUsdc;
  final List<String> approvedRecipients;
  final List<String> approvedTokens;
  final String safeAddress;
  final String guardAddress;

  double get remainingDailyBudgetUsdc =>
      (dailyAutonomousLimitUsdc - currentDailySpentUsdc).clamp(0.0, dailyAutonomousLimitUsdc);

  bool isRecipientApproved(String address) {
    return approvedRecipients.any((r) => r.toLowerCase() == address.toLowerCase());
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
