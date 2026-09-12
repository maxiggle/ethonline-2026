import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/dashboard/models/treasury_metrics.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/services/api/models/propose_action_request.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required Chapter2ApiService apiService})
      : _apiService = apiService,
        super(const DashboardState());

  final Chapter2ApiService _apiService;

  Future<void> loadDashboardMetrics() async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final actions = await _apiService.fetchActions();
      final pendingCount = actions.where((a) => a.status == TreasuryActionStatus.pending).length;
      final blockedCount = actions.where((a) => a.status == TreasuryActionStatus.rejected).length;

      final metrics = TreasuryMetrics(
        totalTreasuryBalanceUsdc: 150000.0,
        activeAutonomousAgentsCount: 2,
        todaySpentUsdc: 140.0,
        dailyAutonomousCapUsdc: 500.0,
        singleAutonomousCapUsdc: 100.0,
        pendingEscalationsCount: pendingCount,
        blockedAttacksCount: blockedCount,
      );

      emit(state.copyWith(
        status: DashboardStatus.success,
        metrics: metrics,
        recentActions: actions,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Scenario 1: Propose $40 autonomous payment (evaluated as ALLOW, auto-executed).
  Future<void> triggerAutonomousAllowScenario() async {
    emit(state.copyWith(isSubmittingScenario: true));
    try {
      const request = ProposeActionRequest(
        target: '0x0000000000000000000000000000000000041c4e',
        value: '0',
        data: '0xa9059cbb',
        token: '0x0000000000000000000000000000000000041c4e',
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '40',
        agentAddress: '0x1111111111111111111111111111111111111111',
        justification: 'Alchemy RPC node infrastructure subscription',
      );

      final response = await _apiService.proposeAction(request);
      final updatedActions = [response.action, ...state.recentActions];

      final txInfo = response.action.txHash != null
          ? ' Tx: ${response.action.txHash}'
          : '';
      emit(state.copyWith(
        isSubmittingScenario: false,
        recentActions: updatedActions,
        lastScenarioNotice:
            'Autonomous Payment (\$40) ALLOWED & Executed on-chain!$txInfo',
      ));
      await loadDashboardMetrics();
    } catch (e) {
      emit(state.copyWith(
        isSubmittingScenario: false,
        errorMessage: 'Failed to propose autonomous payment: $e',
      ));
    }
  }

  /// Scenario 2: Propose $850 budget-exceeding payment (evaluated as ESCALATE, requires Face ID).
  Future<TreasuryAction?> triggerEscalateScenario() async {
    emit(state.copyWith(isSubmittingScenario: true));
    try {
      const request = ProposeActionRequest(
        target: '0x0000000000000000000000000000000000041c4e',
        value: '0',
        data: '0xa9059cbb',
        token: '0x0000000000000000000000000000000000041c4e',
        recipient: '0x0000000000000000000000000000000000041c4e',
        amount: '850',
        agentAddress: '0x1111111111111111111111111111111111111111',
        justification: 'Dedicated Cloud Security Cluster Annual Renewal',
      );

      final response = await _apiService.proposeAction(request);
      final updatedActions = [response.action, ...state.recentActions];

      emit(state.copyWith(
        isSubmittingScenario: false,
        recentActions: updatedActions,
        pendingEscalationAction: response.action,
        lastScenarioNotice:
            'Action #850 Exceeds Daily Limit (\$500). ESCALATED for Biometric Clear-Signing!',
      ));
      await loadDashboardMetrics();
      return response.action;
    } catch (e) {
      emit(state.copyWith(
        isSubmittingScenario: false,
        errorMessage: 'Failed to propose escalation: $e',
      ));
      return null;
    }
  }

  /// Scenario 3: Propose $5,000 transfer to untrusted recipient (evaluated as BLOCK).
  Future<void> triggerBlockThreatScenario() async {
    emit(state.copyWith(isSubmittingScenario: true));
    try {
      const request = ProposeActionRequest(
        target: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        value: '0',
        data: '0xa9059cbb',
        token: '0x0000000000000000000000000000000000041c4e',
        recipient: '0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef',
        amount: '5000',
        agentAddress: '0x1111111111111111111111111111111111111111',
        justification: 'Unauthorized fund transfer to unverified address',
      );

      final response = await _apiService.proposeAction(request);
      final updatedActions = [response.action, ...state.recentActions];

      emit(state.copyWith(
        isSubmittingScenario: false,
        recentActions: updatedActions,
        lastScenarioNotice:
            'Threat BLOCKED by AI Guardian! Transfer of \$5,000 was intercepted and prevented.',
      ));
      await loadDashboardMetrics();
    } catch (e) {
      emit(state.copyWith(
        isSubmittingScenario: false,
        errorMessage: 'Failed to simulate threat: $e',
      ));
    }
  }

  void clearNotice() {
    emit(state.copyWith(lastScenarioNotice: null));
  }

  void clearPendingEscalation() {
    emit(state.copyWith(pendingEscalationAction: null));
  }
}
