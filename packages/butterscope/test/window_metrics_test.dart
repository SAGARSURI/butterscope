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

    test('has a worst UI time of 17.0 B', () {
      expect(metrics.worstUi, closeTo(17, 0.05));
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
      expect(metrics.uiP90, closeTo(2.4, 0.001));
      expect(metrics.uiP99, closeTo(17, 0.001));
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
      expect(metrics.uiP90, isNull);
      expect(metrics.uiP99, isNull);
      expect(metrics.worstUi, isNull);
      expect(metrics.rasterP90, isNull);
      expect(metrics.rasterP99, isNull);
      expect(metrics.worstRaster, isNull);
      expect(metrics.hitchRatio, isNull);
      expect(metrics.observedRefreshRate, isNull);
      expect(metrics.missedVsyncCount, 0);
    });
  });

  test('counts frames lost to UI work queued before the frame request', () {
    // At 120 Hz, a decode queued before the next frame request holds it
    // back until the vsync at 50 ms, four intervals after the last frame.
    // Every frame starts on time and looks smooth, but three vsyncs pass
    // with no frame.
    const vsyncs = [0, 8333, 16667, 50000, 58333];
    final frames = [
      for (final vsync in vsyncs)
        FrameSample(
          vsyncStartMicros: vsync,
          buildMicros: 2000,
          rasterMicros: 1000,
        ),
    ];
    final metrics = WindowMetrics.of(frames, FrameBudget(120));
    expect(metrics.jankyCount, 0);
    expect(metrics.missedVsyncCount, 3);
    expect(metrics.missedVsyncMillis, closeTo(25, 0.001));
    // No frame was late, so the missed vsyncs are the whole hitch time.
    expect(metrics.hitchMillis, closeTo(25, 0.001));
  });

  test('counts an app that misses every other vsync in the hitch ratio', () {
    // At 120 Hz, every frame renders well within B, but the app misses
    // every other vsync, so frames land 16.7 ms apart as on a 60 Hz screen.
    // Every frame is smooth, so the janky rate reads zero; the hitch ratio
    // sees the frames that never happened through the missed vsyncs.
    final frames = samples(List.filled(11, (2000, 1000)));
    final metrics = WindowMetrics.of(frames, FrameBudget(120));
    expect(metrics.jankyCount, 0);
    expect(metrics.missedVsyncCount, 10);
    expect(metrics.missedVsyncMillis, closeTo(83.333, 0.001));
    // Hitch time 10 × 8.333 = 83.333 ms; rendering time
    // 11 × 8.333 + 83.333 = 175 ms; 83.333 ÷ 0.175 s = 476.19 ms/s.
    expect(metrics.hitchMillis, closeTo(83.333, 0.001));
    expect(metrics.renderingMillis, closeTo(175, 0.001));
    expect(metrics.hitchRatio, closeTo(476.19, 0.01));
    expect(metrics.observedRefreshRate, closeTo(60, 0.01));
  });

  test('counts each janky frame under exactly one thread', () {
    // At 60 Hz: one frame late on each thread alone, one late on both, and
    // one smooth frame.
    const times = [(20000, 8000), (8000, 20000), (20000, 20000), (8000, 8000)];
    final metrics = WindowMetrics.of(samples(times), budget);
    expect(metrics.jankyCount, 3);
    expect(metrics.uiJankyCount, 1);
    expect(metrics.rasterJankyCount, 1);
    expect(metrics.bothJankyCount, 1);
    expect(metrics.jankyRateOn(JankThread.ui), 0.25);
    expect(metrics.jankyRateOn(JankThread.raster), 0.25);
    expect(metrics.jankyRateOn(JankThread.both), 0.25);
  });

  test('counts a frame that waited for the UI thread as UI lateness', () {
    // At 60 Hz, a 30 ms wait (work outside the frame) before a 2 ms build.
    const waited = FrameSample(
      vsyncStartMicros: 0,
      buildMicros: 2000,
      rasterMicros: 2000,
      vsyncOverheadMicros: 30000,
    );
    final metrics = WindowMetrics.of(const [waited], budget);
    expect(metrics.jankyCount, 1);
    expect(metrics.uiJankyCount, 1);
    expect(metrics.worstUi, closeTo(1.92, 0.001));
    expect(metrics.hitchMillis, closeTo(15.333, 0.001));
  });

  test('one smooth frame', () {
    final metrics = WindowMetrics.of(samples(const [(8000, 4000)]), budget);
    expect(metrics.frameCount, 1);
    expect(metrics.jankyRate, 0);
    expect(metrics.uiP90, closeTo(0.48, 0.001));
    expect(metrics.uiP99, closeTo(0.48, 0.001));
    expect(metrics.worstUi, closeTo(0.48, 0.001));
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
        final frames = samples(
          List.filled(20, (smooth, smooth)),
          gapMicros: budget.micros.round(),
        );
        final metrics = WindowMetrics.of(frames, budget);
        expect(metrics.jankyCount, 0);
        expect(metrics.jankyRate, 0);
        expect(metrics.hitchRatio, 0);
        expect(metrics.worstUi, closeTo(0.9, 0.001));
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

  test('counts a freeze between smooth frames in the hitch time', () {
    // At 60 Hz, two smooth frames 300 ms apart: 18 intervals, so 17 vsyncs
    // had no frame. Hitch time 17 × 16.667 = 283.333 ms; rendering time
    // 2 × 16.667 + 283.333 = 316.667 ms; 283.333 ÷ 0.316667 s = 894.74 ms/s.
    const smooth = [(2000, 1000), (2000, 1000)];
    final metrics = WindowMetrics.of(
      samples(smooth, gapMicros: 300000),
      budget,
    );
    expect(metrics.jankyCount, 0);
    expect(metrics.missedVsyncCount, 17);
    expect(metrics.hitchMillis, closeTo(283.333, 0.001));
    expect(metrics.renderingMillis, closeTo(316.667, 0.001));
    expect(metrics.hitchRatio, closeTo(894.74, 0.01));
  });
}
