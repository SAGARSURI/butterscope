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
    this.frameNumber = -1,
  });

  /// Creates a frame sample from the engine's [timing].
  factory fromTiming(FrameTiming timing) {
    return FrameSample(
      vsyncStartMicros: timing.timestampInMicroseconds(FramePhase.vsyncStart),
      buildMicros: timing.buildDuration.inMicroseconds,
      rasterMicros: timing.rasterDuration.inMicroseconds,
      frameNumber: timing.frameNumber,
    );
  }

  /// When the vsync signal that started this frame arrived.
  final int vsyncStartMicros;

  /// UI thread time: how long the framework took to build the frame.
  final int buildMicros;

  /// Raster thread time: how long the engine took to draw the frame.
  final int rasterMicros;

  /// The engine's frame number, or -1 when it is not known.
  final int frameNumber;
}
