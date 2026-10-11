import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Frames 1 to 6, 8000 µs apart. The part holds frames 3 and 4, and is
  // open from 16 000 µs to 32 000 µs.
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
      const FrameMark(frameNumber: 2, declaredRefreshRate: 125, micros: 16000),
      FrameMark(frameNumber: 4, declaredRefreshRate: endHz, micros: 32000),
    );
  }

  group('declaredRateChanged', () {
    test('sees a read taken while the span was open', () {
      final window = windowWith(const [
        RefreshRateRead(hertz: 60, afterSamples: 3, micros: 24000),
      ]);
      expect(declaredRateChanged(partEndingAt(125), window), isTrue);
    });

    test('ignores reads taken before or after the span, or with no time', () {
      // The read after the span came before any later timing, so it sits
      // after the part's last timing, as a read inside the part could.
      final window = windowWith(const [
        RefreshRateRead(hertz: 60, afterSamples: 2, micros: 15999),
        RefreshRateRead(hertz: 60, afterSamples: 4, micros: 32001),
        RefreshRateRead(hertz: 60, afterSamples: 3),
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
