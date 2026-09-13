import 'package:chapter2/shared/theme/chapter2_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPhone 12/13/14-class viewport the ticket asks screenshots to use:
/// 390x844 logical points at a device pixel ratio of 3.
const Size kGoldenLogicalSize = Size(390, 844);
const double kGoldenDevicePixelRatio = 3.0;

/// The app's real dark theme, with its text styles pinned to the 'Roboto'
/// family that [loadRealFontsForGoldens] registers, so goldens render actual
/// glyphs instead of the test binding's default tofu boxes.
ThemeData buildGoldenTheme() {
  final base = Chapter2Theme.darkTheme;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
  );
}

/// Sets the test binding's window to the golden viewport and restores it
/// after the test completes.
void useGoldenViewport(WidgetTester tester) {
  tester.view.physicalSize = kGoldenLogicalSize * kGoldenDevicePixelRatio;
  tester.view.devicePixelRatio = kGoldenDevicePixelRatio;
  addTearDown(tester.view.reset);
}

/// Pumps [child] inside a themed, correctly-sized [MaterialApp] and settles
/// it, ready for `expect(find.byType(...), matchesGoldenFile(...))`.
Future<void> pumpGolden(WidgetTester tester, Widget child) async {
  useGoldenViewport(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGoldenTheme(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}
