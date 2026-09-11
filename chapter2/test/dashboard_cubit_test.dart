import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';

class MockChapter2ApiService extends Chapter2ApiService {
  @override
  Future<List<Map<String, dynamic>>> fetchActions() async {
    return [
      {'actionId': '1', 'status': 'PENDING'},
      {'actionId': '2', 'status': 'REJECTED'},
    ];
  }
}

void main() {
  group('DashboardCubit Tests', () {
    test('initial state is correct', () {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      expect(cubit.state.status, DashboardStatus.initial);
      expect(cubit.state.metrics, isNull);
    });

    test('loadDashboardMetrics emits success with calculated pending and blocked counts', () async {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      await cubit.loadDashboardMetrics();

      expect(cubit.state.status, DashboardStatus.success);
      expect(cubit.state.metrics?.pendingEscalationsCount, 1);
      expect(cubit.state.metrics?.blockedAttacksCount, 1);
      expect(cubit.state.metrics?.totalTreasuryBalanceUsdc, 150000.0);
    });
  });
}
