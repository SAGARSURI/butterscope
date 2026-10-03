import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/missed_vsyncs.dart';
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
    final classes = [for (final frame in judged) frame.frameClass];
    final threads = [for (final frame in judged) frame.thread];

    int countAtLeast(FrameClass floor) {
      return classes.where((c) => c.isAtLeast(floor)).length;
    }

    int countOn(JankThread thread) {
      return threads.where((t) => t == thread).length;
    }

    var hitchMicros = 0.0;
    for (final frame in judged) {
      if (frame.overrunMicros > 0) hitchMicros += frame.overrunMicros;
    }
    final hitchMillis = hitchMicros / Duration.microsecondsPerMillisecond;

    // Sorted once; every percentile reads from these.
    final uis = [for (final frame in judged) frame.uiMultiple]..sort();
    final rasters = [for (final frame in judged) frame.rasterMultiple]..sort();

    return WindowMetrics._(
      budget: budget,
      frameCount: frames.length,
      jankyCount: countAtLeast(FrameClass.janky),
      severeCount: countAtLeast(FrameClass.severe),
      stallCount: countAtLeast(FrameClass.stall),
      uiJankyCount: countOn(JankThread.ui),
      rasterJankyCount: countOn(JankThread.raster),
      bothJankyCount: countOn(JankThread.both),
      missedVsyncCount: countMissedVsyncs(frames, budget),
      uiP90: _percentile(uis, 90),
      uiP99: _percentile(uis, 99),
      worstUi: _percentile(uis, 100),
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
    required this.missedVsyncCount,
    required this.uiP90,
    required this.uiP99,
    required this.worstUi,
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

  /// Vsyncs that passed with no frame between the window's frames. See
  /// [countMissedVsyncs].
  ///
  /// Catches what per-frame times cannot: work queued on the UI thread
  /// before a frame was requested delays the request itself, so the next
  /// frame starts on time and looks smooth, and only the missing frames
  /// show.
  final int missedVsyncCount;

  /// The 90th percentile UI time (wait plus build), as a multiple of the
  /// budget.
  final double? uiP90;

  /// The 99th percentile UI time (wait plus build), as a multiple of the
  /// budget.
  final double? uiP99;

  /// The longest UI time (wait plus build), as a multiple of the budget.
  final double? worstUi;

  /// The 90th percentile raster time, as a multiple of the budget.
  final double? rasterP90;

  /// The 99th percentile raster time, as a multiple of the budget.
  final double? rasterP99;

  /// The longest raster time, as a multiple of the budget.
  final double? worstRaster;

  /// Total lateness in milliseconds: the sum of every positive overrun.
  final double hitchMillis;

  /// Time spent drawing in milliseconds: frame count × budget plus
  /// [hitchMillis]. During a test frames run back to back, so this is close
  /// to the window's wall-clock length.
  final double renderingMillis;

  /// The most common frame interval in the window, as a rate in hertz, or
  /// `null` when it cannot be observed. See [observeRefreshRate].
  ///
  /// It equals the screen's refresh rate while frames run back to back,
  /// which they always do during a test under `benchmarkLive`.
  final double? observedRefreshRate;

  /// Janky frames as a share of all frames, from 0 to 1.
  double? get jankyRate => _share(jankyCount);

  /// Milliseconds of lateness per second of rendering: the headline metric.
  ///
  /// Compare it with the same flow's baseline. During a test, idle time in
  /// the window still produces frames, which dilute the ratio; the hitch
  /// time and the counts are not diluted.
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

  static double? _percentile(List<double> sorted, int percent) {
    return sorted.isEmpty ? null : nearestRankOfSorted(sorted, percent);
  }
}
