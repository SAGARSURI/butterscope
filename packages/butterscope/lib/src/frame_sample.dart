import 'dart:ui' show FramePhase, FrameTiming;

/// One rendered frame, reduced to the times Butterscope measures.
///
/// Times are in microseconds, the unit `FrameTiming` reports in.
final class FrameSample {
  /// Creates a frame sample from raw times, for example in a test.
  const new({
    required this.vsyncStartMicros,
    required this.buildMicros,
    required this.rasterMicros,
    this.vsyncOverheadMicros = 0,
    this.frameNumber = -1,
  });

  /// Creates a frame sample from the engine's [timing].
  factory fromTiming(FrameTiming timing) {
    return FrameSample(
      vsyncStartMicros: timing.timestampInMicroseconds(FramePhase.vsyncStart),
      buildMicros: timing.buildDuration.inMicroseconds,
      rasterMicros: timing.rasterDuration.inMicroseconds,
      vsyncOverheadMicros: timing.vsyncOverhead.inMicroseconds,
      frameNumber: timing.frameNumber,
    );
  }

  /// When the vsync signal that started this frame arrived.
  final int vsyncStartMicros;

  /// How long the framework took to build the frame on the UI thread.
  final int buildMicros;

  /// Raster thread time: how long the engine took to draw the frame and
  /// hand it to the GPU. GPU execution itself is not included.
  final int rasterMicros;

  /// How long the frame waited for the UI thread after its vsync, before
  /// building started.
  ///
  /// The engine starts a frame only when the UI thread is free, so other
  /// work on it, such as a stream listener, a timer or a platform message
  /// handler, shows up here and not in [buildMicros].
  final int vsyncOverheadMicros;

  /// The engine's frame number, or -1 when it is not known.
  final int frameNumber;
}
