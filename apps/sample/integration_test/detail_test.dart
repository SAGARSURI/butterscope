import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

/// Opens the first item in the feed.
Future<void> openFirstItem(WidgetTester tester) async {
  await launchApp(tester);
  await tester.tap(find.byKey(const Key('item-card-0')));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Detail', () {
    testWidgets('shows the item and its facts', (tester) async {
      await openFirstItem(tester);

      expect(find.byKey(const Key('detail-title')), findsOneWidget);
      expect(find.textContaining('Rated '), findsOneWidget);
      expect(find.textContaining('Saved by '), findsOneWidget);
    });

    testWidgets('scrolls to related items and opens one', (tester) async {
      await openFirstItem(tester);
      final scroll = find.byKey(const Key('detail-scroll'));

      await tester.scrollUntilVisible(
        find.byKey(const Key('detail-end')),
        300,
        scrollable: find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        ),
      );
      final related = find.descendant(
        of: scroll,
        matching: find.byType(ListTile),
      );
      expect(related, findsWidgets);
      await tester.tap(related.last);
      await tester.pumpAndSettle();

      // A second detail page is on top of the first.
      expect(find.byKey(const Key('detail-title')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('feed-list')), findsOneWidget);
    });
  });
}
