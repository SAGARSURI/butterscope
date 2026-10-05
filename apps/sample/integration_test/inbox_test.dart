import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Inbox', () {
    testWidgets('messages arrive while the screen is open', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Inbox');

      // A batch of 20 arrives every 500 ms.
      await pumpUntilFound(tester, find.text('20 messages'));
      await pumpUntilFound(tester, find.text('40 messages'));
    });

    testWidgets('the newest message is at the top and opens', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Inbox');
      await pumpUntilFound(tester, find.text('20 messages'));

      // The first batch holds messages 0 to 19; 19 is the newest.
      final newest = find.byKey(const Key('message-19'));
      final older = find.byKey(const Key('message-18'));
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(older).dy),
      );

      await tester.tap(newest);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.textContaining('Open the app to see the details'),
        findsOneWidget,
      );
    });

    testWidgets('an open message stays put while more arrive', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Inbox');
      await pumpUntilFound(tester, find.text('20 messages'));
      final newest = find.byKey(const Key('message-19'));
      await tester.tap(newest);
      await tester.pump(const Duration(milliseconds: 250));
      final place = tester.getTopLeft(newest);

      // The next batch waits above the list until the message closes.
      await pumpUntilFound(tester, find.text('20 new'));

      expect(tester.getTopLeft(newest), place);
      expect(find.text('20 messages'), findsOneWidget);

      // Closing it lets the waiting messages in. More may have arrived by
      // then, so the count is at least 40 rather than exactly 40.
      await tester.tap(newest);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('inbox-waiting')), findsNothing);
      final count = tester.widget<Text>(find.byKey(const Key('inbox-count')));
      expect(int.parse(count.data!.split(' ').first), greaterThanOrEqualTo(40));
    });
  });
}
