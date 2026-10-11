import 'dart:math' as math;

import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/percentile.dart';

/// A gap this long or longer is a freeze, not a refresh interval, so it
/// says nothing about the screen's rate.
const int _freezeMicros = 100000;

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
  return _modeRate([
    for (final (_, gap) in _qualifyingGaps(frames, budget)) gap,
  ]);
}

/// A slice is judged only with at least this many qualifying gaps (0002,
/// decision 4).
const int _minimumSliceGaps = 10;

/// A slice whose rate is further than this fraction from the declared rate
/// is a mismatch (0001, item 6).
const double _mismatchTolerance = 0.05;

/// One second of a part's frames whose observed rate could be judged.
final class RateSlice {
  /// Creates a slice, for example in a test.
  const new({
    required this.index,
    required this.gapCount,
    required this.observedRefreshRate,
    required this.declaredRefreshRate,
  });

  /// Which second of the part this is: slice `i` holds the frames whose
  /// vsync came `i` to `i + 1` seconds after the part's first frame's.
  final int index;

  /// How many qualifying gaps the slice holds: 10 or more.
  final int gapCount;

  /// The rate the slice's frames were drawn at, in hertz.
  final double observedRefreshRate;

  /// The rate the part was judged at: the declared rate that set its budget.
  final double declaredRefreshRate;

  /// Whether the observed rate differs from the declared one by more than
  /// 5%: a **rate mismatch**. A flag, never a reason to void the part
  /// (`docs/DESIGN.md` section 4).
  bool get isMismatch {
    final difference = (observedRefreshRate - declaredRefreshRate).abs();
    return difference > declaredRefreshRate * _mismatchTolerance;
  }
}

/// The one-second slices of [frames] whose observed rate can be judged
/// against [budget]'s declared rate, in order.
///
/// One mode over a whole part hides a drop in part of it, so the frames
/// are cut into consecutive one-second slices from the first frame's
/// `vsyncStart`, the last one shorter. Each gap belongs to the slice of the
/// frame it follows, and only gaps between [frames] count, so a slice's 10
/// gaps take 11 frames. Gaps qualify as for [observeRefreshRate], and a
/// slice with fewer than 10 is left out. A frame reported with a vsync
/// before the first frame's counts in the first slice. See
/// `docs/decisions/0001-metric-definitions.md`, item 6.
List<RateSlice> judgeRateSlices(List<FrameSample> frames, FrameBudget budget) {
  if (frames.isEmpty) return const [];
  final first = frames.first.vsyncStartMicros;
  final bySlice = <int, List<int>>{};
  for (final (vsync, gap) in _qualifyingGaps(frames, budget)) {
    final index = math.max(0, (vsync - first) ~/ _sliceMicros);
    (bySlice[index] ??= []).add(gap);
  }
  return [
    for (final MapEntry(key: index, value: gaps) in bySlice.entries)
      if (gaps.length >= _minimumSliceGaps)
        RateSlice(
          index: index,
          gapCount: gaps.length,
          observedRefreshRate: _modeRate(gaps)!,
          declaredRefreshRate: budget.refreshRate,
        ),
  ]..sort((a, b) => a.index.compareTo(b.index));
}

const int _sliceMicros = Duration.microsecondsPerSecond;

/// Each qualifying gap, with the vsync of the frame it follows: the gap
/// from a smooth frame's vsync to the next frame's, above 0 and under
/// 100 ms, in the order of [frames].
Iterable<(int, int)> _qualifyingGaps(
  List<FrameSample> frames,
  FrameBudget budget,
) sync* {
  for (var i = 0; i + 1 < frames.length; i++) {
    final frame = ClassifiedFrame(frames[i], budget);
    if (frame.frameClass != FrameClass.smooth) continue;
    final vsync = frames[i].vsyncStartMicros;
    final gap = frames[i + 1].vsyncStartMicros - vsync;
    if (gap > 0 && gap < _freezeMicros) yield (vsync, gap);
  }
}

/// The rate of the most common gap in [unsorted], or `null` when it is
/// empty.
double? _modeRate(List<int> unsorted) {
  if (unsorted.isEmpty) return null;
  final gaps = [...unsorted]..sort();

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
