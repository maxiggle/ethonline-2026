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

  testWidgets('Searching "weather" filters the catalog to a single result', (tester) async {
    final cubit = ServicesCubit(apiService: GoldenServicesApiService());
    await cubit.loadCatalogOnce();
    cubit.updateSearchQuery('weather');

    await pumpGolden(
      tester,
      BlocProvider<ServicesCubit>.value(
        value: cubit,
        child: const Scaffold(body: ServicesScreen()),
      ),
    );

    await expectLater(find.byType(ServicesScreen), matchesGoldenFile('goldens/services_search_weather.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
}
