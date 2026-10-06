import 'package:butterscope_sample/src/activity/activity_screen.dart';
import 'package:butterscope_sample/src/activity/activity_source.dart';
import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/screen_plants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

const source = ActivitySource();

/// The four counters' values as shown.
List<int> shownCounts(WidgetTester tester) => [
  for (var id = 0; id < 4; id++)
    int.parse(tester.widget<Text>(find.byKey(Key('count-$id'))).data!),
];

Future<void> showActivity(WidgetTester tester, {Plant plant = Plant.none}) {
  return tester.pumpWidget(
    inApp(
      ActivityScreen(catalogue: smallCatalogue, source: source),
      plant: plant,
    ),
  );
}

void main() {
  testWidgets('shows a counter for each of the first 40 items', (tester) async {
    await tester.pumpWidget(
      inApp(
        ActivityScreen(catalogue: Catalogue.seeded(count: 50), source: source),
      ),
    );

    await tester.scrollUntilVisible(find.byKey(const Key('counter-39')), 300);

    expect(find.byKey(const Key('counter-39')), findsOneWidget);
    expect(find.byKey(const Key('counter-40')), findsNothing);
  });

  testWidgets('a catalogue under 40 items gets a counter per item', (
    tester,
  ) async {
    await showActivity(tester);
    await tester.pump(source.period * 5);

    // smallCatalogue holds four items, and every bump lands on one of them.
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty catalogue shows no counters', (tester) async {
    await tester.pumpWidget(
      inApp(ActivityScreen(catalogue: Catalogue([]), source: source)),
    );
    await tester.pump(source.period * 5);

    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

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

  group('rebuild_all', () {
    testWidgets('shows the same counts as the clean build', (tester) async {
      await showActivity(tester);
      await tester.pump(source.period * 5);
      final clean = shownCounts(tester);

      await tester.pumpWidget(const SizedBox());
      await showActivity(tester, plant: Plant.rebuildAll);
      await tester.pump(source.period * 5);

      expect(shownCounts(tester), clean);
    });

    testWidgets('builds every row at once, each with a segmented bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        inApp(
          ActivityScreen(
            catalogue: Catalogue.seeded(count: 50),
            source: source,
          ),
          plant: Plant.rebuildAll,
        ),
      );

      // Row 39 is far below the screen, yet built without scrolling.
      expect(find.byKey(const Key('counter-39')), findsOneWidget);
      expect(find.byType(SegmentedBar), findsNWidgets(40));
    });
  });
}
