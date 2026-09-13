import 'package:chapter2/features/world_id/cubit/world_id_approver_cubit.dart';
import 'package:chapter2/features/x402_approvals/cubit/x402_approvals_cubit.dart';
import 'package:chapter2/features/x402_approvals/view/x402_approvals_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Approvals tab with a pending escalation and a connected, matching Ledger', (tester) async {
    final signer = GoldenLedgerEthereumSigner(address: kFixtureApproverAddress);
    final cubit = X402ApprovalsCubit(
      apiService: GoldenX402ApprovalsApiService(pending: [buildFixturePendingApproval()]),
      ledgerBleClient: GoldenLedgerBleClient(signer),
    );
    final worldIdCubit = WorldIdApproverCubit(apiService: GoldenWorldIdApiService());
    await worldIdCubit.loadStatus();
    await cubit.loadConfig();
    await cubit.connectLedger(goldenLedgerDevice);
    await cubit.refreshPendingApprovals();

    await pumpGolden(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<X402ApprovalsCubit>.value(value: cubit),
          BlocProvider<WorldIdApproverCubit>.value(value: worldIdCubit),
        ],
        child: const X402ApprovalsScreen(),
      ),
    );

    await expectLater(
      find.byType(X402ApprovalsScreen),
      matchesGoldenFile('goldens/approvals_connected_pending.png'),
    );

    await cubit.close();
    await worldIdCubit.close();
  });
}
