import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/percentile.dart';
import 'package:butterscope/src/refresh_rate.dart';

/// The gate metrics for one window of frames, such as a span or an episode.
///
/// Every value comes from the frames and the budget alone, so the same
/// frames always give the same metrics. Counts are 0 for an empty window;
/// values that need a frame are `null`. The definitions are in
/// `docs/DESIGN.md` and `docs/decisions/0001-metric-definitions.md`.
final class WindowMetrics {
  /// Computes the metrics for [frames], in frame order, against [budget].
  factory of(List<FrameSample> frames, FrameBudget budget) {
    final judged = [for (final frame in frames) ClassifiedFrame(frame, budget)];
    int count(bool Function(ClassifiedFrame) test) => judged.where(test).length;

    var hitchMicros = 0.0;
    for (final frame in judged) {
      if (frame.overrunMicros > 0) hitchMicros += frame.overrunMicros;
    }
    final hitchMillis = hitchMicros / Duration.microsecondsPerMillisecond;

    final builds = [for (final frame in judged) frame.buildMultiple];
    final rasters = [for (final frame in judged) frame.rasterMultiple];

    return WindowMetrics._(
      budget: budget,
      frameCount: frames.length,
      jankyCount: count((f) => f.frameClass.isAtLeast(FrameClass.janky)),
      severeCount: count((f) => f.frameClass.isAtLeast(FrameClass.severe)),
      stallCount: count((f) => f.frameClass.isAtLeast(FrameClass.stall)),
      uiJankyCount: count((f) => f.thread == JankThread.ui),
      rasterJankyCount: count((f) => f.thread == JankThread.raster),
      bothJankyCount: count((f) => f.thread == JankThread.both),
      buildP90: _percentile(builds, 90),
      buildP99: _percentile(builds, 99),
      worstBuild: _percentile(builds, 100),
      rasterP90: _percentile(rasters, 90),
      rasterP99: _percentile(rasters, 99),
      worstRaster: _percentile(rasters, 100),
      hitchMillis: hitchMillis,
      renderingMillis: frames.length * budget.millis + hitchMillis,
      observedRefreshRate: observeRefreshRate(frames, budget),
    );
  }

  const new _({
    required this.budget,
    required this.frameCount,
    required this.jankyCount,
    required this.severeCount,
    required this.stallCount,
    required this.uiJankyCount,
    required this.rasterJankyCount,
    required this.bothJankyCount,
    required this.buildP90,
    required this.buildP99,
    required this.worstBuild,
    required this.rasterP90,
    required this.rasterP99,
    required this.worstRaster,
    required this.hitchMillis,
    required this.renderingMillis,
    required this.observedRefreshRate,
  });

  /// The budget the frames were judged against.
  final FrameBudget budget;

  /// The number of frames in the window.
  final int frameCount;

  /// Frames over budget on either thread, severe frames and stalls included.
  final int jankyCount;

  /// Frames over twice the budget, stalls included.
  final int severeCount;

  /// Severe frames of 100 ms or more.
  final int stallCount;

  /// Janky frames that were late on the UI thread only.
  final int uiJankyCount;

  /// Janky frames that were late on the raster thread only.
  final int rasterJankyCount;

  /// Janky frames that were late on both threads.
  final int bothJankyCount;

  /// The 90th percentile build time, as a multiple of the budget.
  final double? buildP90;

  /// The 99th percentile build time, as a multiple of the budget.
  final double? buildP99;

  /// The longest build time, as a multiple of the budget.
  final double? worstBuild;

  /// The 90th percentile raster time, as a multiple of the budget.
  final double? rasterP90;

  /// The 99th percentile raster time, as a multiple of the budget.
  final double? rasterP99;

  /// The longest raster time, as a multiple of the budget.
  final double? worstRaster;

  /// Total lateness in milliseconds: the sum of every positive overrun.
  final double hitchMillis;

  /// Time spent drawing in milliseconds: frame count × budget plus
  /// [hitchMillis]. Idle time between frames is not included.
  final double renderingMillis;

  /// The refresh rate the frames were drawn at, in hertz, or `null` when it
  /// cannot be observed. See [observeRefreshRate].
  final double? observedRefreshRate;

  /// Janky frames as a share of all frames, from 0 to 1.
  double? get jankyRate => _share(jankyCount);

  /// Milliseconds of lateness per second of rendering: the headline metric.
  double? get hitchRatio {
    if (renderingMillis == 0) return null;
    return hitchMillis * Duration.millisecondsPerSecond / renderingMillis;
  }

  /// Janky frames late on [thread] as a share of all frames, from 0 to 1.
  double? jankyRateOn(JankThread thread) {
    final count = switch (thread) {
      JankThread.ui => uiJankyCount,
      JankThread.raster => rasterJankyCount,
      JankThread.both => bothJankyCount,
    };
    return _share(count);
  }

  double? _share(int count) => frameCount == 0 ? null : count / frameCount;

  static double? _percentile(List<double> values, int percent) {
    return values.isEmpty ? null : nearestRankPercentile(values, percent);
  }
}
