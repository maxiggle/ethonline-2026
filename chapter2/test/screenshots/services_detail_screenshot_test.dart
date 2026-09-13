import 'package:chapter2/core/network/api_client.dart';
import 'package:chapter2/features/auth/cubit/auth_cubit.dart';
import 'package:chapter2/features/auth/cubit/auth_state.dart';
import 'package:chapter2/features/auth/services/auth_service.dart';
import 'package:chapter2/features/services/cubit/services_cubit.dart';
import 'package:chapter2/features/services/view/service_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Service detail sheet shows the city field, agent picker and price', (tester) async {
    final authCubit = AuthCubit(authService: AuthService(apiClient: ApiClient(baseUrl: 'http://localhost')))
      ..emit(AuthState(status: AuthStatus.authenticated, agents: [kFixtureAgent]));
    final servicesCubit = ServicesCubit(apiService: GoldenServicesApiService());

    await pumpGolden(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<ServicesCubit>.value(value: servicesCubit),
        ],
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showServiceDetailSheet(context, service: kFixtureWeatherService);
            });
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    await expectLater(
      find.byType(DraggableScrollableSheet),
      matchesGoldenFile('goldens/services_detail_weather.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await authCubit.close();
    await servicesCubit.close();
  });
}
