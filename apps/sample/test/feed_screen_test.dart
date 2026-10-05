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

  testWidgets('tapping a card opens its detail page', (tester) async {
    await tester.pumpWidget(inApp(FeedScreen(catalogue: smallCatalogue)));

    await tester.tap(find.byKey(const Key('item-card-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-title')), findsOneWidget);
    expect(find.text('Summary of Cedar Lantern No. 3.'), findsOneWidget);
  });
}
