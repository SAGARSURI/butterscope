import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';

/// The issue list's entries for one span or episode
/// (`docs/DESIGN.md` section 6, "What the report contains"): one per
/// janky frame in [frames] against [budget], in frame order, each as
/// `[part, frame, offsetMs, thread, overrunB, class]`.
///
/// - `part` is [part], the span's or episode's index in the report's
///   `parts`.
/// - `frame` is the engine's frame number.
/// - `offsetMs` is the frame's vsync after the vsync of the first of
///   [frames], in ms. Both times come from the engine's clock; the marks
///   that bound a part use another.
/// - `thread` is `ui`, `raster` or `both`.
/// - `overrunB` is the slower thread's time past the budget, as a multiple
///   of the budget.
/// - `class` is `janky`, `severe` or `stall`.
List<List<Object>> issuesOf(
  int part,
  List<FrameSample> frames,
  FrameBudget budget,
) {
  if (frames.isEmpty) return const [];
  final firstVsync = frames.first.vsyncStartMicros;
  return [
    for (final sample in frames)
      // A frame has a late thread exactly when it is janky or worse.
      if (ClassifiedFrame(sample, budget) case ClassifiedFrame(
        :final thread?,
        :final overrunMicros,
        :final frameClass,
      ))
        [
          part,
          sample.frameNumber,
          (sample.vsyncStartMicros - firstVsync) /
              Duration.microsecondsPerMillisecond,
          thread.name,
          overrunMicros / budget.micros,
          frameClass.name,
        ],
  ];
}
