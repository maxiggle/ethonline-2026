import 'package:chapter2/features/dashboard/models/treasury_metrics.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:equatable/equatable.dart';

enum DashboardStatus { initial, loading, success, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.metrics,
    this.recentActions = const [],
    this.isSubmittingScenario = false,
    this.lastScenarioNotice,
    this.pendingEscalationAction,
    this.errorMessage,
  });

  final DashboardStatus status;
  final TreasuryMetrics? metrics;
  final List<TreasuryAction> recentActions;
  final bool isSubmittingScenario;
  final String? lastScenarioNotice;
  final TreasuryAction? pendingEscalationAction;
  final String? errorMessage;

  DashboardState copyWith({
    DashboardStatus? status,
    TreasuryMetrics? metrics,
    List<TreasuryAction>? recentActions,
    bool? isSubmittingScenario,
    String? lastScenarioNotice,
    TreasuryAction? pendingEscalationAction,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
      recentActions: recentActions ?? this.recentActions,
      isSubmittingScenario: isSubmittingScenario ?? this.isSubmittingScenario,
      lastScenarioNotice: lastScenarioNotice ?? this.lastScenarioNotice,
      pendingEscalationAction: pendingEscalationAction,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        metrics,
        recentActions,
        isSubmittingScenario,
        lastScenarioNotice,
        pendingEscalationAction,
        errorMessage,
      ];
}
