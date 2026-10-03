import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// 125 Hz gives a budget of exactly 8000 µs, so every edge is exact.
final FrameBudget budget = FrameBudget(125);

ClassifiedFrame judge(int buildMicros, int rasterMicros, {int waitMicros = 0}) {
  return ClassifiedFrame(
    FrameSample(
      vsyncStartMicros: 0,
      buildMicros: buildMicros,
      rasterMicros: rasterMicros,
      vsyncOverheadMicros: waitMicros,
    ),
    budget,
  );
}

void main() {
  group('frame class', () {
    test('exactly the budget is smooth', () {
      expect(judge(8000, 8000).frameClass, FrameClass.smooth);
    });

    test('one microsecond over the budget on either thread is janky', () {
      expect(judge(8001, 0).frameClass, FrameClass.janky);
      expect(judge(0, 8001).frameClass, FrameClass.janky);
    });

    test('exactly twice the budget is janky, not severe', () {
      expect(judge(16000, 0).frameClass, FrameClass.janky);
    });

    test('over twice the budget is severe', () {
      expect(judge(16001, 0).frameClass, FrameClass.severe);
      expect(judge(0, 99999).frameClass, FrameClass.severe);
    });

    test('100 ms or more is a stall', () {
      expect(judge(100000, 0).frameClass, FrameClass.stall);
      expect(judge(0, 250000).frameClass, FrameClass.stall);
    });

    test('a long frame is a stall only when it is also severe', () {
      // At 5 Hz the budget is 200 ms, so a 300 ms frame is only janky.
      final frame = ClassifiedFrame(
        const FrameSample(
          vsyncStartMicros: 0,
          buildMicros: 300000,
          rasterMicros: 0,
        ),
        FrameBudget(5),
      );
      expect(frame.frameClass, FrameClass.janky);
    });

    test('classes nest', () {
      expect(FrameClass.stall.isAtLeast(FrameClass.severe), isTrue);
      expect(FrameClass.severe.isAtLeast(FrameClass.janky), isTrue);
      expect(FrameClass.janky.isAtLeast(FrameClass.janky), isTrue);
      expect(FrameClass.smooth.isAtLeast(FrameClass.janky), isFalse);
    });
  });

  group('thread', () {
    test('is null for a smooth frame', () {
      expect(judge(8000, 8000).thread, isNull);
    });

    test('is ui when only build is over budget', () {
      expect(judge(9000, 8000).thread, JankThread.ui);
    });

    test('is raster when only raster is over budget', () {
      expect(judge(8000, 9000).thread, JankThread.raster);
    });

    test('is both when both are over budget', () {
      expect(judge(9000, 9000).thread, JankThread.both);
    });
  });

  test('overrun is the slower thread minus the budget', () {
    expect(judge(9000, 12000).overrunMicros, 4000);
    expect(judge(5000, 3000).overrunMicros, -3000);
  });

  test('multiples are relative to the budget', () {
    final frame = judge(12000, 4000);
    expect(frame.uiMultiple, 1.5);
    expect(frame.rasterMultiple, 0.5);
  });

  group('waiting for the UI thread', () {
    test('counts as UI time', () {
      // Neither the 5 ms wait nor the 5 ms build is over the 8 ms budget
      // alone; together the UI thread missed the next vsync.
      final frame = judge(5000, 2000, waitMicros: 5000);
      expect(frame.uiMicros, 10000);
      expect(frame.frameClass, FrameClass.janky);
      expect(frame.thread, JankThread.ui);
      expect(frame.overrunMicros, 2000);
      expect(frame.uiMultiple, 1.25);
    });

    test('makes a frame severe when the UI thread was busy elsewhere', () {
      // A 40 ms decode in a stream listener delays a 3 ms build.
      final frame = judge(3000, 2000, waitMicros: 40000);
      expect(frame.frameClass, FrameClass.severe);
      expect(frame.thread, JankThread.ui);
    });

    test('of 100 ms or more makes a stall', () {
      final frame = judge(1000, 1000, waitMicros: 100000);
      expect(frame.frameClass, FrameClass.stall);
    });

    test('below zero counts as none', () {
      final frame = judge(7000, 2000, waitMicros: -500);
      expect(frame.uiMicros, 7000);
      expect(frame.frameClass, FrameClass.smooth);
    });
  });
}
