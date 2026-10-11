import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();

  group('Feed', () {
    testWidgets('opens on the feed with the first items', (tester) async {
      await launchApp(tester);

      expect(find.text('Feed'), findsWidgets);
      expect(find.byKey(const Key('item-card-0')), findsOneWidget);
      expect(find.byKey(const Key('item-card-1')), findsOneWidget);
    });

    testWidgets('scrolls down to an item and opens it', (tester) async {
      await launchApp(tester);

      final card = find.byKey(const Key('item-card-39'));
      await span('feed scroll', () async {
        await tester.scrollUntilVisible(
          card,
          400,
          scrollable: find.descendant(
            of: find.byKey(const Key('feed-list')),
            matching: find.byType(Scrollable),
          ),
        );
      });
      // scrollUntilVisible ends with a jump that is laid out only in the
      // next frame; until then the card's tap point can sit under the
      // navigation bar, as it did on the iPhone with Larger Text.
      await tester.pumpAndSettle();
      final title = tester
          .widget<Text>(
            find.descendant(of: card, matching: find.textContaining('No. 40')),
          )
          .data!;
      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail-title')), findsOneWidget);
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('comes back to the same place after an item', (tester) async {
      await launchApp(tester);
      await tester.drag(
        find.byKey(const Key('feed-list')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byKey(const Key('item-card-5')));

      await tester.tap(find.byKey(const Key('item-card-5')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(const Key('item-card-5'))), before);
    });
  });
}
