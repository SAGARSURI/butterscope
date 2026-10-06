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
  /// Throws a [FormatException] when [cost] is not a number of type [T],
  /// and an [ArgumentError] when it is not finite and above 0, so a typo
  /// fails loudly instead of measuring the default or never finishing.
  T resolve(Plant buildPlant, String cost) {
    if (cost.isEmpty || buildPlant != plant) {
      return defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
    }
    final value = (T == int ? int.parse(cost) : double.parse(cost)) as T;
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(cost, 'BUTTERSCOPE_COST', 'must be above 0');
    }
    return value;
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

// M4's plants, one per sample screen. Values come from single probe runs
// with semantics off.
// **(open, M4: set by the probe runs.)**

/// Save layers around each feed card for `raster_clip`.
/// On the iPhone, 150 cost Feed nothing and 350 cost it 43%: the frames
/// went from 0.7 to 2.4 budgets. On the S24, 24 cost about 1%.
const rasterClipLayers = PlantCost<int>(
  Plant.rasterClip,
  android: 60,
  ios: 350,
);

/// Words of each item's title, tags and summary that `ui_busy` scores
/// against the query on every keystroke. An item has about 22.
const uiBusyWordsPerItem = PlantCost<int>(Plant.uiBusy, android: 12, ios: 12);

/// Segments in each row's bar for `rebuild_all`, every one a widget that
/// is built and laid out again on every tick.
/// 200 cost Activity 16% on the S24 and 13% on the iPhone; 300 cost the
/// iPhone 17%.
const rebuildAllSegments = PlantCost<int>(
  Plant.rebuildAll,
  android: 200,
  ios: 300,
);

/// Header entries in each inbox message's JSON, which `sync_decode` parses
/// on the UI isolate. The screen shows none of them. Each is about 80
/// bytes, so at 6,000 a batch of 20 messages is about 10 MB. The clean
/// build gets the same messages and decodes them on a background isolate.
/// With the socket sending bytes, 6,000 cost the S24's Inbox 9.7% and
/// 10,000 cost the iPhone 12.7% in single runs. In 3 runs on the S24,
/// 8,000 cost 12 to 14%, under 10 points above the clean screen's 3.4%,
/// and 10,000 cost 17 to 18%.
const syncDecodeHeaders = PlantCost<int>(
  Plant.syncDecode,
  android: 10000,
  ios: 10000,
);

/// The width in pixels of the copy of each photo whose pixels `photo_tint`
/// averages, every time a cell is built into the grid. The copy is 4:3,
/// so 2,000 is 3 million pixels. On the S24, 1,500 cost Gallery 13% and
/// 3,000 cost 41% in single runs, and 2,000 cost 22 to 23% in 3 runs. The
/// iPhone's value is a first guess.
const photoTintWidth = PlantCost<int>(
  Plant.photoTint,
  android: 2000,
  ios: 1500,
);

/// Backdrop blurs stacked over the detail page's header picture for
/// `gpu_blur`, each of sigma 40 like `backdrop_blur`'s. The knob is the
/// layer count, not the sigma: Impeller blurs a downsampled copy, scaling
/// by about 4 / sigma down to 1/16 (`GaussianBlurFilterContents::
/// CalculateScale` in `impeller/entity/contents/filters/
/// gaussian_blur_filter_contents.cc`), so a larger sigma costs about the
/// same. On the S24 one layer of sigma 40 cost no frames, 12 cost Detail
/// 40%, and 24 ran the phone out of memory. On the iPhone 12 cost 11% and
/// 24 cost 28%.
const gpuBlurLayers = PlantCost<int>(Plant.gpuBlur, android: 12, ios: 24);
