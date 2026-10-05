import 'package:flutter/foundation.dart';

/// A plant's one cost knob, with a value for each platform.
///
/// The same work costs the Galaxy S24 and the iPhone 17 Pro very different
/// amounts (decision record 0002, decision 12), so each plant is tuned on
/// each phone. The comment on each knob names the runs that set it.
class PlantCost<T> {
  const new({required this.android, required this.ios});

  final T android;
  final T ios;

  /// The value for the platform the app runs on. Butterscope supports
  /// Android and iOS only; any other platform gets the Android value.
  T get value => defaultTargetPlatform == TargetPlatform.iOS ? ios : android;
}

// M2's plants, on the calibration screen. The Android values are M2's,
// from the S24 runs in docs/measurements/m2.md. The iOS values are first
// guesses, scaled from the iPhone's p99 raster time in the same runs to
// about 1.5 frame budgets. **(open, M4: set by the probe runs.)**

/// Frame budgets of UI-thread work per event, for `listener_decode` and
/// `postframe_decode`. M2 lost 10.5% and 50% on the S24, and 15.2% and
/// 50% on the iPhone, at 1.5 on both.
const decodeWorkBudgets = PlantCost<double>(android: 1.5, ios: 1.5);

/// Save-layer depth for `slow_raster`. 40 lost 39.8% on the S24 and none
/// on the iPhone, whose p99 raster time was 0.17 budgets.
const slowRasterDepth = PlantCost<int>(android: 40, ios: 350);

/// Stacked blurs for `backdrop_blur`. 6 lost 39.1% on the S24 and none on
/// the iPhone, whose p99 raster time was 0.30 budgets.
const backdropBlurLayers = PlantCost<int>(android: 6, ios: 30);

/// Shader loop steps per pixel for `gpu_heavy`. 500 lost 34.1% on the S24
/// and 76.7% on the iPhone, whose p99 raster time was 8.9 budgets.
const gpuHeavyIterations = PlantCost<int>(android: 500, ios: 85);

// M4's plants, one per sample screen. Every value is a first guess.
// **(open, M4: set by the probe runs.)**

/// Save layers around each feed card for `raster_clip`.
const rasterClipLayers = PlantCost<int>(android: 6, ios: 50);

/// Words of each item's title, tags and summary that `ui_busy` scores
/// against the query on every keystroke. An item has about 22.
const uiBusyWordsPerItem = PlantCost<int>(android: 12, ios: 12);

/// Segments in each row's bar for `rebuild_all`, every one a widget that
/// is built and laid out again on every tick.
const rebuildAllSegments = PlantCost<int>(android: 200, ios: 200);

/// Header entries in each inbox message's JSON, which `sync_decode` parses
/// on the UI isolate. The screen shows none of them. Each is about 80
/// bytes, so a batch of 20 messages is about 5 MB. The clean build gets
/// the same messages and decodes them on a background isolate.
const syncDecodeHeaders = PlantCost<int>(android: 3000, ios: 3000);

/// The width in pixels `image_full_res` decodes every photo at. The photos
/// are 4032 x 3024, so 4032 is full size.
const imageFullResWidth = PlantCost<int>(android: 4032, ios: 4032);

/// Blur sigma over the detail page's header picture for `gpu_blur`.
const gpuBlurSigma = PlantCost<double>(android: 40, ios: 40);
