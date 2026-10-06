// Screenshots of Flutter's performance overlay on the screens a build
// plants, each taken while the screen's scripted action runs, so the charts
// show the frames that action draws. tool/m4/run_overlay.sh runs it.
//
// fvm flutter drive --profile --no-dds --keep-app-running \
//   --driver=test_driver/overlay_driver.dart \
//   --target=integration_test/m4_overlay_test.dart \
//   --dart-define=BUTTERSCOPE_OVERLAY=on \
//   --dart-define=BUTTERSCOPE_PLANT=<name>
//
// A plant's build shoots its own screen; the clean build shoots every
// screen, for comparison. Each shot prints a `shot` line first. On iOS the
// test takes the screenshot itself and the driver saves it. On Android the
// plugin's screenshot first converts the Flutter view to an image view,
// which changes how frames are drawn, so the script takes the screenshot
// over adb when it reads the line instead.

import 'dart:ui' as ui;

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
/// action cover Android, where the script reads the line and then takes
/// the shot.
const Duration shootAfter = Duration(seconds: 3);

/// The name M2's calibration screen goes by in screenshot names.
const String calibration = 'Calibration';

/// The screens a build of [plant] shoots: its own, or every one for the
/// clean build.
Set<String> screensFor(Plant plant) {
  if (plant != Plant.none) return {plant.screen ?? calibration};
  return {for (final plant in Plant.values) ?plant.screen, calibration};
}

/// Shrinks a PNG to half its width, so a run's screenshots travel to the
/// driver in a reasonable size and the overlay's text stays readable.
Future<List<int>> halfSize(List<int> png) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    Uint8List.fromList(png),
  );
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) => ui.TargetImageSize(width: width ~/ 2),
  );
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  codec.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final plant = Plant.fromEnvironment();
  final name = plant == Plant.none ? 'clean' : plant.defineName;
  final screens = screensFor(plant);
  final writer = BscopeWriter(debugPrintSynchronously);
  final shots = <String, List<int>>{};

  Future<void> shoot(String screen, ScreenAction act) async {
    if (!screens.contains(screen)) return;
    await Future<void>.delayed(settle);
    final watch = Stopwatch()..start();
    final acting = Future.wait([act(watch), Future<void>.delayed(window)]);
    await Future<void>.delayed(shootAfter);
    final shot = '$name-${screen.toLowerCase()}';
    writer.line('shot', [shot]);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      shots[shot] = await binding.takeScreenshot(shot);
    }
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

    // Shrunk after the last action, so the work draws no charted frame.
    binding.reportData = {
      'screenshots': [
        for (final MapEntry(:key, :value) in shots.entries)
          {'screenshotName': key, 'bytes': await halfSize(value)},
      ],
    };
    writer.done();
  });
}
