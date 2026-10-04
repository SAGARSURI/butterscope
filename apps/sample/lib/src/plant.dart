/// A planted cause of dropped frames, switched on at build time with
/// `--dart-define=BUTTERSCOPE_PLANT=<name>`. One at a time; none by default.
///
/// Each plant runs only in the calibration screen's animated phase, so the
/// still phase stays a clean control.
enum Plant {
  /// No plant.
  none(''),

  /// A periodic stream whose listener does synchronous work on the UI
  /// thread, as a socket listener decoding a message would.
  listenerDecode('listener_decode'),

  /// The same work in a post-frame callback, rescheduled every frame.
  postframeDecode('postframe_decode'),

  /// Stacked layers, opacity and anti-aliased clips that each need a
  /// save layer, to load the raster thread.
  slowRaster('slow_raster'),

  /// A full-screen backdrop blur over the animation.
  backdropBlur('backdrop_blur'),

  /// Large blurred shadows, to load the GPU rather than the raster thread.
  gpuHeavy('gpu_heavy');

  new(this.defineName);

  /// The plant's name in `BUTTERSCOPE_PLANT`.
  final String defineName;

  /// The plant this build was made with.
  static Plant fromEnvironment() {
    return fromName(const String.fromEnvironment('BUTTERSCOPE_PLANT'));
  }

  /// The plant called [name], or [none] for an empty name.
  ///
  /// Throws an [ArgumentError] for an unknown name, so a typo fails loudly
  /// instead of measuring a clean app.
  static Plant fromName(String name) {
    for (final plant in values) {
      if (plant.defineName == name) return plant;
    }
    throw ArgumentError.value(name, 'BUTTERSCOPE_PLANT', 'is not a plant');
  }
}
