import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();

  group('Gallery', () {
    testWidgets('shows a grid of photos', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Gallery');

      expect(find.byKey(const Key('photo-0')), findsOneWidget);
      expect(find.byKey(const Key('photo-5')), findsOneWidget);
    });

    testWidgets('opens a photo and swipes through', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Gallery');

      await tester.tap(find.byKey(const Key('photo-0')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 60'), findsOneWidget);

      // A swipe across most of the screen, as a thumb makes it.
      final viewer = find.byKey(const Key('photo-viewer'));
      await tester.drag(viewer, Offset(-tester.getSize(viewer).width * 0.6, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 60'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gallery-grid')), findsOneWidget);
    });

    testWidgets('scrolls to the bottom of the grid', (tester) async {
      await launchApp(tester);
      await openTab(tester, 'Gallery');

      await tester.scrollUntilVisible(
        find.byKey(const Key('photo-59')),
        500,
        scrollable: find.descendant(
          of: find.byKey(const Key('gallery-grid')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.byKey(const Key('photo-59')), findsOneWidget);
    });
  });
}
