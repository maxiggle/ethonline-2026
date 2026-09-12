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

  factory GuardianDecision.fromJson(Map<String, dynamic> json) {
    final verdictStr = (json['decision'] ?? json['verdict'] ?? 'BLOCK').toString();
    final verdict = verdictStr.toUpperCase() == 'ALLOW'
        ? GuardianVerdict.allow
        : (verdictStr.toUpperCase() == 'ESCALATE'
            ? GuardianVerdict.escalate
            : GuardianVerdict.block);

    final reasonsList = (json['reasons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final singleReason = json['reason']?.toString() ??
        (reasonsList.isNotEmpty ? reasonsList.first : '');

    return GuardianDecision(
      actionId: (json['actionId'] ?? '') as String,
      verdict: verdict,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      deterministicPass: json['deterministicPassed'] == true || json['deterministicPass'] == true,
      reason: singleReason,
      adversarialFactors: reasonsList,
      timestamp: json['evaluatedAt'] != null
          ? DateTime.tryParse(json['evaluatedAt'].toString()) ?? DateTime.now()
          : (json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'decision': verdict.label,
      'verdict': verdict.label,
      'riskScore': riskScore,
      'deterministicPassed': deterministicPass,
      'reason': reason,
      'reasons': adversarialFactors,
      'evaluatedAt': timestamp.toIso8601String(),
    };
  }

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
