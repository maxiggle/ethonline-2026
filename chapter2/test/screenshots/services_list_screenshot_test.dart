import 'package:chapter2/features/services/cubit/services_cubit.dart';
import 'package:chapter2/features/services/view/services_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Services tab lists the catalog with no search applied', (tester) async {
    final cubit = ServicesCubit(apiService: GoldenServicesApiService());
    await cubit.loadCatalogOnce();

    await pumpGolden(
      tester,
      BlocProvider<ServicesCubit>.value(
        value: cubit,
        child: const Scaffold(body: ServicesScreen()),
      ),
    );

    await expectLater(find.byType(ServicesScreen), matchesGoldenFile('goldens/services_list.png'));

    // Unmount before closing the cubit, so ServicesScreen.dispose() stops
    // the purchases-polling timer its initState started.
    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
}
