import 'dart:convert';

import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecordedWindow windowOf(List<int> frameNumbers) {
    return RecordedWindow(
      startFrameNumber: 0,
      endFrameNumber: frameNumbers.last,
      samples: [
        for (final number in frameNumbers)
          FrameSample(
            vsyncStartMicros: number * 8333,
            buildMicros: 2000,
            rasterMicros: 2000,
            frameNumber: number,
          ),
      ],
      refreshRateReads: const [],
      flushTimedOut: false,
      flushMicros: 0,
      callbackMicros: 0,
    );
  }

  test('reports a part with no metrics when its rate gives no budget', () {
    final report = RunReport(windowOf([1, 2, 3]), const [
      MarkedPart(
        PartKind.test,
        'opens',
        FrameMark(frameNumber: 0, declaredRefreshRate: 0, micros: 0),
        FrameMark(frameNumber: 3, declaredRefreshRate: 0, micros: 0),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    expect(part['frames'], 3);
    expect(part['declaredHz'], 0);
    expect(part.containsKey('metrics'), isFalse);
  });

  test("judges a part against its start's declared rate", () {
    // Builds of 2 ms are smooth at 120 Hz (8.33 ms) and janky at 600 Hz
    // (1.67 ms), whatever the rate read at the end.
    final report = RunReport(windowOf([1, 2]), const [
      MarkedPart(
        PartKind.test,
        'opens',
        FrameMark(frameNumber: 0, declaredRefreshRate: 600, micros: 0),
        FrameMark(frameNumber: 2, declaredRefreshRate: 120, micros: 0),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['janky'], 2);
    expect(part['declaredHzAtEnd'], 120);
  });

  test('writes a rate that is not finite as null, so JSON can hold it', () {
    final report = RunReport(windowOf([1]), const [
      MarkedPart(
        PartKind.test,
        'opens',
        FrameMark(frameNumber: 0, declaredRefreshRate: double.nan, micros: 0),
        FrameMark(
          frameNumber: 1,
          declaredRefreshRate: double.infinity,
          micros: 0,
        ),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    expect(part['declaredHz'], isNull);
    expect(part['declaredHzAtEnd'], isNull);
    expect(part.containsKey('metrics'), isFalse);
    expect(() => jsonEncode(report), returnsNormally);
  });

  test('lists the seconds whose rate is off the declared one', () {
    // 12 smooth frames 16 667 µs apart, judged at a declared 120 Hz: one
    // slice of 11 gaps reading 1 000 000 ÷ 16 667 = 59.999 Hz.
    final window = RecordedWindow(
      startFrameNumber: 0,
      endFrameNumber: 12,
      samples: [
        for (var i = 0; i < 12; i++)
          FrameSample(
            vsyncStartMicros: i * 16667,
            buildMicros: 2000,
            rasterMicros: 2000,
            frameNumber: i + 1,
          ),
      ],
      refreshRateReads: const [],
      flushTimedOut: false,
      flushMicros: 0,
      callbackMicros: 0,
    );
    final report = RunReport(window, const [
      MarkedPart(
        PartKind.span,
        'feed scroll',
        FrameMark(frameNumber: 0, declaredRefreshRate: 120, micros: 0),
        FrameMark(frameNumber: 12, declaredRefreshRate: 120, micros: 0),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['rateSlicesJudged'], 1);
    final mismatch = (metrics['rateMismatches']! as List).single as List;
    expect(mismatch[0], 0);
    expect(mismatch[1], 11);
    expect(mismatch[2] as double, closeTo(59.999, 0.001));
  });

  test('says a part too short for a slice was not checked', () {
    final report = RunReport(windowOf([1, 2, 3]), const [
      MarkedPart(
        PartKind.span,
        'tap',
        FrameMark(frameNumber: 0, declaredRefreshRate: 120, micros: 0),
        FrameMark(frameNumber: 3, declaredRefreshRate: 120, micros: 0),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['rateSlicesJudged'], 0);
    expect(metrics['rateMismatches'], isEmpty);
  });
}
