// M2's overhead probe: traces the calibration screen's animated and still
// phases with the frame recorder on or off, so p99 frame times from the VM
// timeline can be compared between the two (decision record 0002).
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/overhead_driver.dart \
//   --target=integration_test/m2_overhead_test.dart \
//   --dart-define=BUTTERSCOPE_RECORDER=on
//
// The same command with `off` runs the arm without the recorder. The test
// reports its arm with the traces, so the driver labels them from the build
// itself.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_sample/main.dart';
import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const Duration settle = Duration(seconds: 2);
const Duration window = Duration(seconds: 5);

/// The gap between the animated window and the still one, so the phase
/// change has been drawn before the still window starts.
const Duration phaseChange = Duration(milliseconds: 500);

/// The VM timeline streams that carry the framework's `Frame` events and the
/// engine's `GPURasterizer::Draw` events, which the timeline summary reads.
const List<String> streams = ['Dart', 'Embedder'];

bool recorderFromEnvironment() {
  const value = String.fromEnvironment('BUTTERSCOPE_RECORDER');
  return switch (value) {
    'on' => true,
    'off' => false,
    _ => throw ArgumentError.value(value, 'BUTTERSCOPE_RECORDER'),
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  final recording = recorderFromEnvironment();

  /// Traces one window under [name], with the recorder running through it
  /// when [recording]. The recorder starts before the trace and stops after
  /// it, so the trace holds the same span of frames in both arms.
  Future<void> traceWindow(String name) async {
    final recorder = recording ? FrameRecorder(EngineFrameSource()) : null;
    recorder?.start();
    await binding.traceAction(
      () => Future<void>.delayed(window),
      streams: streams,
      reportKey: name,
    );
    await recorder?.stop();
  }

  testWidgets('M2 overhead windows', semanticsEnabled: false, (tester) async {
    final phase = ValueNotifier(CalibrationPhase.animated);
    addTearDown(phase.dispose);
    await tester.pumpWidget(SampleApp(phase: phase));
    await Future<void>.delayed(settle);

    await traceWindow('animated');
    phase.value = CalibrationPhase.still;
    await Future<void>.delayed(phaseChange);
    await traceWindow('still');
    binding.reportData!['arm'] = recording ? 'on' : 'off';
  });
}
