// The scripted visit to each sample screen that M4's probe and overlay
// runs share: the screens in one order, each with the action that loads
// it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app.dart';

/// How long each screen's action runs.
const Duration window = Duration(seconds: 5);

/// The pause after each fling, so the list coasts as it would under a
/// thumb.
const Duration coast = Duration(milliseconds: 600);

/// The time between keystrokes: a fast typist, about 7 a second.
const Duration keystroke = Duration(milliseconds: 150);

/// What the Search window types, one letter at a time, again and again.
const String phrase = 'lantern garden';

/// A screen's scripted action, which runs until [watch] reaches [window].
typedef ScreenAction = Future<void> Function(Stopwatch watch);

/// Flings [scrollable] by [distance] logical pixels, alternating direction
/// when [alternate] is set, until [watch] reaches [window].
Future<void> flingFor(
  WidgetTester tester,
  Stopwatch watch,
  Finder scrollable, {
  double distance = 1200,
  bool alternate = false,
}) async {
  var sign = -1.0;
  while (watch.elapsed < window) {
    await tester.fling(scrollable, Offset(0, sign * distance), 2500);
    await Future<void>.delayed(coast);
    if (alternate) sign = -sign;
  }
}

/// Types [phrase] into the search field a letter at a time, starting over
/// when it is done, until [watch] reaches [window].
Future<void> typeFor(WidgetTester tester, Stopwatch watch) async {
  final field = find.byKey(const Key('search-field'));
  var length = 0;
  while (watch.elapsed < window) {
    length = length % phrase.length + 1;
    await tester.enterText(field, phrase.substring(0, length));
    await Future<void>.delayed(keystroke);
  }
}

/// The action for Activity and Inbox, whose streams do the work.
Future<void> justWait(Stopwatch watch) async {}

/// Opens each screen of the launched app in turn and calls [visit] with
/// the screen's name and its action: flings on Feed, Gallery and Detail,
/// typing on Search, and waiting on Activity and Inbox.
Future<void> tourScreens(
  WidgetTester tester,
  Future<void> Function(String screen, ScreenAction act) visit,
) async {
  await visit(
    'Feed',
    (watch) => flingFor(tester, watch, find.byKey(const Key('feed-list'))),
  );
  await openTab(tester, 'Search');
  await visit('Search', (watch) => typeFor(tester, watch));
  await openTab(tester, 'Activity');
  await visit('Activity', justWait);
  await openTab(tester, 'Inbox');
  await visit('Inbox', justWait);
  await openTab(tester, 'Gallery');
  await visit(
    'Gallery',
    (watch) => flingFor(
      tester,
      watch,
      find.byKey(const Key('gallery-grid')),
      alternate: true,
    ),
  );
  await openTab(tester, 'Feed');
  await tester.tap(find.byKey(const Key('item-card-0')));
  await visit(
    'Detail',
    (watch) => flingFor(
      tester,
      watch,
      find.byKey(const Key('detail-scroll')),
      distance: 600,
      alternate: true,
    ),
  );
}
