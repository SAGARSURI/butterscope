import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Frames 1 to 6, 8000 µs apart. The part holds frames 3 and 4: the 3rd
  // and 4th timings, at indices 2 and 3.
  RecordedWindow windowWith(List<RefreshRateRead> reads) {
    return RecordedWindow(
      startFrameNumber: 0,
      endFrameNumber: 6,
      samples: [
        for (var number = 1; number <= 6; number++)
          FrameSample(
            vsyncStartMicros: number * 8000,
            buildMicros: 2000,
            rasterMicros: 2000,
            frameNumber: number,
          ),
      ],
      refreshRateReads: reads,
      flushTimedOut: false,
      flushMicros: 0,
      callbackMicros: 0,
    );
  }

  MarkedPart partEndingAt(double endHz) {
    return MarkedPart(
      PartKind.span,
      'scroll',
      const FrameMark(frameNumber: 2, declaredRefreshRate: 125, micros: 0),
      FrameMark(frameNumber: 4, declaredRefreshRate: endHz, micros: 0),
    );
  }

  group('declaredRateChanged', () {
    test('sees a read between the span’s first and last timings', () {
      // After 3 timings: the part's first had arrived, its last had not.
      final window = windowWith(const [
        RefreshRateRead(hertz: 60, afterSamples: 3),
      ]);
      expect(declaredRateChanged(partEndingAt(125), window), isTrue);
    });

    test('ignores reads taken before or after the span’s timings', () {
      // After 2 timings, none of the part's; after 5, one past its last.
      final window = windowWith(const [
        RefreshRateRead(hertz: 60, afterSamples: 2),
        RefreshRateRead(hertz: 60, afterSamples: 5),
      ]);
      expect(declaredRateChanged(partEndingAt(125), window), isFalse);
    });

    test('allows 5% of the starting rate, and no more', () {
      final window = windowWith(const []);
      // 5% of 125 Hz is 6.25 Hz: 118.75 is the edge.
      expect(declaredRateChanged(partEndingAt(118.75), window), isFalse);
      expect(declaredRateChanged(partEndingAt(131.25), window), isFalse);
      expect(declaredRateChanged(partEndingAt(118.7), window), isTrue);
      expect(declaredRateChanged(partEndingAt(131.3), window), isTrue);
    });

    test('counts a rate that is not a number as moved', () {
      final window = windowWith(const []);
      expect(declaredRateChanged(partEndingAt(double.nan), window), isTrue);
    });
  });
}
