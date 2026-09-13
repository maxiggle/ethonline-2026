import 'package:chapter2/features/activity/view/activity_timeline_screen.dart';
import 'package:chapter2/features/dashboard/cubit/dashboard_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/golden_fakes.dart';
import 'support/golden_fonts.dart';
import 'support/golden_harness.dart';

void main() {
  setUpAll(loadRealFontsForGoldens);

  testWidgets('Activity timeline lists allow, escalate and block verdicts', (tester) async {
    final dashboardCubit = DashboardCubit(apiService: GoldenChapter2ApiService(actions: buildFixtureActions()));
    await dashboardCubit.loadDashboardMetrics();

    await pumpGolden(
      tester,
      BlocProvider<DashboardCubit>.value(
        value: dashboardCubit,
        child: const ActivityTimelineScreen(),
      ),
    );

    await expectLater(find.byType(ActivityTimelineScreen), matchesGoldenFile('goldens/activity.png'));

    await dashboardCubit.close();
  });
}
