import 'package:flutter_test/flutter_test.dart';
import 'package:chapter2/app/app.dart';
import 'package:chapter2/core/di/locator.dart';

void main() {
  setUp(() {
    setupServiceLocator();
  });

  testWidgets('Chapter2App smoke test renders navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const Chapter2App());
    await tester.pumpAndSettle();

    expect(find.text('CHAPTER 2 GUARDIAN'), findsOneWidget);
    expect(find.text('Command Center Dashboard'), findsOneWidget);
  });
}
