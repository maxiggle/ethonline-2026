import 'package:chapter2/shared/enums/guardian_verdict.dart';
import 'package:equatable/equatable.dart';

class GuardianDecision extends Equatable {
  const GuardianDecision({
    required this.actionId,
    required this.verdict,
    required this.riskScore,
    required this.deterministicPass,
    required this.reason,
    required this.adversarialFactors,
    required this.timestamp,
  });

  final String actionId;
  final GuardianVerdict verdict;
  final int riskScore;
  final bool deterministicPass;
  final String reason;
  final List<String> adversarialFactors;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        actionId,
        verdict,
        riskScore,
        deterministicPass,
        reason,
        adversarialFactors,
        timestamp,
      ];
}
