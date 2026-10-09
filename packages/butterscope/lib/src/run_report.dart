import 'package:butterscope/src/activity.dart';
import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/diagnostic_metrics.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/marks.dart';
import 'package:butterscope/src/recorded_window.dart';
import 'package:butterscope/src/window_metrics.dart';
import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;

/// The report of one run: what M5 prints after the last test.
///
/// The schema is provisional (version 0). M7 freezes version 1 and the way
/// it leaves the phone (`docs/DESIGN.md` section 8).
final class RunReport {
  /// Builds the report of [window], split into [parts], with the
  /// [activities] and [pages] that episodes were split on.
  new(
    this.window,
    this.parts, {
    this.activities = const [],
    this.pages = const [],
  });

  /// The provisional schema's version.
  static const int schemaVersion = 0;

  /// The run's whole recording.
  final RecordedWindow window;

  /// The tests, spans and episodes, in the order they ended.
  final List<MarkedPart> parts;

  /// The activity recorded during the run.
  final List<Activity> activities;

  /// The page changes recorded during the run.
  final List<PageChange> pages;

  /// The report as JSON-ready maps and lists.
  ///
  /// Each part reports its declared refresh rate at its start and its end,
  /// and its gate and diagnostic metrics against the budget its start
  /// declared. A part whose starting rate cannot give a budget has no
  /// metrics; M6's guards make it `INVALID`. A rate that is not finite is
  /// written as `null`, because JSON has no NaN or infinity.
  ///
  /// The activity and page changes go in too, as lists of
  /// `[kind, startFrame, startMicros, endFrame, endMicros]` and
  /// `[frame, micros, page, cuts]`, so a reader can split the tests again
  /// by another rule.
  Map<String, Object?> toJson() {
    return {
      'schema': schemaVersion,
      'buildMode': _buildMode,
      'frames': window.samples.length,
      'flushTimedOut': window.flushTimedOut,
      'flushMicros': window.flushMicros,
      'callbackMicros': window.callbackMicros,
      'parts': [for (final part in parts) _partJson(part)],
      'activity': [
        for (final Activity(:kind, :start, :end) in activities)
          [
            kind.name,
            start.frameNumber,
            start.micros,
            end.frameNumber,
            end.micros,
          ],
      ],
      'pages': [
        for (final PageChange(:at, :page, :cuts) in pages)
          [at.frameNumber, at.micros, page, cuts],
      ],
    };
  }

  Map<String, Object?> _partJson(MarkedPart part) {
    final frames = window.samplesBetween(part.start, part.end);
    final hertz = part.start.declaredRefreshRate;
    final valid = FrameBudget.isValidRefreshRate(hertz);
    return {
      'kind': part.kind.name,
      'name': part.name,
      'test': ?part.test,
      'page': ?part.page,
      'startFrame': part.start.frameNumber,
      'endFrame': part.end.frameNumber,
      'startMicros': part.start.micros,
      'endMicros': part.end.micros,
      'declaredHz': _finiteOrNull(hertz),
      'declaredHzAtEnd': _finiteOrNull(part.end.declaredRefreshRate),
      'frames': frames.length,
      if (valid)
        'metrics': _gateJson(WindowMetrics.of(frames, FrameBudget(hertz))),
      'diagnostics': _diagnosticJson(DiagnosticMetrics.of(frames)),
    };
  }
}

double? _finiteOrNull(double hertz) => hertz.isFinite ? hertz : null;

String get _buildMode {
  if (kReleaseMode) return 'release';
  if (kProfileMode) return 'profile';
  return 'debug';
}

Map<String, Object?> _gateJson(WindowMetrics metrics) {
  return {
    'observedHz': metrics.observedRefreshRate,
    'hitchRatio': metrics.hitchRatio,
    'hitchMs': metrics.hitchMillis,
    'renderingMs': metrics.renderingMillis,
    'missedVsyncs': metrics.missedVsyncCount,
    'missedVsyncMs': metrics.missedVsyncMillis,
    'janky': metrics.jankyCount,
    'jankyRate': metrics.jankyRate,
    'jankyRateUi': metrics.jankyRateOn(JankThread.ui),
    'jankyRateRaster': metrics.jankyRateOn(JankThread.raster),
    'jankyRateBoth': metrics.jankyRateOn(JankThread.both),
    'severe': metrics.severeCount,
    'stalls': metrics.stallCount,
    'uiP90B': metrics.uiP90,
    'uiP99B': metrics.uiP99,
    'worstUiB': metrics.worstUi,
    'rasterP90B': metrics.rasterP90,
    'rasterP99B': metrics.rasterP99,
    'worstRasterB': metrics.worstRaster,
  };
}

Map<String, Object?> _diagnosticJson(DiagnosticMetrics metrics) {
  final cache = metrics.peakRasterCache;
  return {
    'avgUiMs': metrics.averageUiMillis,
    'avgBuildMs': metrics.averageBuildMillis,
    'avgRasterMs': metrics.averageRasterMillis,
    'vsyncOverheadP90Ms': metrics.vsyncOverheadP90Millis,
    'vsyncOverheadP99Ms': metrics.vsyncOverheadP99Millis,
    'totalSpanP90Ms': metrics.totalSpanP90Millis,
    'totalSpanP99Ms': metrics.totalSpanP99Millis,
    if (cache != null)
      'rasterCachePeak': {
        'layers': cache.layerCount,
        'layerBytes': cache.layerBytes,
        'pictures': cache.pictureCount,
        'pictureBytes': cache.pictureBytes,
      },
  };
}
