import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/view/dashboard_screen.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Home with an agent, a pending Ledger approval and 5 actions', (tester) async {
    final authCubit = AuthCubit(authService: AuthService(apiClient: ApiClient(baseUrl: 'http://localhost')))
      ..emit(AuthState(
        status: AuthStatus.authenticated,
        user: const UserIdentity(
          id: 'user_1',
          email: 'operator@chapter2.finance',
          walletAddress: '0xC97d5648B82Cc733D566d252bF33759b4B040c75',
        ),
        agents: [kFixtureAgent],
      ));

    final dashboardCubit = DashboardCubit(apiService: GoldenChapter2ApiService(actions: buildFixtureActions()));
    await dashboardCubit.loadDashboardMetrics();

    final x402Cubit = X402ApprovalsCubit(
      apiService: GoldenX402ApprovalsApiService(pending: [buildFixturePendingApproval()]),
      ledgerBleClient: GoldenLedgerBleClient(GoldenLedgerEthereumSigner(address: kFixtureApproverAddress)),
    );
    await x402Cubit.refreshPendingApprovals();

    await pumpGolden(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<X402ApprovalsCubit>.value(value: x402Cubit),
        ],
        child: const Scaffold(body: DashboardScreen()),
      ),
    );

    await expectLater(find.byType(DashboardScreen), matchesGoldenFile('goldens/home_with_data.png'));

    await authCubit.close();
    await dashboardCubit.close();
    await x402Cubit.close();
  });

  testWidgets('Home with no agent bound and no activity yet', (tester) async {
    final authCubit = AuthCubit(authService: AuthService(apiClient: ApiClient(baseUrl: 'http://localhost')))
      ..emit(const AuthState(
        status: AuthStatus.authenticated,
        user: UserIdentity(id: 'user_2', email: 'new.operator@chapter2.finance'),
        agents: [],
      ));

    final dashboardCubit = DashboardCubit(apiService: GoldenChapter2ApiService(actions: const []));
    await dashboardCubit.loadDashboardMetrics();

    final x402Cubit = X402ApprovalsCubit(
      apiService: GoldenX402ApprovalsApiService(pending: const []),
      ledgerBleClient: GoldenLedgerBleClient(GoldenLedgerEthereumSigner(address: kFixtureApproverAddress)),
    );
    await x402Cubit.refreshPendingApprovals();

    await pumpGolden(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<X402ApprovalsCubit>.value(value: x402Cubit),
        ],
        child: const Scaffold(body: DashboardScreen()),
      ),
    );

    await expectLater(find.byType(DashboardScreen), matchesGoldenFile('goldens/home_empty.png'));

    await authCubit.close();
    await dashboardCubit.close();
    await x402Cubit.close();
  });
}
