import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

/// The sum of the counters on screen.
int shownTotal(WidgetTester tester) {
  final counts = tester.widgetList<Text>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('count-'),
    ),
  );
  return counts.fold(0, (sum, text) => sum + int.parse(text.data!));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();

  group('Activity', () {
    testWidgets('counters climb while the screen is open', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Activity');
      final before = shownTotal(tester);

      // The feed sends a batch every 100 ms, so a second brings several.
      await span('activity counters', () async {
        await tester.pump(const Duration(seconds: 1));
      });

      expect(shownTotal(tester), greaterThan(before));
    });

    testWidgets('scrolls to the last counter', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Activity');

      await tester.drag(
        find.byKey(const Key('activity-list')),
        const Offset(0, -3000),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('counter-39')), findsOneWidget);
    });
  });
}
