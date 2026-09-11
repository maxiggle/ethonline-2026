import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/dashboard/models/treasury_metrics.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
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
      final pendingCount = actions.where((a) => a['status'] == 'PENDING').length;
      final blockedCount = actions.where((a) => a['status'] == 'REJECTED').length;

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
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
