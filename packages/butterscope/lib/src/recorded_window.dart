import 'package:butterscope/src/frame_sample.dart';

/// One read of the screen's declared refresh rate, placed in the frame
/// sequence of a window.
final class RefreshRateRead {
  /// Creates a read of [hertz], taken after [afterSamples] of the window's
  /// samples had been reported.
  const new({required this.hertz, required this.afterSamples});

  /// The rate the screen declared, as read. It is stored as read, even when
  /// it is 0 or not finite; the guards judge it later.
  final double hertz;

  /// How many of the window's samples were reported before this read. The
  /// read sits after them, and before any sample reported later.
  final int afterSamples;
}

/// Everything a recorder stored for one window, before any metric is
/// computed.
final class RecordedWindow {
  /// Creates a recorded window, for example in a test.
  const new({
    required this.startFrameNumber,
    required this.endFrameNumber,
    required this.samples,
    required this.refreshRateReads,
    required this.flushTimedOut,
    required this.flushMicros,
    required this.callbackMicros,
  });

  /// The frame begun most recently when the window started. Frames after it
  /// are in the window; it is not.
  final int startFrameNumber;

  /// The frame begun most recently when the window stopped: the window's
  /// last frame.
  final int endFrameNumber;

  /// The window's frames, in the order the engine reported them.
  ///
  /// Frame numbers can skip: a vsync whose frame was not built, for example
  /// because the raster pipeline was full, used up a number without a
  /// timing. The gaps are kept as they are.
  final List<FrameSample> samples;

  /// The declared refresh rate, read at the start, on each batch of timings
  /// while recording, and at the end.
  final List<RefreshRateRead> refreshRateReads;

  /// Whether the wait for the window's last timings ended by timeout rather
  /// than by a timing from after the window. If it did, frames at the end
  /// of the window may be missing.
  final bool flushTimedOut;

  /// How long the wait for the window's last timings took after the window
  /// stopped, in microseconds.
  final int flushMicros;

  /// The recorder's own cost: total time spent in its timings callback for
  /// this window, in microseconds.
  final int callbackMicros;
}
