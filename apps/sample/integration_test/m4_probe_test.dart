// M4's probe: opens each sample screen and records one window while a
// scripted action runs, then prints every frame as BSCOPE lines for
// tool/m2/summarise.dart. tool/m4/run_probe.sh runs it.
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/m4_probe_test.dart \
//   --dart-define=BUTTERSCOPE_PLANT=<name> \
//   --dart-define=BUTTERSCOPE_COST=<value> \
//   --dart-define=BUTTERSCOPE_SEMANTICS=<on|off>
//
// This is measurement code like M2's probe, kept apart from the ordinary
// tests; it is not the M5 API.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'bscope_writer.dart';
import 'support/app.dart';
import 'support/run_conditions.dart';
import 'support/screen_tour.dart';

/// How long a screen runs before its window starts, so that opening it is
/// not measured.
const Duration settle = Duration(seconds: 2);

/// Records one window while [act] runs, and returns it with its
/// wall-clock length.
Future<(RecordedWindow, int)> recordWhile(ScreenAction act) async {
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plant = Plant.fromEnvironment();
  const cost = String.fromEnvironment('BUTTERSCOPE_COST');
  final semantics = semanticsFromEnvironment();
  final writer = BscopeWriter(debugPrintSynchronously);
  final run = <String, Object>{
    'plant': plant == Plant.none ? 'none' : plant.defineName,
    'cost': cost.isEmpty ? 'default' : cost,
    'semantics': semantics ? 'on' : 'off',
    'mode': buildMode,
  };

  testWidgets('M4 screen windows', semanticsEnabled: semantics, (tester) async {
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
    Future<void> measure(String screen, ScreenAction act) async {
      await Future<void>.delayed(settle);
      final (recorded, wall) = await recordWhile(act);
      windows.add((screen, recorded, wall));
    }

    await tourScreens(tester, measure);

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
