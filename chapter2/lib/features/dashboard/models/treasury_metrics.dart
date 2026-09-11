import 'package:equatable/equatable.dart';

class TreasuryMetrics extends Equatable {
  const TreasuryMetrics({
    required this.totalTreasuryBalanceUsdc,
    required this.activeAutonomousAgentsCount,
    required this.todaySpentUsdc,
    required this.dailyAutonomousCapUsdc,
    required this.singleAutonomousCapUsdc,
    required this.pendingEscalationsCount,
    required this.blockedAttacksCount,
  });

  final double totalTreasuryBalanceUsdc;
  final int activeAutonomousAgentsCount;
  final double todaySpentUsdc;
  final double dailyAutonomousCapUsdc;
  final double singleAutonomousCapUsdc;
  final int pendingEscalationsCount;
  final int blockedAttacksCount;

  double get dailyBudgetBurnPercentage => dailyAutonomousCapUsdc > 0
      ? (todaySpentUsdc / dailyAutonomousCapUsdc).clamp(0.0, 1.0)
      : 0.0;

  @override
  List<Object?> get props => [
        totalTreasuryBalanceUsdc,
        activeAutonomousAgentsCount,
        todaySpentUsdc,
        dailyAutonomousCapUsdc,
        singleAutonomousCapUsdc,
        pendingEscalationsCount,
        blockedAttacksCount,
      ];
}
