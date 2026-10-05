// M4's probe: opens each sample screen and records one window while a
// scripted action runs, then prints every frame as BSCOPE lines for
// tool/m2/summarise.dart. tool/m4/run_probe.sh runs it.
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/m4_probe_test.dart \
//   --dart-define=BUTTERSCOPE_PLANT=<name> \
//   --dart-define=BUTTERSCOPE_COST=<value>
//
// This is measurement code like M2's probe, kept apart from the ordinary
// tests; it is not the M5 API.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'bscope_writer.dart';
import 'support/app.dart';

/// How long a screen runs before its window starts, so that opening it is
/// not measured.
const Duration settle = Duration(seconds: 2);

const Duration window = Duration(seconds: 5);

/// The pause after each fling, so the list coasts as it would under a
/// thumb.
const Duration coast = Duration(milliseconds: 600);

/// The time between keystrokes: a fast typist, about 7 a second.
const Duration keystroke = Duration(milliseconds: 150);

/// What the Search window types, one letter at a time, again and again.
const String phrase = 'lantern garden';

String get buildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

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

/// Records one window while [act] runs, and returns it with its
/// wall-clock length.
Future<(RecordedWindow, int)> recordWhile(
  Future<void> Function(Stopwatch watch) act,
) async {
  final recorder = FrameRecorder(EngineFrameSource());
  final wall = Stopwatch()..start();
  recorder.start();
  final acting = act(wall);
  await Future<void>.delayed(window);
  // The window ends when stop is called, not after the flush.
  final stopping = recorder.stop();
  wall.stop();
  final recorded = await stopping;
  // A fling or keystroke started near the end finishes before the next
  // screen opens.
  await acting;
  return (recorded, wall.elapsedMicroseconds);
}

/// The action for Activity and Inbox, whose streams do the work.
Future<void> justWait(Stopwatch watch) async {}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plant = Plant.fromEnvironment();
  const cost = String.fromEnvironment('BUTTERSCOPE_COST');
  final writer = BscopeWriter(debugPrintSynchronously);
  final run = <String, Object>{
    'plant': plant == Plant.none ? 'none' : plant.defineName,
    'cost': cost.isEmpty ? 'default' : cost,
    'mode': buildMode,
  };

  testWidgets('M4 screen windows', (tester) async {
    // Launch and navigate as the ordinary tests do, then switch to
    // benchmarkLive, under which pumpAndSettle would never settle.
    await launchApp(tester);
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
    writer.line('run', [
      // Unique per run, so a reader never mistakes two runs for one.
      'id=${DateTime.now().microsecondsSinceEpoch}',
      'policy=${binding.framePolicy.name}',
      for (final MapEntry(:key, :value) in run.entries) '$key=$value',
    ]);

    final windows = <(String, RecordedWindow, int)>[];
    Future<void> measure(
      String screen,
      Future<void> Function(Stopwatch watch) act,
    ) async {
      await Future<void>.delayed(settle);
      final (recorded, wall) = await recordWhile(act);
      windows.add((screen, recorded, wall));
    }

    await measure(
      'Feed',
      (watch) => flingFor(tester, watch, find.byKey(const Key('feed-list'))),
    );
    await openTab(tester, 'Search');
    await measure('Search', (watch) => typeFor(tester, watch));
    await openTab(tester, 'Activity');
    await measure('Activity', justWait);
    await openTab(tester, 'Inbox');
    await measure('Inbox', justWait);
    await openTab(tester, 'Gallery');
    await measure(
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
    await measure(
      'Detail',
      (watch) => flingFor(
        tester,
        watch,
        find.byKey(const Key('detail-scroll')),
        distance: 600,
        alternate: true,
      ),
    );

    // Printed after recording, so the printing costs no measured frame.
    // The pause between windows keeps logcat from dropping lines.
    for (final (screen, recorded, wall) in windows) {
      writer.window(screen.toLowerCase(), recorded, {
        'screen': screen,
        'planted': plant.screen == screen,
        ...run,
        'wallMicros': wall,
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    writer.done();
  });
}
