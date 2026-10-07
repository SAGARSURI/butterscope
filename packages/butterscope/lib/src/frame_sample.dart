import 'dart:math' as math;
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
    this.totalSpanMicros = 0,
    this.rasterCache = RasterCacheUse.none,
  });

  /// Creates a frame sample from the engine's [timing].
  factory fromTiming(FrameTiming timing) {
    return FrameSample(
      vsyncStartMicros: timing.timestampInMicroseconds(FramePhase.vsyncStart),
      buildMicros: timing.buildDuration.inMicroseconds,
      rasterMicros: timing.rasterDuration.inMicroseconds,
      vsyncOverheadMicros: timing.vsyncOverhead.inMicroseconds,
      frameNumber: timing.frameNumber,
      totalSpanMicros: timing.totalSpan.inMicroseconds,
      rasterCache: RasterCacheUse(
        layerCount: timing.layerCacheCount,
        layerBytes: timing.layerCacheBytes,
        pictureCount: timing.pictureCacheCount,
        pictureBytes: timing.pictureCacheBytes,
      ),
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

  /// From the vsync to the end of rasterising the frame: its latency.
  ///
  /// The UI and raster threads run in a pipeline, so this can exceed the
  /// budget with no frame dropped. It is a diagnostic, never used for
  /// jank (`docs/DESIGN.md` section 4).
  final int totalSpanMicros;

  /// What the raster cache held while this frame was drawn.
  final RasterCacheUse rasterCache;

  /// UI thread time in microseconds: the wait for the UI thread after the
  /// vsync plus the build.
  ///
  /// The UI thread cannot start the next frame until this one is built, so
  /// UI time over the budget means a vsync was missed, whatever caused the
  /// wait. A negative wait, which a well-behaved engine never reports,
  /// counts as none.
  int get uiMicros => math.max(0, vsyncOverheadMicros) + buildMicros;
}

/// The raster cache's contents during one frame, as the engine reports
/// them in [FrameTiming].
final class RasterCacheUse {
  /// Creates a record of the raster cache's contents.
  const new({
    required this.layerCount,
    required this.layerBytes,
    required this.pictureCount,
    required this.pictureBytes,
  });

  /// An empty cache, for samples made without a timing.
  static const RasterCacheUse none = RasterCacheUse(
    layerCount: 0,
    layerBytes: 0,
    pictureCount: 0,
    pictureBytes: 0,
  );

  /// Layers stored in the raster cache.
  final int layerCount;

  /// Bytes the cached layers take.
  final int layerBytes;

  /// Pictures stored in the raster cache.
  final int pictureCount;

  /// Bytes the cached pictures take.
  final int pictureBytes;
}
