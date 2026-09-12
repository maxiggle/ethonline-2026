import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_state.dart';
import 'package:chapter2/features/mandate/models/treasury_mandate.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';

class MockChapter2ApiService extends Chapter2ApiService {
  @override
  Future<TreasuryMandate> fetchMandate() async {
    return const TreasuryMandate(
      safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
      guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
      maxAutonomousAmountUsdc: 100.0,
      dailyAutonomousLimitUsdc: 500.0,
      currentDailySpentUsdc: 0.0,
      approvedRecipients: [],
      approvedTokens: [],
    );
  }

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

void main() {
  group('DashboardCubit Tests', () {
    test('initial state is correct', () {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      expect(cubit.state.status, DashboardStatus.initial);
      expect(cubit.state.metrics, isNull);
    });

    test('loadDashboardMetrics emits success with calculated pending and blocked counts from mandate', () async {
      final cubit = DashboardCubit(apiService: MockChapter2ApiService());
      await cubit.loadDashboardMetrics();

      expect(cubit.state.status, DashboardStatus.success);
      expect(cubit.state.metrics?.pendingEscalationsCount, 1);
      expect(cubit.state.metrics?.blockedAttacksCount, 1);
      expect(cubit.state.metrics?.totalTreasuryBalanceUsdc, 10.0);
      expect(cubit.state.metrics?.dailyAutonomousCapUsdc, 500.0);
      expect(cubit.state.metrics?.singleAutonomousCapUsdc, 100.0);
    });
  });
}
