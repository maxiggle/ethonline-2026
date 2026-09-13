import 'package:chapter2/core/di/locator.dart';
import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/models/user_identity.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/settings/view/settings_screen.dart';
import 'package:chapter2/features/world_id/remote/world_id_api_service.dart';
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
    locator.registerLazySingleton<Chapter2ApiService>(
      () => GoldenChapter2ApiService(),
    );
    locator.registerLazySingleton<WorldIdApiService>(
      () => GoldenWorldIdApiService(),
    );
  });

  testWidgets('Settings shows account, backend and World ID sections with real data', (tester) async {
    final authCubit = AuthCubit(authService: AuthService(apiClient: ApiClient(baseUrl: 'http://localhost')))
      ..emit(const AuthState(
        status: AuthStatus.authenticated,
        user: UserIdentity(
          id: 'user_1',
          email: 'operator@chapter2.finance',
          name: 'Chapter 2 Operator',
          walletAddress: '0xC97d5648B82Cc733D566d252bF33759b4B040c75',
        ),
      ));

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
        child: const SettingsScreen(),
      ),
    );

    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/settings.png'));

    await authCubit.close();
    await x402Cubit.close();
  });
}
