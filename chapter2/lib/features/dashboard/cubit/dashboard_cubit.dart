import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Loads the treasury action feed shown on Home and the Activity tab.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required Chapter2ApiService apiService})
      : _apiService = apiService,
        super(const DashboardState());

  final Chapter2ApiService _apiService;

  Future<void> loadDashboardMetrics() async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final actions = await _apiService.fetchActions();
      emit(state.copyWith(status: DashboardStatus.success, recentActions: actions));
    } catch (e) {
      emit(state.copyWith(status: DashboardStatus.failure, errorMessage: e.toString()));
    }
  }
}
