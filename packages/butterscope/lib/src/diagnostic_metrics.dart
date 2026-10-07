import 'dart:math' as math;

import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/percentile.dart';

/// The diagnostic metrics for one window of frames: recorded beside the
/// gate metrics to explain them, never gated (`docs/DESIGN.md` section 5).
///
/// Times are in milliseconds, not multiples of the budget, because they are
/// read by people looking for a cause: a 6 ms average build is the same
/// work on any screen. Every value is `null` for an empty window.
final class DiagnosticMetrics {
  /// Computes the diagnostics for [frames].
  factory of(List<FrameSample> frames) {
    if (frames.isEmpty) return const DiagnosticMetrics._empty();

    double average(int Function(FrameSample) micros) {
      final total = frames.fold(0, (sum, frame) => sum + micros(frame));
      return total / frames.length / Duration.microsecondsPerMillisecond;
    }

    final overheads = [for (final f in frames) f.vsyncOverheadMicros]..sort();
    final spans = [for (final f in frames) f.totalSpanMicros]..sort();

    int largest(int Function(RasterCacheUse) value) {
      return frames.map((frame) => value(frame.rasterCache)).reduce(math.max);
    }

    return DiagnosticMetrics._(
      averageUiMillis: average((frame) => frame.uiMicros),
      averageBuildMillis: average((frame) => frame.buildMicros),
      averageRasterMillis: average((frame) => frame.rasterMicros),
      vsyncOverheadP90Millis: _millisAt(overheads, 90),
      vsyncOverheadP99Millis: _millisAt(overheads, 99),
      totalSpanP90Millis: _millisAt(spans, 90),
      totalSpanP99Millis: _millisAt(spans, 99),
      peakRasterCache: RasterCacheUse(
        layerCount: largest((cache) => cache.layerCount),
        layerBytes: largest((cache) => cache.layerBytes),
        pictureCount: largest((cache) => cache.pictureCount),
        pictureBytes: largest((cache) => cache.pictureBytes),
      ),
    );
  }

  const new _({
    required this.averageUiMillis,
    required this.averageBuildMillis,
    required this.averageRasterMillis,
    required this.vsyncOverheadP90Millis,
    required this.vsyncOverheadP99Millis,
    required this.totalSpanP90Millis,
    required this.totalSpanP99Millis,
    required this.peakRasterCache,
  });

  const new _empty()
    : averageUiMillis = null,
      averageBuildMillis = null,
      averageRasterMillis = null,
      vsyncOverheadP90Millis = null,
      vsyncOverheadP99Millis = null,
      totalSpanP90Millis = null,
      totalSpanP99Millis = null,
      peakRasterCache = null;

  /// The mean UI time: the wait for the UI thread plus the build.
  final double? averageUiMillis;

  /// The mean build time, without the wait before it.
  final double? averageBuildMillis;

  /// The mean raster time.
  final double? averageRasterMillis;

  /// The 90th percentile wait for the UI thread after the vsync. Tells a
  /// busy UI thread apart from a slow build.
  final double? vsyncOverheadP90Millis;

  /// The 99th percentile wait for the UI thread after the vsync.
  final double? vsyncOverheadP99Millis;

  /// The 90th percentile time from the vsync to the end of rasterising:
  /// latency, for example from a price tick to the pixels.
  final double? totalSpanP90Millis;

  /// The 99th percentile time from the vsync to the end of rasterising.
  final double? totalSpanP99Millis;

  /// The most the raster cache held in any frame, field by field. Each
  /// field's peak can come from a different frame.
  final RasterCacheUse? peakRasterCache;

  /// The nearest-rank percentile of [sortedMicros], in milliseconds.
  static double _millisAt(List<int> sortedMicros, int percent) {
    final micros = nearestRankOfSorted(sortedMicros, percent);
    return micros / Duration.microsecondsPerMillisecond;
  }
}
