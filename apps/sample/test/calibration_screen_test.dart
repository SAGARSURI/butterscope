import 'package:butterscope_sample/src/calibration_screen.dart';
import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:butterscope_sample/src/plants/plant_costs.dart';
import 'package:butterscope_sample/src/plants/raster_plants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shows the calibration screen with [plant] in [phase], adding the frame
/// budgets of each run of the planted UI work to [workRuns].
Future<void> showScreen(
  WidgetTester tester, {
  required ValueNotifier<CalibrationPhase> phase,
  required List<double> workRuns,
  Plant plant = Plant.none,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: CalibrationScreen(
        plant: plant,
        phase: phase,
        work: (_, budgets) => workRuns.add(budgets),
      ),
    ),
  );
}

/// A phase notifier that counts its listeners, starting animated.
class CountingPhase extends ValueNotifier<CalibrationPhase> {
  new() : super(CalibrationPhase.animated);

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) {
    listeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners--;
    super.removeListener(listener);
  }
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
  late List<double> workRuns;

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

    testWidgets('follows a new phase notifier', (tester) async {
      final first = CountingPhase();
      final second = CountingPhase()..value = CalibrationPhase.still;
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await showScreen(tester, phase: first, workRuns: workRuns);
      // The screen and its ValueListenableBuilder both listen.
      final listening = first.listeners;
      await showScreen(tester, phase: second, workRuns: workRuns);
      expect(first.listeners, 0);
      expect(second.listeners, listening);
      // The animation stops while the new notifier is applied; the frame it
      // had already asked for is the last.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      first.value = CalibrationPhase.still;
      second.value = CalibrationPhase.animated;
      await tester.pump();
      final before = boxTransform(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(boxTransform(tester), isNot(before));

      await tester.pumpWidget(const SizedBox());
      expect(second.listeners, 0);
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
      expect(workRuns, everyElement(listenerDecodeBudgets.value));
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
      expect(workRuns, everyElement(postframeDecodeBudgets.value));
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

  testWidgets('GpuHeavyPlant throws when its shader fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GpuHeavyPlant(
          turns: const AlwaysStoppedAnimation(0),
          iterations: 1,
          loadProgram: () => Future.error(UnsupportedError('no shader')),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isUnsupportedError);
  });
}
