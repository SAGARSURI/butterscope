import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plant.dart';
import 'package:butterscope_sample/src/raster_plants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the calibration screen with [plant] in [phase], counting each run
/// of the planted UI work in [workRuns].
Future<void> showScreen(
  WidgetTester tester, {
  required ValueNotifier<CalibrationPhase> phase,
  required List<int> workRuns,
  Plant plant = Plant.none,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: CalibrationScreen(
        plant: plant,
        phase: phase,
        work: (_) => workRuns.add(workRuns.length),
      ),
    ),
  );
}

Matrix4 boxTransform(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(
    find.ancestor(
      of: find.byKey(const Key('calibration-box')),
      matching: find.byType(Transform),
    ),
  );
  return transforms.first.transform;
}

void main() {
  late ValueNotifier<CalibrationPhase> phase;
  late List<int> workRuns;

  setUp(() {
    phase = ValueNotifier(CalibrationPhase.animated);
    workRuns = [];
  });

  tearDown(() => phase.dispose());

  group('CalibrationScreen phases', () {
    testWidgets('the box moves while animated', (tester) async {
      await showScreen(tester, phase: phase, workRuns: workRuns);
      final before = boxTransform(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(boxTransform(tester), isNot(before));
    });

    testWidgets('nothing is redrawn while still', (tester) async {
      await showScreen(tester, phase: phase, workRuns: workRuns);
      phase.value = CalibrationPhase.still;
      await tester.pump();
      final before = boxTransform(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(boxTransform(tester), before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a tap toggles the phase', (tester) async {
      await showScreen(tester, phase: phase, workRuns: workRuns);
      await tester.tap(find.byType(CalibrationScreen));
      expect(phase.value, CalibrationPhase.still);

      await tester.tap(find.byType(CalibrationScreen));
      expect(phase.value, CalibrationPhase.animated);
    });
  });

  group('CalibrationScreen UI plants', () {
    testWidgets('listener_decode runs on each stream event', (tester) async {
      await showScreen(
        tester,
        phase: phase,
        workRuns: workRuns,
        plant: Plant.listenerDecode,
      );
      // The stream emits every 50 ms.
      await tester.pump(const Duration(milliseconds: 160));

      expect(workRuns, hasLength(3));
    });

    testWidgets('postframe_decode runs after each frame', (tester) async {
      await showScreen(
        tester,
        phase: phase,
        workRuns: workRuns,
        plant: Plant.postframeDecode,
      );
      await tester.pump();
      await tester.pump();

      // One run after each of the three frames.
      expect(workRuns, hasLength(3));
    });

    for (final plant in [Plant.listenerDecode, Plant.postframeDecode]) {
      testWidgets('${plant.defineName} stops in the still phase', (
        tester,
      ) async {
        await showScreen(
          tester,
          phase: phase,
          workRuns: workRuns,
          plant: plant,
        );
        phase.value = CalibrationPhase.still;
        await tester.pump();
        final runs = workRuns.length;
        await tester.pump(const Duration(milliseconds: 200));

        expect(workRuns, hasLength(runs));
      });
    }

    testWidgets('no plant runs no work', (tester) async {
      await showScreen(tester, phase: phase, workRuns: workRuns);
      await tester.pump(const Duration(milliseconds: 200));

      expect(workRuns, isEmpty);
    });
  });

  group('CalibrationScreen render plants', () {
    final layers = {
      Plant.slowRaster: find.byType(SlowRasterPlant),
      Plant.backdropBlur: find.byType(BackdropBlurPlant),
      Plant.gpuHeavy: find.byType(GpuHeavyPlant),
    };

    for (final MapEntry(key: plant, value: finder) in layers.entries) {
      testWidgets('${plant.defineName} is shown only while animated', (
        tester,
      ) async {
        await showScreen(
          tester,
          phase: phase,
          workRuns: workRuns,
          plant: plant,
        );
        expect(finder, findsOneWidget);

        phase.value = CalibrationPhase.still;
        await tester.pump();
        expect(finder, findsNothing);
      });
    }

    testWidgets('no plant shows none of them', (tester) async {
      await showScreen(tester, phase: phase, workRuns: workRuns);

      for (final finder in layers.values) {
        expect(finder, findsNothing);
      }
    });
  });
}
