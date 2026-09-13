import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/guardian_alert/view/guardian_analysis_sheet.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    setupServiceLocator();
  });

  testWidgets('ActivityTimelineScreen displays filter chips and empty state or actions', (tester) async {
    final dashboardCubit = DashboardCubit(apiService: locator<Chapter2ApiService>());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
        ],
        child: MaterialApp(
          theme: Chapter2Theme.darkTheme,
          home: const ActivityTimelineScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity & Verdict Feed'), findsOneWidget);
    expect(find.text('All Events'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Escalated'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
  });

  testWidgets('SettingsScreen displays account, backend and World ID sections', (tester) async {
    final authCubit = AuthCubit(authService: locator<AuthService>());
    authCubit.emit(const AuthState(
      status: AuthStatus.authenticated,
      user: UserIdentity(
        id: 'user_123',
        email: 'operator@chapter2.finance',
        walletAddress: '0xc97d5648b82cc733D566d252Bf33759B4b040c75',
      ),
    ));

    final x402Cubit = X402ApprovalsCubit(
      apiService: locator<X402ApprovalsApiService>(),
      ledgerBleClient: locator<LedgerBleClient>(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<X402ApprovalsCubit>.value(value: x402Cubit),
        ],
        child: MaterialApp(
          theme: Chapter2Theme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('World ID'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('GuardianAnalysisSheet displays tri-verdict evaluations correctly', (tester) async {
    final action = TreasuryAction(
      actionId: 'action_1',
      agentAddress: '0x1111111111111111111111111111111111111111',
      recipientAddress: '0x2222222222222222222222222222222222222222',
      tokenAddress: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amountUnits: BigInt.from(50000000),
      amountDisplayUsdc: 50.0,
      status: TreasuryActionStatus.executed,
      riskScore: 10,
      purpose: 'Google Cloud Vertex AI API Credits',
      timestamp: DateTime.now(),
      txHash: '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: Chapter2Theme.darkTheme,
        home: Scaffold(
          body: GuardianAnalysisSheet(action: action),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardian Risk Analysis'), findsOneWidget);
    expect(find.text('ALLOW — Autonomous Execution'), findsOneWidget);
    expect(find.text('Google Cloud Vertex AI API Credits'), findsOneWidget);
    expect(find.text('\$50.00 USDC'), findsOneWidget);
    expect(find.text('Guardian Mandate & Policy Checks'), findsOneWidget);
  });
}
