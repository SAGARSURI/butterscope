import 'package:butterscope/src/activity.dart';
import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/diagnostic_metrics.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/guards.dart';
import 'package:butterscope/src/marks.dart';
import 'package:butterscope/src/recorded_window.dart';
import 'package:butterscope/src/run_identity.dart';
import 'package:butterscope/src/window_metrics.dart';

/// The report of one run: what is printed after the last test.
///
/// The schema is provisional (version 0). M7 freezes version 1 and the way
/// it leaves the phone (`docs/DESIGN.md` section 8).
final class RunReport {
  /// Builds the report of [window], split into [parts], with the
  /// [activities] and [pages] that episodes were split on, the run's
  /// [identity], and the run guards that [failures] lists.
  new(
    this.window,
    this.parts, {
    required this.identity,
    this.failures = const [],
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

  /// What the run was measured on.
  final RunIdentity identity;

  /// The run guards that failed while it was recorded. [runFailures] adds
  /// those judged from the recording.
  final List<GuardFailure> failures;

  /// Every run guard that failed: [failures], and a declared rate of 0 or
  /// not finite anywhere in the recording, which leaves no budget to
  /// judge frames by (`docs/decisions/0001-metric-definitions.md` item 7).
  List<GuardFailure> get runFailures {
    final rates = [
      for (final read in window.refreshRateReads) read.hertz,
      for (final part in parts) ...[
        part.start.declaredRefreshRate,
        part.end.declaredRefreshRate,
      ],
    ];
    final invalid = rates.where(
      (hertz) => !FrameBudget.isValidRefreshRate(hertz),
    );
    return [
      ...failures,
      if (invalid.isNotEmpty)
        GuardFailure(Guard.declaredRate, 'recording', '${invalid.first}'),
    ];
  }

  /// The report as JSON-ready maps and lists.
  ///
  /// The run says whether it is valid, and lists the guards that failed as
  /// `[guard, at]` or `[guard, at, value]`. A failed run guard voids every
  /// span in it. Each span also says whether it is valid, lists its own
  /// failed guards, and says whether semantics was on at its start and
  /// end. Tests and episodes are never gated, so they carry no validity
  /// (`docs/DESIGN.md` section 7.1).
  ///
  /// Each part reports its declared refresh rate at its start and its end,
  /// and its gate and diagnostic metrics against the budget its start
  /// declared. A part whose starting rate cannot give a budget has no
  /// metrics, and its run is invalid. An episode whose declared rate moved
  /// says so instead of reporting metrics. A rate that is not finite is
  /// written as `null`, because JSON has no NaN or infinity.
  ///
  /// Its metrics include the rate-mismatch check: how many one-second
  /// slices had enough gaps to judge, and each mismatched slice as
  /// `[second, gaps, observedHz]`. No slice judged means the part was not
  /// checked.
  ///
  /// The activity and page changes go in too, as lists of
  /// `[kind, startFrame, startMicros, endFrame, endMicros]` and
  /// `[frame, micros, page, cuts]`, so a reader can split the tests again
  /// by another rule.
  Map<String, Object?> toJson() {
    final runFailures = this.runFailures;
    final runValid = runFailures.isEmpty;
    return {
      'schema': schemaVersion,
      'identity': identity.toJson(),
      'valid': runValid,
      'reasons': [for (final failure in runFailures) failure.toJson()],
      'frames': window.samples.length,
      'flushTimedOut': window.flushTimedOut,
      'flushMicros': window.flushMicros,
      'callbackMicros': window.callbackMicros,
      'parts': [for (final part in parts) _partJson(part, runValid: runValid)],
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

  Map<String, Object?> _partJson(MarkedPart part, {required bool runValid}) {
    final frames = window.samplesBetween(part.start, part.end);
    final hertz = part.start.declaredRefreshRate;
    final rateChanged =
        part.kind != PartKind.test && declaredRateChanged(part, window);
    final episodeMoved = part.kind == PartKind.episode && rateChanged;
    final metrics = FrameBudget.isValidRefreshRate(hertz) && !episodeMoved
        ? WindowMetrics.of(frames, FrameBudget(hertz))
        : null;
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
      'metrics': ?(metrics == null ? null : _gateJson(metrics)),
      if (episodeMoved) 'declaredRateChanged': true,
      'diagnostics': _diagnosticJson(DiagnosticMetrics.of(frames)),
      if (part.kind == PartKind.span)
        ..._spanJson(
          part,
          metrics,
          rateChanged: rateChanged,
          runValid: runValid,
        ),
    };
  }
}

/// A span's validity: the run's, plus the failures its recording saw, a
/// declared rate that moved inside it, and too few vsyncs. [metrics] is
/// `null` when the span has no budget to count vsyncs in; its run is then
/// void already.
Map<String, Object?> _spanJson(
  MarkedPart part,
  WindowMetrics? metrics, {
  required bool rateChanged,
  required bool runValid,
}) {
  // Rendering time is summed from a fractional budget, so a whole count can
  // come out a hair under: 2 frames and 9 missed vsyncs at 119.88 Hz give
  // 10.999999999999998. Rounding to a millionth of a vsync, under 10 ns,
  // puts it back without moving a real span across the line.
  final elapsedVsyncs = metrics == null
      ? null
      : (metrics.renderingMillis / metrics.budget.millis * 1e6).round() / 1e6;
  final failures = [
    ...part.failures,
    if (rateChanged)
      GuardFailure(
        Guard.declaredRateChange,
        'span',
        '${part.start.declaredRefreshRate} to '
            '${part.end.declaredRefreshRate}',
      ),
    if (elapsedVsyncs != null && elapsedVsyncs < minimumSpanVsyncs)
      GuardFailure(
        Guard.tooFewVsyncs,
        'span',
        elapsedVsyncs.toStringAsFixed(1),
      ),
  ];
  final semantics = part.semantics;
  return {
    'valid': runValid && failures.isEmpty,
    'reasons': [for (final failure in failures) failure.toJson()],
    'semantics': ?(semantics == null
        ? null
        : [semantics.atStart, semantics.atEnd]),
  };
}

double? _finiteOrNull(double hertz) => hertz.isFinite ? hertz : null;

Map<String, Object?> _gateJson(WindowMetrics metrics) {
  return {
    'observedHz': metrics.observedRefreshRate,
    'rateSlicesJudged': metrics.rateSlices.length,
    'rateMismatches': [
      for (final slice in metrics.rateMismatches)
        [slice.index, slice.gapCount, slice.observedRefreshRate],
    ],
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
