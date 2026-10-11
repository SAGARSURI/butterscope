import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Timestamp jitter in microseconds, repeated in this order.
const List<int> jitter = [-40, 30, -10, 50, 0, -30, 20, -50, 40, -20];

/// Frames whose vsyncs are [gaps] microseconds apart, each with the matching
/// build time from [builds], or 2 ms when [builds] is shorter.
List<FrameSample> framesWithGaps(
  List<int> gaps, {
  List<int> builds = const [],
}) {
  final vsyncs = [0];
  for (final gap in gaps) {
    vsyncs.add(vsyncs.last + gap);
  }
  return [
    for (var i = 0; i < vsyncs.length; i++)
      FrameSample(
        vsyncStartMicros: vsyncs[i],
        buildMicros: i < builds.length ? builds[i] : 2000,
        rasterMicros: 1000,
      ),
  ];
}

/// [count] gaps at [rate] hertz, with jitter, and every 25th gap doubled.
List<int> gapsAt(double rate, int count) {
  final interval = (Duration.microsecondsPerSecond / rate).round();
  return [
    for (var i = 0; i < count; i++)
      (i % 25 == 24 ? 2 * interval : interval) + jitter[i % jitter.length],
  ];
}

void main() {
  group('observeRefreshRate', () {
    for (final rate in <double>[60, 90, 120, 144]) {
      test('reads $rate Hz from jittered gaps', () {
        final frames = framesWithGaps(gapsAt(rate, 300));
        final observed = observeRefreshRate(frames, FrameBudget(rate));
        expect(observed, closeTo(rate, 0.5));
      });
    }

    test('ignores the gap after a janky frame', () {
      // At 120 Hz, 7 frames in 10 take 12 ms and push the next vsync back by
      // a whole interval. The mode of all gaps would read 60 Hz.
      int buildAt(int i) => i % 10 < 7 ? 12000 : 2000;
      final builds = List.generate(200, buildAt);
      final gaps = builds.map((b) => b > 8333 ? 16667 : 8333).toList();
      final frames = framesWithGaps(gaps, builds: builds);
      final observed = observeRefreshRate(frames, FrameBudget(120));
      expect(observed, closeTo(120, 0.5));
    });

    test('catches a screen running slower than declared', () {
      final frames = framesWithGaps(gapsAt(60, 100));
      final observed = observeRefreshRate(frames, FrameBudget(120));
      expect(observed, closeTo(60, 0.5));
    });

    test('ignores pauses of 100 ms or more', () {
      // Five pauses outnumber three real gaps; counted, they would win.
      final gaps = [...List.filled(5, 100000), 11111, 11111, 11111];
      final frames = framesWithGaps(gaps);
      expect(observeRefreshRate(frames, FrameBudget(90)), closeTo(90, 0.01));
    });

    test('counts a gap just under 100 ms but not one of exactly 100 ms', () {
      final budget = FrameBudget(60);
      final under = observeRefreshRate(framesWithGaps([99999]), budget);
      expect(under, closeTo(10, 0.001));
      expect(observeRefreshRate(framesWithGaps([100000]), budget), isNull);
    });

    test('ignores gaps of zero or less', () {
      final frames = framesWithGaps([0, 0, 0, -10, 16667, 16667]);
      expect(observeRefreshRate(frames, FrameBudget(60)), closeTo(60, 0.01));
    });

    test('takes the median of the winning group, not the mean', () {
      // All five gaps are within 5% of 10000 µs. The median is 10000 µs
      // (100 Hz); the mean, 10160 µs, would read 98.4 Hz.
      final frames = framesWithGaps([10000, 10000, 10000, 10400, 10400]);
      expect(observeRefreshRate(frames, FrameBudget(60)), 100);
    });

    test('follows the requests when frames are drawn on demand', () {
      // Outside a test, updates every 33 ms on a 120 Hz screen read 30 Hz.
      // Under benchmarkLive frames run back to back, so this cannot happen
      // during a run.
      final frames = framesWithGaps(List.filled(50, 33333));
      expect(observeRefreshRate(frames, FrameBudget(120)), closeTo(30, 0.01));
    });

    test('gives ties to the shorter gap', () {
      final frames = framesWithGaps([10000, 10000, 20000, 20000]);
      expect(observeRefreshRate(frames, FrameBudget(60)), 100);
    });

    test('is null with no usable gap', () {
      final budget = FrameBudget(60);
      expect(observeRefreshRate(const [], budget), isNull);
      expect(observeRefreshRate(framesWithGaps([]), budget), isNull);
      expect(observeRefreshRate(framesWithGaps([150000]), budget), isNull);
      final allJanky = framesWithGaps([33333], builds: [30000, 30000]);
      expect(observeRefreshRate(allJanky, budget), isNull);
    });
  });

  group('judgeRateSlices', () {
    test('cuts a steady part into one-second slices with no mismatch', () {
      // 300 gaps of 8333 µs: frame k's vsync is k × 8333 µs. Slice 0 holds
      // frames 0 to 120 (120 × 8333 = 999 960), slice 1 frames 121 to 240
      // (240 × 8333 = 1 999 920), slice 2 frames 241 to 299; frame 300 is
      // last and has no gap after it. So 121, 120 and 59 gaps.
      final frames = framesWithGaps(List.filled(300, 8333));
      final slices = judgeRateSlices(frames, FrameBudget(120));
      expect([for (final s in slices) s.index], [0, 1, 2]);
      expect([for (final s in slices) s.gapCount], [121, 120, 59]);
      for (final slice in slices) {
        // 1 000 000 ÷ 8333 = 120.005 Hz, 0.004% off.
        expect(slice.observedRefreshRate, closeTo(120.005, 0.001));
        expect(slice.declaredRefreshRate, 120);
        expect(slice.isMismatch, isFalse);
      }
    });

    test('flags the second in which the screen dropped to 60 Hz', () {
      // Frames 0 to 120 at 8333 µs fill slice 0; frame 120's vsync is
      // 999 960 and its gap, 16 667 µs, is the first at 60 Hz. Slice 0 has
      // 120 gaps of 8333 and that one, so its mode stays 120 Hz. Frames 121
      // to 180 sit at 999 960 + j × 16 667 for j = 1 to 60, the last at
      // 1 999 980, so slice 1 holds them and the 59 gaps after 121 to 179:
      // 1 000 000 ÷ 16 667 = 59.999 Hz, 50% under the declared 120.
      final gaps = [...List.filled(120, 8333), ...List.filled(60, 16667)];
      final slices = judgeRateSlices(framesWithGaps(gaps), FrameBudget(120));
      expect([for (final s in slices) s.gapCount], [121, 59]);
      expect(slices[0].isMismatch, isFalse);
      expect(slices[1].isMismatch, isTrue);
      expect(slices[1].observedRefreshRate, closeTo(59.999, 0.001));
    });

    test('judges a slice only from 10 gaps, which take 11 frames', () {
      final budget = FrameBudget(60);
      final nine = framesWithGaps(List.filled(9, 16667));
      expect(judgeRateSlices(nine, budget), isEmpty);
      final eleven = framesWithGaps(List.filled(10, 16667));
      final ten = judgeRateSlices(eleven, budget);
      expect(ten.single.gapCount, 10);
    });

    test('judges nothing when every frame is janky', () {
      // Builds of 30 ms are over the 16.67 ms budget, so no gap qualifies.
      final frames = framesWithGaps(
        List.filled(60, 33333),
        builds: List.filled(61, 30000),
      );
      expect(judgeRateSlices(frames, FrameBudget(60)), isEmpty);
      expect(judgeRateSlices(const [], FrameBudget(60)), isEmpty);
    });

    test('flags a rate more than 5% off the declared one, not exactly 5%', () {
      RateSlice at(double observed) {
        return RateSlice(
          index: 0,
          gapCount: 10,
          observedRefreshRate: observed,
          declaredRefreshRate: 100,
        );
      }

      // 5% of 100 Hz is 5 Hz: 95 and 105 are on the edge and pass.
      expect(at(95).isMismatch, isFalse);
      expect(at(105).isMismatch, isFalse);
      expect(at(94.9).isMismatch, isTrue);
      expect(at(105.1).isMismatch, isTrue);
    });
  });
}
