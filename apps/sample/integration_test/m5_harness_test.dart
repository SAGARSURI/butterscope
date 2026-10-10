// M5's harness cost: what a test step inside a span costs the app's frames
// (DESIGN 6.8). Test code runs on the UI thread between frames, so its time
// can push a frame past its vsync. Each step runs 50 times, 100 ms apart, in
// a span of its own, between two empty spans of the same length. It runs on
// the calibration screen's still window, where any lost frame is the
// harness's, and on the clean Feed, whose tree is the size a real screen's
// is. tool/m5/run_tests.sh runs it:
//
//   TARGET=integration_test/m5_harness_test.dart RUNS=5 \
//     tool/m5/run_tests.sh <device-id> clean
//
// Each call's own time, from a Stopwatch, is printed as a BSCOPE-HARNESS
// line after its screen's spans, for tool/m5/read_harness.dart.

import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_test/butterscope_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/m5/harness_costs.dart'
    show emptyAfter, emptyBefore, harnessCalls, harnessTag;
import 'support/app.dart';
import 'support/screen_tour.dart' show phrase;

/// The time from one call's start to the next.
const Duration interval = Duration(milliseconds: 100);

/// How long a screen runs before its first span, so opening it is not
/// measured.
const Duration settle = Duration(seconds: 2);

/// One test step, as a test would write it.
typedef Step = Future<void> Function();

/// Runs [step] [harnessCalls] times, [interval] apart, inside the span
/// [name], and returns each call's time in µs. With no [step] the span is
/// empty.
///
/// The span ends one [interval] after the last call, so it lasts 5 s and
/// holds the frames of every call.
Future<List<int>> measure(String name, [Step? step]) {
  return span(name, () async {
    final times = <int>[];
    final clock = Stopwatch()..start();
    for (var i = 0; i <= harnessCalls; i++) {
      final wait = interval * i - clock.elapsed;
      await Future<void>.delayed(wait.isNegative ? Duration.zero : wait);
      if (step == null || i == harnessCalls) continue;
      final call = Stopwatch()..start();
      await step();
      times.add(call.elapsedMicroseconds);
    }
    return times;
  });
}

/// Runs each of [steps] in its own span on [screen], between empty spans,
/// then prints each step's call times.
Future<void> measureScreen(String screen, Map<String, Step> steps) async {
  await Future<void>.delayed(settle);
  await measure('$screen: $emptyBefore');
  final times = {
    for (final MapEntry(key: name, value: step) in steps.entries)
      name: await measure('$screen: $name', step),
  };
  await measure('$screen: $emptyAfter');
  // Printed after the spans, so printing costs no measured frame.
  for (final MapEntry(key: name, value: micros) in times.entries) {
    debugPrintSynchronously('$harnessTag $screen: $name ${micros.join(',')}');
  }
}

/// The steps measured on a screen, as an ordinary test writes them.
///
/// [key] and [text] each name one widget for the finders, [title] finds one
/// [Text], and [spot] is a place where a tap or a drag does nothing. With a
/// [field], it also types into it, a keystroke a call.
Map<String, Step> stepsOn(
  WidgetTester tester, {
  required Key key,
  required String text,
  required Finder title,
  required Finder spot,
  Finder? field,
}) {
  return {
    // A finder searches the tree only when its result is read.
    'find.byKey': () async => find.byKey(key).evaluate().length,
    'find.text': () async => find.text(text).evaluate().length,
    'expect': () async => expect(find.byKey(key), findsOneWidget),
    'tester.widget': () async => tester.widget<Text>(title),
    'tap': () => tester.tap(spot),
    'drag': () => tester.drag(spot, const Offset(-100, 0)),
    if (field != null) 'enterText': keystrokes(tester, field),
  };
}

/// A step that types one more letter of [phrase] into [field] each call,
/// starting over when it is done, as a person types.
Step keystrokes(WidgetTester tester, Finder field) {
  var typed = 0;
  return () {
    typed = typed % phrase.length + 1;
    return tester.enterText(field, phrase.substring(0, typed));
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachButterscope();

  const pad = Key('harness-pad');
  const field = Key('harness-field');

  testWidgets('still screen', semanticsEnabled: false, (tester) async {
    tester.testTextInput.register();
    final phase = ValueNotifier(CalibrationPhase.still);
    addTearDown(phase.dispose);
    // Below the still box: a strip where a tap or drag does nothing, and a
    // field to type into.
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Column(
            children: [
              Expanded(
                child: CalibrationScreen(plant: Plant.none, phase: phase),
              ),
              const SizedBox(
                key: pad,
                height: 120,
                child: Center(child: Text('harness')),
              ),
              const TextField(key: field),
            ],
          ),
        ),
      ),
    );

    await measureScreen(
      'still',
      stepsOn(
        tester,
        key: pad,
        text: 'harness',
        title: find.text('harness'),
        spot: find.byKey(pad),
        field: find.byKey(field),
      ),
    );
  });

  testWidgets('feed', semanticsEnabled: false, (tester) async {
    await launchApp(tester);
    // The bar's title does nothing when tapped or dragged.
    final title = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Feed'),
    );

    await measureScreen(
      'feed',
      stepsOn(
        tester,
        key: const Key('item-card-0'),
        text: 'Feed',
        title: title,
        spot: title,
      ),
    );
  });

  testWidgets('search typing', semanticsEnabled: false, (tester) async {
    await launchApp(tester);
    await openTab(tester, 'Search');

    // The Feed has no field, so a real screen's keystroke is measured on
    // Search, where each one searches the catalogue.
    await measureScreen('search', {
      'enterText': keystrokes(tester, find.byKey(const Key('search-field'))),
    });
  });
}
