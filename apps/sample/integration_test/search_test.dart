import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';
import 'support/screen_tour.dart' show keystroke;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();

  group('Search', () {
    testWidgets('finds items by tag and shows how many', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Search');

      const query = 'garden';
      final field = find.byKey(const Key('search-field'));
      await span('search typing', () async {
        // A letter at a time, as a person types, so every keystroke
        // searches.
        for (var length = 1; length <= query.length; length++) {
          await tester.enterText(field, query.substring(0, length));
          await tester.pump(keystroke);
        }
        await tester.pumpAndSettle();
      });

      final count = tester.widget<Text>(find.byKey(const Key('search-count')));
      expect(count.data, matches(RegExp(r'^[1-9]\d* results$')));
      expect(find.textContaining(query), findsWidgets);
    });

    testWidgets('a word that matches nothing shows no results', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Search');

      await tester.enterText(find.byKey(const Key('search-field')), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('0 results'), findsOneWidget);
    });

    testWidgets('opens a result and comes back to the list', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Search');
      await tester.enterText(find.byKey(const Key('search-field')), 'lantern');
      await tester.pumpAndSettle();

      final results = find.descendant(
        of: find.byKey(const Key('search-results')),
        matching: find.byType(ListTile),
      );
      final title = tester
          .widget<Text>(
            find.descendant(
              of: results.first,
              matching: find.textContaining('Lantern'),
            ),
          )
          .data!;
      await tester.tap(results.first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail-title')), findsOneWidget);
      expect(find.text(title), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('search-field')), findsOneWidget);
    });
  });
}
