import 'package:butterscope_sample/src/feed/feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

void main() {
  testWidgets('shows a card for each item', (tester) async {
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    expect(find.byType(ItemCard), findsNWidgets(4));
    expect(find.text('Quiet Harbour No. 2'), findsOneWidget);
    expect(find.text('indoor · gift'), findsOneWidget);
  });

  testWidgets('cards grow to fit large text', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: inApp(FeedScreen(catalogue: smallCatalogue)),
      ),
    );

    // An overflowing card reports a layout error, which fails the test.
    expect(tester.takeException(), isNull);
    expect(find.text('Amber Lantern No. 1'), findsOneWidget);
  });

  testWidgets('a screen reader hears each title, not the picture', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    // The card reads as one label. The picture shows the title's initial,
    // "Q" for Quiet Harbour, which must not be read before the title.
    final card = tester.getSemantics(
      find.descendant(
        of: find.byKey(const Key('item-card-1')),
        matching: find.byType(InkWell),
      ),
    );
    expect(card.label, startsWith('Quiet Harbour No. 2\n'));
    semantics.dispose();
  });

  testWidgets('tapping a card opens its detail page', (tester) async {
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    await tester.tap(find.byKey(const Key('item-card-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.text('Summary of Cedar Lantern No. 3.'), findsOneWidget);
  });
}
