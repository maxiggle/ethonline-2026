import 'package:chapter2/features/services/view/purchase_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Purchase detail shows the transaction hash and the weather response once PAID', (tester) async {
    final purchase = buildFixturePurchaseRequestPaid();
    final apiService = GoldenServicesApiService(purchaseRequestById: purchase);

    await pumpGolden(
      tester,
      PurchaseDetailScreen(
        purchaseRequestId: purchase.id,
        initialPurchase: purchase,
        apiService: apiService,
      ),
    );

    await expectLater(find.byType(PurchaseDetailScreen), matchesGoldenFile('goldens/purchase_paid.png'));

    // PAID is terminal, so the detail screen's own polling should already
    // have stopped; unmount anyway so no timer is ever left pending.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
