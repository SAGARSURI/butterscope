import 'package:butterscope_sample/src/catalogue/catalogue.dart';
import 'package:butterscope_sample/src/catalogue/item.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
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

  testWidgets('finds items by tag, ignoring case', (tester) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));

    await tester.enterText(find.byKey(const Key('search-field')), 'OUTDOOR');
    await tester.pump();

    // Items 0, 2 and 3 are tagged "outdoor"; no title contains the word.
    expect(find.text('3 results'), findsOneWidget);
  });

  testWidgets('finds a capitalised tag from a lower-case query', (
    tester,
  ) async {
    final catalogue = Catalogue([
      item(0, 'Brisk Atlas No. 1', ['Garden', 'gift']),
    ]);
    await tester.pumpWidget(inApp(SearchScreen(catalogue: catalogue)));

    await tester.enterText(find.byKey(const Key('search-field')), 'garden');
    await tester.pump();

    expect(find.text('1 results'), findsOneWidget);
  });

  testWidgets('clearing the field clears the results', (tester) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));
    final field = find.byKey(const Key('search-field'));
    await tester.enterText(field, 'lantern');
    await tester.pump();

    await tester.enterText(field, '   ');
    await tester.pump();

    expect(find.byType(ItemTile), findsNothing);
    expect(find.byKey(const Key('search-count')), findsOneWidget);
    expect(find.textContaining('results'), findsNothing);
  });

  testWidgets('tapping a result opens its detail page', (tester) async {
    await tester.pumpWidget(inApp(SearchScreen(catalogue: smallCatalogue)));
    await tester.enterText(find.byKey(const Key('search-field')), 'gift');
    await tester.pump();

    await tester.tap(find.byKey(const Key('item-tile-1')));
    await tester.pumpAndSettle();

    expect(find.text('Summary of Quiet Harbour No. 2.'), findsOneWidget);
  });

  group('ui_busy', () {
    /// The ids of the results, top to bottom.
    List<int> shownIds(WidgetTester tester) => [
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        int.parse((tile.key! as ValueKey<String>).value.split('-').last),
    ];

    Future<void> searchFor(
      WidgetTester tester,
      Catalogue catalogue,
      String query, {
      Plant plant = Plant.none,
    }) async {
      // A fresh screen, so a second search does not reuse the first.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        inApp(SearchScreen(catalogue: catalogue), plant: plant),
      );
      await tester.enterText(find.byKey(const Key('search-field')), query);
      await tester.pump();
    }

    testWidgets('finds the same items as the clean build', (tester) async {
      await searchFor(tester, smallCatalogue, 'outdoor');
      final clean = shownIds(tester)..sort();

      await searchFor(tester, smallCatalogue, 'outdoor', plant: Plant.uiBusy);

      expect(find.text('3 results'), findsOneWidget);
      expect(shownIds(tester)..sort(), clean);
    });

    testWidgets('scores an item that has no words', (tester) async {
      final catalogue = Catalogue([
        item(0, 'Brisk Lantern No. 1', ['gift', 'travel']),
        const Item(
          id: 1,
          title: '🎈',
          tags: ['🎁'],
          summary: '🎈',
          rating: 4.5,
          saves: 7,
        ),
      ]);

      await searchFor(tester, catalogue, 'lantern', plant: Plant.uiBusy);

      expect(tester.takeException(), isNull);
      expect(shownIds(tester), [0]);
    });

    testWidgets('lists the closest match first', (tester) async {
      final catalogue = Catalogue([
        item(0, 'Lanterns Kit No. 1', ['gift', 'travel']),
        item(1, 'Brisk Lantern No. 2', ['gift', 'travel']),
      ]);

      await searchFor(tester, catalogue, 'lantern');
      expect(shownIds(tester), [0, 1]);

      // "lanterns" is one letter from the query and "lantern" none.
      await searchFor(tester, catalogue, 'lantern', plant: Plant.uiBusy);
      expect(shownIds(tester), [1, 0]);
    });
  });
}
