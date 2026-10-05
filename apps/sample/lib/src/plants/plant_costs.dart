import 'package:butterscope_sample/src/plants/plant.dart';
import 'package:flutter/foundation.dart';

/// A plant's one cost knob, with a value for each platform.
///
/// The same work costs the Galaxy S24 and the iPhone 17 Pro very different
/// amounts (decision record 0002, decision 12), so each plant is tuned on
/// each phone. The comment on each knob names the runs that set it.
///
/// For tuning, `--dart-define=BUTTERSCOPE_COST=<value>` replaces the knob
/// of the build's plant, so each candidate value is a build rather than an
/// edit. The other plants' knobs keep their values.
class PlantCost<T extends num> {
  const new(this.plant, {required this.android, required this.ios});

  /// The plant this knob belongs to.
  final Plant plant;

  final T android;
  final T ios;

  /// The value in this build.
  T get value => resolve(
    Plant.fromEnvironment(),
    const String.fromEnvironment('BUTTERSCOPE_COST'),
  );

  /// The value in a build made with [buildPlant] and `BUTTERSCOPE_COST` set
  /// to [cost]: [cost] when it is set and [buildPlant] is [plant], else the
  /// value for the platform the app runs on. Butterscope supports Android
  /// and iOS only; any other platform gets the Android value.
  ///
  /// Throws a [FormatException] when [cost] is not a number of type [T], so
  /// a typo fails loudly instead of measuring the default.
  T resolve(Plant buildPlant, String cost) {
    if (cost.isNotEmpty && buildPlant == plant) {
      return (T == int ? int.parse(cost) : double.parse(cost)) as T;
    }
    return defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
  }
}

// M2's plants, on the calibration screen. The Android values are M2's,
// from the S24 runs in docs/measurements/m2.md. The iOS values are first
// guesses, scaled from the iPhone's p99 raster time in the same runs to
// about 1.5 frame budgets. **(open, M4: set by the probe runs.)**

/// Frame budgets of UI-thread work per stream event for `listener_decode`.
/// M2 lost 10.5% on the S24 and 15.2% on the iPhone at 1.5.
const listenerDecodeBudgets = PlantCost<double>(
  Plant.listenerDecode,
  android: 1.5,
  ios: 1.5,
);

/// Frame budgets of UI-thread work per frame for `postframe_decode`. M2
/// lost 50% on both phones at 1.5.
const postframeDecodeBudgets = PlantCost<double>(
  Plant.postframeDecode,
  android: 1.5,
  ios: 1.5,
);

/// Save-layer depth for `slow_raster`. 40 lost 39.8% on the S24 and none
/// on the iPhone, whose p99 raster time was 0.17 budgets.
const slowRasterDepth = PlantCost<int>(Plant.slowRaster, android: 40, ios: 350);

/// Stacked blurs for `backdrop_blur`. 6 lost 39.1% on the S24 and none on
/// the iPhone, whose p99 raster time was 0.30 budgets.
const backdropBlurLayers = PlantCost<int>(
  Plant.backdropBlur,
  android: 6,
  ios: 30,
);

/// Shader loop steps per pixel for `gpu_heavy`. 500 lost 34.1% on the S24
/// and 76.7% on the iPhone, whose p99 raster time was 8.9 budgets.
const gpuHeavyIterations = PlantCost<int>(
  Plant.gpuHeavy,
  android: 500,
  ios: 85,
);

// M4's plants, one per sample screen. Every value is a first guess.
// **(open, M4: set by the probe runs.)**

/// Save layers around each feed card for `raster_clip`.
const rasterClipLayers = PlantCost<int>(Plant.rasterClip, android: 6, ios: 50);

/// Words of each item's title, tags and summary that `ui_busy` scores
/// against the query on every keystroke. An item has about 22.
const uiBusyWordsPerItem = PlantCost<int>(Plant.uiBusy, android: 12, ios: 12);

/// Segments in each row's bar for `rebuild_all`, every one a widget that
/// is built and laid out again on every tick.
const rebuildAllSegments = PlantCost<int>(
  Plant.rebuildAll,
  android: 200,
  ios: 200,
);

/// Header entries in each inbox message's JSON, which `sync_decode` parses
/// on the UI isolate. The screen shows none of them. Each is about 80
/// bytes, so a batch of 20 messages is about 5 MB. The clean build gets
/// the same messages and decodes them on a background isolate.
const syncDecodeHeaders = PlantCost<int>(
  Plant.syncDecode,
  android: 3000,
  ios: 3000,
);

/// The width in pixels `image_full_res` decodes every photo at. The photos
/// are 4032 x 3024, so 4032 is full size.
const imageFullResWidth = PlantCost<int>(
  Plant.imageFullRes,
  android: 4032,
  ios: 4032,
);

/// Blur sigma over the detail page's header picture for `gpu_blur`.
const gpuBlurSigma = PlantCost<double>(Plant.gpuBlur, android: 40, ios: 40);
