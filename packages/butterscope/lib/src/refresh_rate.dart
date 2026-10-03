import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/percentile.dart';

/// A gap between vsyncs this long or longer means rendering paused.
const int _pauseMicros = 100000;

/// Gaps within this fraction of each other count as the same interval.
const double _tolerance = 0.05;

/// The refresh rate [frames] were actually drawn at, in hertz.
///
/// Only meaningful while frames run back to back. Under the
/// `benchmarkLive` frame policy that Butterscope sets, the test binding
/// requests a new frame after every frame, so they always do during a test.
/// Outside a test, Flutter draws a frame only when one is requested, and the
/// result follows the requests: updates every 33 ms read as 30 Hz.
///
/// Uses the gap from each smooth frame's vsync to the next frame's, in the
/// order of [frames]. A janky frame pushes the next vsync back by whole
/// intervals, so the gap after it is left out. Gaps of zero or less, and
/// gaps of 100 ms or more, are ignored. The result is the most common gap,
/// not the mean: each gap `g` is grouped with every gap from `0.95 g` to
/// `1.05 g`, the largest group wins, ties go to the shorter `g`, and the
/// interval is the group's nearest-rank median.
///
/// Returns `null` when no gap qualifies, for example with fewer than two
/// frames or no smooth frame. See `docs/decisions/0001-metric-definitions.md`.
double? observeRefreshRate(List<FrameSample> frames, FrameBudget budget) {
  final gaps = <int>[];
  for (var i = 0; i + 1 < frames.length; i++) {
    final frame = ClassifiedFrame(frames[i], budget);
    if (frame.frameClass != FrameClass.smooth) continue;
    final gap = frames[i + 1].vsyncStartMicros - frames[i].vsyncStartMicros;
    if (gap > 0 && gap < _pauseMicros) gaps.add(gap);
  }
  if (gaps.isEmpty) return null;
  gaps.sort();

  // For each gap, find the gaps within the tolerance of it. The sorted list
  // lets two indexes slide forward: [low, high) is the current group.
  var bestLow = 0;
  var bestHigh = 0;
  var low = 0;
  var high = 0;
  for (final gap in gaps) {
    while (gaps[low] < gap * (1 - _tolerance)) {
      low++;
    }
    while (high < gaps.length && gaps[high] <= gap * (1 + _tolerance)) {
      high++;
    }
    if (high - low > bestHigh - bestLow) {
      bestLow = low;
      bestHigh = high;
    }
  }

  final interval = nearestRankOfSorted(gaps.sublist(bestLow, bestHigh), 50);
  return Duration.microsecondsPerSecond / interval;
}
