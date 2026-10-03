import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// The 10-frame example at 60 Hz, as (build µs, raster µs).
const List<(int, int)> tenFrames = [
  (6000, 5000), // smooth
  (7000, 6000), // smooth
  (20000, 8000), // janky: UI thread, 1.2 B
  (9000, 22000), // janky: raster thread, 1.32 B
  (8000, 7000), // smooth
  (40000, 12000), // severe: UI thread, 2.4 B
  (7000, 6000), // smooth
  (283333, 10000), // stall: UI thread, 17.0 B
  (6000, 5000), // smooth
  (7000, 6000), // smooth
];

/// The class of a frame that took [buildMicros] on the UI thread.
FrameClass classOf(int buildMicros, FrameBudget budget) {
  final sample = FrameSample(
    vsyncStartMicros: 0,
    buildMicros: buildMicros,
    rasterMicros: 0,
  );
  return ClassifiedFrame(sample, budget).frameClass;
}

/// Frames from (build µs, raster µs) pairs, [gapMicros] apart.
List<FrameSample> samples(List<(int, int)> times, {int gapMicros = 16667}) {
  return [
    for (var i = 0; i < times.length; i++)
      FrameSample(
        vsyncStartMicros: i * gapMicros,
        buildMicros: times[i].$1,
        rasterMicros: times[i].$2,
      ),
  ];
}

void main() {
  final budget = FrameBudget(60);

  group('the 10-frame example at 60 Hz', () {
    final metrics = WindowMetrics.of(samples(tenFrames), budget);

    test('is 40% janky, with 2 severe frames and 1 stall', () {
      expect(metrics.frameCount, 10);
      expect(metrics.jankyCount, 4);
      expect(metrics.jankyRate, 0.4);
      expect(metrics.severeCount, 2);
      expect(metrics.stallCount, 1);
    });

    test('has a worst build of 17.0 B', () {
      expect(metrics.worstBuild, closeTo(17, 0.05));
    });

    test('splits janky frames by thread', () {
      expect(metrics.uiJankyCount, 3);
      expect(metrics.rasterJankyCount, 1);
      expect(metrics.bothJankyCount, 0);
      expect(metrics.jankyRateOn(JankThread.ui), 0.3);
      expect(metrics.jankyRateOn(JankThread.raster), 0.1);
      expect(metrics.jankyRateOn(JankThread.both), 0);
    });

    test('reports percentiles as multiples of B', () {
      expect(metrics.buildP90, closeTo(2.4, 0.001));
      expect(metrics.buildP99, closeTo(17, 0.001));
      expect(metrics.rasterP90, closeTo(0.72, 0.001));
      expect(metrics.rasterP99, closeTo(1.32, 0.001));
      expect(metrics.worstRaster, closeTo(1.32, 0.001));
    });

    test('has a hitch ratio of about 642 ms/s', () {
      expect(metrics.hitchMillis, closeTo(298.666, 0.001));
      expect(metrics.renderingMillis, closeTo(465.333, 0.001));
      expect(metrics.hitchRatio, closeTo(641.83, 0.01));
    });

    test('observes 60 Hz', () {
      expect(metrics.observedRefreshRate, closeTo(60, 0.01));
    });
  });

  group('an empty window', () {
    final metrics = WindowMetrics.of(const [], budget);

    test('counts nothing', () {
      expect(metrics.frameCount, 0);
      expect(metrics.jankyCount, 0);
      expect(metrics.severeCount, 0);
      expect(metrics.stallCount, 0);
      expect(metrics.hitchMillis, 0);
      expect(metrics.renderingMillis, 0);
    });

    test('has no rates, percentiles or hitch ratio', () {
      expect(metrics.jankyRate, isNull);
      expect(metrics.jankyRateOn(JankThread.ui), isNull);
      expect(metrics.buildP90, isNull);
      expect(metrics.buildP99, isNull);
      expect(metrics.worstBuild, isNull);
      expect(metrics.rasterP90, isNull);
      expect(metrics.rasterP99, isNull);
      expect(metrics.worstRaster, isNull);
      expect(metrics.hitchRatio, isNull);
      expect(metrics.observedRefreshRate, isNull);
    });
  });

  test('one smooth frame', () {
    final metrics = WindowMetrics.of(samples(const [(8000, 4000)]), budget);
    expect(metrics.frameCount, 1);
    expect(metrics.jankyRate, 0);
    expect(metrics.buildP90, closeTo(0.48, 0.001));
    expect(metrics.buildP99, closeTo(0.48, 0.001));
    expect(metrics.worstBuild, closeTo(0.48, 0.001));
    expect(metrics.hitchRatio, 0);
    expect(metrics.observedRefreshRate, isNull);
  });

  test('one stall', () {
    final metrics = WindowMetrics.of(samples(const [(150000, 4000)]), budget);
    expect(metrics.jankyCount, 1);
    expect(metrics.severeCount, 1);
    expect(metrics.stallCount, 1);
    expect(metrics.jankyRate, 1);
    expect(metrics.hitchRatio, closeTo(888.889, 0.001));
  });

  group('one threshold on every screen', () {
    // A 10 ms frame and a 15 ms frame, judged at each refresh rate.
    const cases = [
      (60, FrameClass.smooth, FrameClass.smooth),
      (90, FrameClass.smooth, FrameClass.janky),
      (120, FrameClass.janky, FrameClass.janky),
      (144, FrameClass.janky, FrameClass.severe),
    ];

    for (final (rate, at10ms, at15ms) in cases) {
      test('$rate Hz', () {
        final budget = FrameBudget(rate.toDouble());
        expect(classOf(10000, budget), at10ms);
        expect(classOf(15000, budget), at15ms);
      });

      test('$rate Hz, all smooth', () {
        final budget = FrameBudget(rate.toDouble());
        final smooth = (budget.micros * 0.9).round();
        final frames = samples(List.filled(20, (smooth, smooth)));
        final metrics = WindowMetrics.of(frames, budget);
        expect(metrics.jankyCount, 0);
        expect(metrics.jankyRate, 0);
        expect(metrics.hitchRatio, 0);
        expect(metrics.worstBuild, closeTo(0.9, 0.001));
      });

      test('$rate Hz, all stalls', () {
        final budget = FrameBudget(rate.toDouble());
        final frames = samples(List.filled(20, (120000, 5000)));
        final metrics = WindowMetrics.of(frames, budget);
        expect(metrics.jankyCount, 20);
        expect(metrics.severeCount, 20);
        expect(metrics.stallCount, 20);
        expect(metrics.jankyRate, 1);
        expect(metrics.uiJankyCount, 20);
      });
    }
  });

  test('idle time between frames does not change the hitch ratio', () {
    final idleFrames = samples(tenFrames, gapMicros: 500000);
    final busy = WindowMetrics.of(samples(tenFrames), budget);
    final idle = WindowMetrics.of(idleFrames, budget);
    expect(idle.hitchRatio, busy.hitchRatio);
    expect(idle.renderingMillis, busy.renderingMillis);
  });
}
