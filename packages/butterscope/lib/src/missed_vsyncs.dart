import 'dart:math' as math;

import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';

/// The vsyncs that passed with no frame between consecutive [frames], beyond
/// what each frame's own UI time explains.
///
/// Under the `benchmarkLive` frame policy that Butterscope sets, the test
/// binding requests a new frame after every frame, so every vsync should
/// produce one. A gap of k intervals between consecutive frames' vsyncs
/// means k - 1 vsyncs passed without a frame. A frame whose UI time spans n
/// intervals already explains the first n of them, and that lateness is
/// counted as its overrun, so only the rest are counted here: work queued
/// on the UI thread before the next frame was requested, work after the
/// frame was built (semantics, tree finalisation, post-frame callbacks),
/// or a raster pipeline too full to take another frame.
///
/// Each gap is rounded to whole intervals of [budget]; gaps of zero or less
/// are ignored. Long gaps are counted in full, because during a test they
/// are freezes. The count assumes [budget] is the screen's real rate: a
/// window whose observed rate does not match is `INVALID` and its count is
/// not used. Outside a test, frames are drawn only when requested, and this
/// count would include idle time.
int countMissedVsyncs(List<FrameSample> frames, FrameBudget budget) {
  var missed = 0;
  for (var i = 0; i + 1 < frames.length; i++) {
    final gap = frames[i + 1].vsyncStartMicros - frames[i].vsyncStartMicros;
    if (gap <= 0) continue;
    final intervals = (gap / budget.micros).round();
    final ui = ClassifiedFrame(frames[i], budget).uiMicros;
    final explained = math.max(1, (ui / budget.micros).ceil());
    if (intervals > explained) missed += intervals - explained;
  }
  return missed;
}
