// Screenshots of Flutter's performance overlay on the screens a build
// plants, each taken while the screen's scripted action runs, so the charts
// show the frames that action draws. tool/m4/run_overlay.sh runs it.
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/m4_overlay_test.dart \
//   --dart-define=BUTTERSCOPE_OVERLAY=on \
//   --dart-define=BUTTERSCOPE_PLANT=<name>
//
// A plant's build shoots its own screen; the clean build shoots every
// screen, for comparison. Each shot prints a `shot` line, and the script
// takes the screenshot from the Mac when it reads the line: over adb on
// Android, with devicectl on iOS. The app does no work for it, so the
// charted frames are the action's alone.

import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'bscope_writer.dart';
import 'support/app.dart';
import 'support/screen_tour.dart';

/// How long a screen runs before its action starts, so that opening it is
/// not charted.
const Duration settle = Duration(seconds: 2);

/// How far into the action the screenshot is taken. The overlay charts the
/// last 120 frames (flow/stopwatch.h kMaxSamples): 1 s at 120 Hz, and 3 s
/// at 40 Hz, the slowest rate a plant here draws at (gpu_heavy on the
/// iPhone). So every bar is a frame the action drew. The 2 s left of the
/// action cover the script reading the line and taking the shot.
const Duration shootAfter = Duration(seconds: 3);

/// The name M2's calibration screen goes by in screenshot names.
const String calibration = 'Calibration';

/// The screens a build of [plant] shoots: its own, or every one for the
/// clean build.
Set<String> screensFor(Plant plant) {
  if (plant != Plant.none) return {plant.screen ?? calibration};
  return {for (final plant in Plant.values) ?plant.screen, calibration};
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plant = Plant.fromEnvironment();
  final name = plant == Plant.none ? 'clean' : plant.defineName;
  final screens = screensFor(plant);
  final writer = BscopeWriter(debugPrintSynchronously);

  Future<void> shoot(String screen, ScreenAction act) async {
    if (!screens.contains(screen)) return;
    await Future<void>.delayed(settle);
    final watch = Stopwatch()..start();
    final acting = Future.wait([act(watch), Future<void>.delayed(window)]);
    await Future<void>.delayed(shootAfter);
    final shot = '$name-${screen.toLowerCase()}';
    writer.line('shot', [shot]);
    await acting;
  }

  testWidgets('M4 overlay screenshots', semanticsEnabled: false, (
    tester,
  ) async {
    expect(
      const String.fromEnvironment('BUTTERSCOPE_OVERLAY'),
      'on',
      reason: 'Build with --dart-define=BUTTERSCOPE_OVERLAY=on.',
    );
    writer.line('run', ['plant=$name', 'screens=${screens.join(',')}']);
    if (plant.screen != null || plant == Plant.none) {
      await launchApp(tester);
      binding.framePolicy =
          LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
      await tourScreens(tester, shoot);
    }
    if (screens.contains(calibration)) {
      binding.framePolicy =
          LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
      final phase = ValueNotifier(CalibrationPhase.animated);
      addTearDown(phase.dispose);
      await tester.pumpWidget(
        MaterialApp(
          showPerformanceOverlay: true,
          home: CalibrationScreen(plant: plant, phase: phase),
        ),
      );
      await shoot(calibration, justWait);
    }

    writer.done();
  });
}
