import 'package:butterscope/src/frame_budget.dart';
import 'package:butterscope/src/frame_sample.dart';

/// The vsyncs that passed with no frame, between consecutive [frames].
///
/// Under the `benchmarkLive` frame policy that Butterscope sets, the test
/// binding requests a new frame after every frame, so every vsync should
/// produce one. A gap of k intervals between consecutive frames' vsyncs
/// means k - 1 vsyncs passed without a frame, whatever held it up: work
/// queued on the UI thread before the frame was requested, a long build, or
/// a raster pipeline too full to take another frame. Each gap is rounded to
/// whole intervals of [budget]; gaps of zero or less are ignored. Long gaps
/// are counted in full, because during a test they are freezes, not pauses.
///
/// Outside a test, frames are drawn only when requested, and this count
/// would include idle time.
int countMissedVsyncs(List<FrameSample> frames, FrameBudget budget) {
  var missed = 0;
  for (var i = 0; i + 1 < frames.length; i++) {
    final gap = frames[i + 1].vsyncStartMicros - frames[i].vsyncStartMicros;
    if (gap <= 0) continue;
    final intervals = (gap / budget.micros).round();
    if (intervals > 1) missed += intervals - 1;
  }
  return missed;
}
