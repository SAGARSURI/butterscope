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
        FrameMark(frameNumber: 0, declaredRefreshRate: 0),
        FrameMark(frameNumber: 3, declaredRefreshRate: 0),
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
        FrameMark(frameNumber: 0, declaredRefreshRate: 600),
        FrameMark(frameNumber: 2, declaredRefreshRate: 120),
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
        FrameMark(frameNumber: 0, declaredRefreshRate: double.nan),
        FrameMark(frameNumber: 1, declaredRefreshRate: double.infinity),
      ),
    ]).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    expect(part['declaredHz'], isNull);
    expect(part['declaredHzAtEnd'], isNull);
    expect(part.containsKey('metrics'), isFalse);
    expect(() => jsonEncode(report), returnsNormally);
  });
}
