import 'package:butterscope_sample/src/activity/activity_screen.dart';
import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

const source = ActivitySource(counters: 4);

/// The four counters' values as shown.
List<int> shownCounts(WidgetTester tester) => [
  for (var id = 0; id < 4; id++)
    int.parse(tester.widget<Text>(find.byKey(Key('count-$id'))).data!),
];

Future<void> showActivity(WidgetTester tester) {
  return tester.pumpWidget(
    inApp(ActivityScreen(catalogue: smallCatalogue, source: source)),
  );
}

void main() {
  testWidgets('starts every counter at zero', (tester) async {
    await showActivity(tester);

    expect(shownCounts(tester), [0, 0, 0, 0]);
  });

  testWidgets('each batch adds three bumps of 1 to 5 saves', (tester) async {
    await showActivity(tester);

    await tester.pump(source.period);

    // Three bumps of 1 to 5 each add 3 to 15 saves in all.
    final total = shownCounts(tester).reduce((a, b) => a + b);
    expect(total, inInclusiveRange(3, 15));
  });

  testWidgets('every visit sees the same numbers', (tester) async {
    await showActivity(tester);
    await tester.pump(source.period * 5);
    final first = shownCounts(tester);

    await tester.pumpWidget(const SizedBox());
    await showActivity(tester);
    await tester.pump(source.period * 5);

    expect(shownCounts(tester), first);
  });
}
