import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/marks.dart';

/// One read of the screen's declared refresh rate, placed in the frame
/// sequence of a window.
final class RefreshRateRead {
  /// Creates a read of [hertz], taken after [afterSamples] of the window's
  /// samples had been reported, at [micros].
  const new({required this.hertz, required this.afterSamples, this.micros});

  /// The rate the screen declared, as read. It is stored as read, even when
  /// it is 0 or not finite; the guards judge it later.
  final double hertz;

  /// How many of the window's samples were reported before this read. The
  /// read sits after them, and before any sample reported later.
  final int afterSamples;

  /// When the read was taken, in microseconds on the clock [FrameMark]s
  /// use, or null when the log it was read back from did not say, as M2's
  /// logs do not.
  final int? micros;
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
  /// than by a timing numbered at or past the window's last frame. If it
  /// did, frames at the end of the window may be missing.
  final bool flushTimedOut;

  /// How long the wait for the window's last timings took after the window
  /// stopped, in microseconds.
  final int flushMicros;

  /// The recorder's own cost: total time spent in its timings callback for
  /// this window, in microseconds.
  final int callbackMicros;

  /// The samples of the frames begun after [start], up to and including
  /// the frame [end] names, in the order they were reported.
  List<FrameSample> samplesBetween(FrameMark start, FrameMark end) {
    return [
      for (final sample in samples)
        if (sample.frameNumber > start.frameNumber &&
            sample.frameNumber <= end.frameNumber)
          sample,
    ];
  }

  /// The declared-rate reads taken from [start] to [end] by the clock:
  /// the reads at both marks, and on each batch of timings that arrived
  /// between them.
  ///
  /// A read after [end] is left out, even when no timing arrived between
  /// the two, so a rate change after a part never reaches it. A read with
  /// no time is left out.
  Iterable<RefreshRateRead> readsBetween(FrameMark start, FrameMark end) {
    return refreshRateReads.where((read) {
      final micros = read.micros;
      return micros != null && micros >= start.micros && micros <= end.micros;
    });
  }
}
