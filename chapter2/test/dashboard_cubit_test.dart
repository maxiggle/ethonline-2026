import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';

class MockChapter2ApiService extends Chapter2ApiService {
  @override
  Future<List<TreasuryAction>> fetchActions({TreasuryActionStatus? status}) async {
    return [
      TreasuryAction(
        actionId: '1',
        agentAddress: '0xAgent1',
        recipientAddress: '0xRecipient1',
        tokenAddress: '0xToken1',
        amountUnits: BigInt.from(100000000),
        amountDisplayUsdc: 100.0,
        status: TreasuryActionStatus.pending,
        riskScore: 20,
        purpose: 'Test pending',
        timestamp: DateTime.now(),
      ),
      TreasuryAction(
        actionId: '2',
        agentAddress: '0xAgent2',
        recipientAddress: '0xRecipient2',
        tokenAddress: '0xToken2',
        amountUnits: BigInt.from(5000000000),
        amountDisplayUsdc: 5000.0,
        status: TreasuryActionStatus.rejected,
        riskScore: 99,
        purpose: 'Test rejected',
        timestamp: DateTime.now(),
      ),
    ];
  }
}

class FailingChapter2ApiService extends Chapter2ApiService {
  @override
  Future<List<TreasuryAction>> fetchActions({TreasuryActionStatus? status}) async {
    throw Exception('network unavailable');
  }
}

void main() {
  group('DashboardCubit Tests', () {
    test('initial state is correct', () {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      expect(cubit.state.status, DashboardStatus.initial);
      expect(cubit.state.recentActions, isEmpty);
    });

    test('loadDashboardMetrics emits success with fetched actions', () async {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      await cubit.loadDashboardMetrics();

      expect(cubit.state.status, DashboardStatus.success);
      expect(cubit.state.recentActions.length, 2);
    });

    test('loadDashboardMetrics emits failure with the real error on API failure', () async {
      final cubit = DashboardCubit(apiService: FailingChapter2ApiService());
      await cubit.loadDashboardMetrics();

      expect(cubit.state.status, DashboardStatus.failure);
      expect(cubit.state.errorMessage, contains('network unavailable'));
    });
  });
}
