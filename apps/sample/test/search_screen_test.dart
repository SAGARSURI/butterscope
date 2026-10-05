import 'package:butterscope_sample/src/search/search_screen.dart';
import 'package:butterscope_sample/src/widgets/item_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/items.dart';

void main() {
  testWidgets('shows nothing before a query', (tester) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));

    expect(find.byType(ItemTile), findsNothing);
    expect(find.text('0 results'), findsNothing);
  });

  testWidgets('lists the matches and their count as the user types', (
    tester,
  ) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));

    await tester.enterText(find.byKey(const Key('search-field')), 'lantern');
    await tester.pump();

    // Items 0 and 2 have "Lantern" in their titles.
    expect(find.text('2 results'), findsOneWidget);
    expect(find.byKey(const Key('item-tile-0')), findsOneWidget);
    expect(find.byKey(const Key('item-tile-2')), findsOneWidget);
  });

  testWidgets('tapping a result opens its detail page', (tester) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));
    await tester.enterText(find.byKey(const Key('search-field')), 'gift');
    await tester.pump();

    await tester.tap(find.byKey(const Key('item-tile-1')));
    await tester.pumpAndSettle();

    expect(find.text('Summary of Quiet Harbour No. 2.'), findsOneWidget);
  });
}
