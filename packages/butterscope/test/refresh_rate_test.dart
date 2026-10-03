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
      final gaps = [...gapsAt(90, 50), 100000, 250000, ...gapsAt(90, 50)];
      final frames = framesWithGaps(gaps);
      expect(observeRefreshRate(frames, FrameBudget(90)), closeTo(90, 0.5));
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
}
