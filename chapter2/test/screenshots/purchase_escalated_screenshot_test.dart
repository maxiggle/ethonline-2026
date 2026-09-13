import 'package:chapter2/features/services/view/purchase_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Purchase detail asks for a Ledger approval when ESCALATEd', (tester) async {
    final purchase = buildFixturePurchaseRequestEscalated();
    final apiService = GoldenServicesApiService(purchaseRequestById: purchase);

    await pumpGolden(
      tester,
      PurchaseDetailScreen(
        purchaseRequestId: purchase.id,
        initialPurchase: purchase,
        apiService: apiService,
      ),
    );

    await expectLater(find.byType(PurchaseDetailScreen), matchesGoldenFile('goldens/purchase_escalated.png'));

    // AUTHORIZED + ESCALATE is not terminal, so the detail screen's polling
    // timer is still pending. Unmount so dispose() cancels it before the
    // test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
