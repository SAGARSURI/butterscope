import 'package:flutter/widgets.dart';

/// A planted cause of dropped frames, switched on at build time with
/// `--dart-define=BUTTERSCOPE_PLANT=<name>`. One at a time; none by default.
///
/// M2's plants run only in the calibration screen's animated phase, so the
/// still phase stays a clean control. Each of M4's plants is a mistake on
/// one sample screen, named by [screen]. A plant makes its screen slow,
/// never wrong.
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

  /// A full-screen fragment shader, to load the GPU rather than the raster
  /// thread.
  gpuHeavy('gpu_heavy'),

  /// Every feed card clipped with save layers under an opacity.
  rasterClip('raster_clip', screen: 'Feed'),

  /// Every keystroke scores every item with a fuzzy match, synchronously.
  uiBusy('ui_busy', screen: 'Search'),

  /// Every counter tick rebuilds and lays out every row.
  rebuildAll('rebuild_all', screen: 'Activity'),

  /// Each message batch is decoded on the UI isolate.
  syncDecode('sync_decode', screen: 'Inbox'),

  /// Every cell averages its photo's pixels on the UI thread to tint its
  /// frame.
  photoTint('photo_tint', screen: 'Gallery'),

  /// A large blur over the whole header picture.
  gpuBlur('gpu_blur', screen: 'Detail');

  new(this.defineName, {this.screen});

  /// The plant's name in `BUTTERSCOPE_PLANT`.
  final String defineName;

  /// The sample screen the plant slows down, or null for M2's calibration
  /// plants. tool/m4/run_tests.sh reads it to pick the plants to run.
  final String? screen;

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

/// Makes the build's [plant] known to the screens below it.
class PlantScope extends InheritedWidget {
  const new({required this.plant, required super.child, super.key});

  final Plant plant;

  /// The plant above [context], or [Plant.none] when there is none.
  ///
  /// A build has one plant for its whole run, so this registers no
  /// dependency, and a state can read it in `initState`.
  static Plant of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<PlantScope>()?.plant ??
        Plant.none;
  }

  @override
  bool updateShouldNotify(PlantScope oldWidget) => plant != oldWidget.plant;
}
