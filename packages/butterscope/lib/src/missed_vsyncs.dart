import 'dart:math' as math;

import 'package:butterscope/src/classified_frame.dart';
import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';

/// The vsyncs that passed with no frame between consecutive [frames], beyond
/// what a late frame explains.
///
/// Under the `benchmarkLive` frame policy that Butterscope sets, the test
/// binding requests a new frame after every frame, so every vsync should
/// produce one. A gap of k intervals between consecutive frames' vsyncs
/// means k - 1 vsyncs passed without a frame. A late frame explains some of
/// them, and its lateness is already counted as its overrun:
///
/// - a frame whose UI time or raster time spans n intervals explains the
///   first n intervals of the gap after it;
/// - the raster pipeline holds two frames, so a slow raster frame can cost
///   its vsync one frame later: a frame whose raster time spans m intervals
///   also explains m - 1 intervals of the gap after the next frame, having
///   used one on its own gap.
///
/// Only the rest are counted here: work queued on the UI thread before the
/// next frame was requested, work after the frame was built (semantics,
/// tree finalisation, post-frame callbacks), or a screen slower than
/// [budget]. On iOS, UI work between frames also lands here, because the
/// vsync callback waits for the UI thread.
///
/// Each gap is rounded to whole intervals of [budget]; gaps of zero or less
/// are ignored. Long gaps are counted in full, because during a test they
/// are freezes. The count assumes [budget] is the screen's real rate; see
/// `docs/decisions/0001-metric-definitions.md` for how a wrong one is
/// caught, and `docs/decisions/0002-m2-recorder-findings.md` (decision 6)
/// for the raster terms. Outside a test, frames are drawn only when
/// requested, and this count would include idle time.
int countMissedVsyncs(List<FrameSample> frames, FrameBudget budget) {
  int spanned(int micros) => (micros / budget.micros).ceil();

  var missed = 0;
  for (var i = 0; i + 1 < frames.length; i++) {
    final gap = frames[i + 1].vsyncStartMicros - frames[i].vsyncStartMicros;
    if (gap <= 0) continue;
    final intervals = (gap / budget.micros).round();
    final ui = ClassifiedFrame(frames[i], budget).uiMicros;
    final carried = i == 0 ? 0 : spanned(frames[i - 1].rasterMicros) - 1;
    final own = math.max(spanned(ui), spanned(frames[i].rasterMicros));
    final explained = math.max(1, math.max(own, carried));
    if (intervals > explained) missed += intervals - explained;
  }
  return missed;
}
