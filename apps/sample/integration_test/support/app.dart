import 'package:butterscope_sample/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the app as a user would and waits for the first screen.
Future<void> launchApp(WidgetTester tester) async {
  // On a device the binding leaves typing to the real keyboard, which
  // `enterText` cannot reach, so route text input through the test's.
  tester.testTextInput.register();
  app.main();
  await tester.pumpAndSettle();
}

/// Taps [label] in the bottom bar and waits for the screen to show.
///
/// Waits a fixed time rather than settling: Activity and Inbox are fed by
/// streams, so they never settle.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

/// Pumps until [finder] finds something, failing after [timeout].
///
/// For screens fed by a stream, where `pumpAndSettle` never settles.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out after $timeout waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}
