// M2's probe: records the calibration screen's animated and still phases
// on a phone and prints every frame as BSCOPE lines for
// tool/m2/summarise.dart.
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/m2_calibration_test.dart \
//   --dart-define=BUTTERSCOPE_PLANT=<name> \
//   --dart-define=BUTTERSCOPE_SEMANTICS=<on|off>

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'bscope_writer.dart';
import 'support/run_conditions.dart';

const Duration settle = Duration(seconds: 2);
const Duration window = Duration(seconds: 5);

/// The gap between the animated window and the still one, so the phase
/// change has been drawn before the still window starts.
const Duration phaseChange = Duration(milliseconds: 500);

/// Records a window of [length] and returns it with its wall-clock length.
Future<(RecordedWindow, int)> record(Duration length) async {
  final recorder = FrameRecorder(EngineFrameSource());
  final wall = Stopwatch()..start();
  recorder.start();
  await Future<void>.delayed(length);
  // The window ends when stop is called, not after the flush.
  final stopping = recorder.stop();
  wall.stop();
  return (await stopping, wall.elapsedMicroseconds);
}

String describe(WindowMetrics metrics) {
  String fixed(double? value) => value?.toStringAsFixed(3) ?? 'n/a';
  return [
    'frames=${metrics.frameCount}',
    'janky=${metrics.jankyCount}',
    'severe=${metrics.severeCount}',
    'stalls=${metrics.stallCount}',
    'missedVsyncs=${metrics.missedVsyncCount}',
    'uiP99=${fixed(metrics.uiP99)}B',
    'rasterP99=${fixed(metrics.rasterP99)}B',
    'hitchRatio=${fixed(metrics.hitchRatio)}',
    'observedHz=${fixed(metrics.observedRefreshRate)}',
  ].join(' ');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  final plant = Plant.fromEnvironment();
  final semantics = semanticsFromEnvironment();
  final writer = BscopeWriter(debugPrintSynchronously);
  final run = <String, Object>{
    'plant': plant == Plant.none ? 'none' : plant.defineName,
    'semantics': semantics ? 'on' : 'off',
    'mode': buildMode,
  };

  testWidgets('M2 calibration windows', semanticsEnabled: semantics, (
    tester,
  ) async {
    writer.line('run', [
      // Unique per run, so a reader never mistakes two runs for one.
      'id=${DateTime.now().microsecondsSinceEpoch}',
      'policy=${binding.framePolicy.name}',
      for (final MapEntry(:key, :value) in run.entries) '$key=$value',
    ]);
    final phase = ValueNotifier(CalibrationPhase.animated);
    addTearDown(phase.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationScreen(plant: plant, phase: phase),
      ),
    );
    await Future<void>.delayed(settle);

    final (animated, animatedWall) = await record(window);
    phase.value = CalibrationPhase.still;
    await Future<void>.delayed(phaseChange);
    final (still, stillWall) = await record(window);

    // Printed after recording, so the printing costs no measured frame.
    for (final (name, recorded, wall) in [
      ('animated', animated, animatedWall),
      ('still', still, stillWall),
    ]) {
      writer.window(name, recorded, {...run, 'wallMicros': wall});
      final reads = recorded.refreshRateReads;
      if (FrameBudget.isValidRefreshRate(reads.first.hertz)) {
        final budget = FrameBudget(reads.first.hertz);
        final metrics = WindowMetrics.of(recorded.samples, budget);
        writer.line('metrics', [name, describe(metrics)]);
      }
    }
    writer.done();
  });
}
