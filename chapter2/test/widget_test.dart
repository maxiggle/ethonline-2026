import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chapter2/app/app.dart';
import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:chapter2/features/dashboard/view/dashboard_screen.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/ledger/ledger_ble_client.dart';
import 'package:chapter2/features/x402_approvals/remote/x402_approvals_api_service.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:chapter2/shared/theme/chapter2_theme.dart';

void main() {
  setUp(() {
    setupServiceLocator();
  });

  testWidgets('Chapter2App initial boot renders SplashScreen then navigates to LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const Chapter2App());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('CHAPTER 2'), findsOneWidget);
    expect(find.text('Autonomous Treasury Supervision'), findsOneWidget);

    // Settle splash navigation timeout
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Sign In with Privy'), findsOneWidget);
  });

  testWidgets('DashboardScreen (Home) renders the agent card, Ledger card and activity feed', (WidgetTester tester) async {
    final authCubit = AuthCubit(authService: locator<AuthService>());
    authCubit.emit(const AuthState(
      status: AuthStatus.authenticated,
      user: UserIdentity(
        id: 'user_123',
        email: 'operator@chapter2.finance',
        walletAddress: '0x1234567890123456789012345678901234567890',
      ),
    ));

    final dashboardCubit = DashboardCubit(apiService: locator<Chapter2ApiService>());
    final x402Cubit = X402ApprovalsCubit(
      apiService: locator<X402ApprovalsApiService>(),
      ledgerBleClient: locator<LedgerBleClient>(),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<X402ApprovalsCubit>.value(value: x402Cubit),
        ],
        child: MaterialApp(
          theme: Chapter2Theme.darkTheme,
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapter 2'), findsOneWidget);
    expect(find.text('Your Agent'), findsOneWidget);
    expect(find.text('Ledger Approvals'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
  });
}
