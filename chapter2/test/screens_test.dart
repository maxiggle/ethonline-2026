import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/agents/view/agent_detail_screen.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/agent_model.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/guardian_alert/view/guardian_analysis_sheet.dart';
import 'package:chapter2/features/mandate/view/mandate_management_sheet.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/features/timeline/models/treasury_action.dart';
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

  testWidgets('AgentDetailScreen displays telemetry, kill switch, and protocols', (tester) async {
    final authCubit = AuthCubit(authService: locator<AuthService>());
    authCubit.emit(const AuthState(
      status: AuthStatus.authenticated,
      user: UserIdentity(
        id: 'user_123',
        email: 'operator@chapter2.finance',
        walletAddress: '0xc97d5648b82cc733D566d252Bf33759B4b040c75',
      ),
      agents: [
        AgentModel(
          id: 'agent_default_01',
          userId: 'user_123',
          agentAddress: '0x1111111111111111111111111111111111111111',
          name: 'Treasury Worker #1',
          safeAddress: '0x4f712dd78Cb1a504C69CB4f68B82Fddb6b3b1df6',
          guardAddress: '0x9b6023D1B6D3b076C8d999Ba406AE486750ce7d3',
        ),
      ],
    ));

    final dashboardCubit = DashboardCubit(apiService: locator<Chapter2ApiService>());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
        ],
        child: MaterialApp(
          theme: Chapter2Theme.darkTheme,
          home: const AgentDetailScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Supervised Agents & Mandates'), findsOneWidget);
    expect(find.text('Treasury Worker #1'), findsOneWidget);
    expect(find.text('Emergency Kill Switch'), findsOneWidget);
    expect(find.text("Today's Operational Telemetry"), findsOneWidget);
    expect(find.text('Authorized Interaction Protocols'), findsOneWidget);
    expect(find.text('Google Cloud Vertex AI'), findsOneWidget);
  });

  testWidgets('SettingsScreen displays identity, contracts, and World ID verification', (tester) async {
    final authCubit = AuthCubit(authService: locator<AuthService>());
    authCubit.emit(const AuthState(
      status: AuthStatus.authenticated,
      user: UserIdentity(
        id: 'user_123',
        email: 'operator@chapter2.finance',
        walletAddress: '0xc97d5648b82cc733D566d252Bf33759B4b040c75',
      ),
    ));

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
        ],
        child: MaterialApp(
          theme: Chapter2Theme.darkTheme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings & Infrastructure'), findsOneWidget);
    expect(find.text('Connected Identity'), findsOneWidget);
    expect(find.text('World ID Verification'), findsOneWidget);
    expect(find.text('Smart Contract Infrastructure'), findsOneWidget);
    expect(find.text('Ledger Hardware Signer'), findsOneWidget);
    expect(find.text('Disconnect Session & Sign Out'), findsOneWidget);
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
