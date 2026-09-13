import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/onboarding/view/onboarding_screen.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/services/api/chapter2_api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  setUp(() async {
    await locator.reset();
    locator.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: 'http://localhost'));
    locator.registerLazySingleton<Chapter2ApiService>(() => GoldenChapter2ApiService());
    locator.registerLazySingleton<AuthService>(() => AuthService(apiClient: locator<ApiClient>()));
  });

  Future<void> pumpOnboardingStep(WidgetTester tester, int step) async {
    final authCubit = AuthCubit(authService: locator<AuthService>());
    final x402Cubit = X402ApprovalsCubit(
      apiService: GoldenX402ApprovalsApiService(),
      ledgerBleClient: GoldenLedgerBleClient(GoldenLedgerEthereumSigner(address: kFixtureApproverAddress)),
    );

    await pumpGolden(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<X402ApprovalsCubit>.value(value: x402Cubit),
        ],
        child: OnboardingScreen(initialStep: step),
      ),
    );
  }

  testWidgets('Onboarding step 1: welcome', (tester) async {
    await pumpOnboardingStep(tester, 0);
    await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('goldens/onboarding_step1_welcome.png'));
  });

  testWidgets('Onboarding step 2: bind agent with real Safe/Guard addresses', (tester) async {
    await pumpOnboardingStep(tester, 1);
    await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('goldens/onboarding_step2_bind_agent.png'));
  });

  testWidgets('Onboarding step 3: connect Ledger approver', (tester) async {
    await pumpOnboardingStep(tester, 2);
    await expectLater(find.byType(OnboardingScreen), matchesGoldenFile('goldens/onboarding_step3_connect_ledger.png'));
  });

  testWidgets('Onboarding step 2: an approver without an agent can skip to connecting the Ledger', (tester) async {
    await pumpOnboardingStep(tester, 1);

    final skipButton = find.text("Skip, I'm only approving");
    await tester.ensureVisible(skipButton);
    await tester.tap(skipButton);
    await tester.pumpAndSettle();

    expect(find.text('STEP 3 OF 3 · Connect Ledger'), findsOneWidget);
    expect(find.text('Connect your Ledger approver'), findsOneWidget);
  });
}
