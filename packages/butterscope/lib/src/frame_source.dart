import 'dart:ui'
    show FlutterView, FrameTiming, PlatformDispatcher, TimingsCallback;

import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// What a frame recorder reads from the engine.
///
/// The recorder uses only this, so a host test can feed it fake batches of
/// timings, frame numbers and refresh rates without a device.
abstract interface class FrameSource {
  /// Starts sending each batch of [FrameTiming]s the engine reports to
  /// [callback].
  void addTimingsCallback(TimingsCallback callback);

  /// Stops sending batches to [callback].
  void removeTimingsCallback(TimingsCallback callback);

  /// The number of the frame the engine began most recently.
  ///
  /// Matches [FrameTiming.frameNumber] for the same frame.
  int get currentFrameNumber;

  /// The refresh rate the screen declares, in hertz.
  ///
  /// In Flutter 3.47.6 the engine sends it to Dart only at startup, and on
  /// Android after a configuration change, so it does not follow a later
  /// change of rate (`docs/decisions/0002-m2-recorder-findings.md`).
  double get declaredRefreshRate;

  /// The time now, in microseconds on a clock that only runs forward.
  ///
  /// Marks take it, so the quiet stretches that split episodes are measured
  /// in time, not in frames.
  int get nowMicros;
}

/// The [FrameSource] of a running app, on a phone.
///
/// Frame numbers come from `PlatformDispatcher.instance.frameData`. In the
/// pinned engine (Flutter 3.47.6), each vsync gets a `FrameTimingsRecorder`
/// that takes the next number from one counter
/// (`engine/src/flutter/flow/frame_timings.cc:41`). `Animator::BeginFrame`
/// passes that number to the framework with the frame
/// (`shell/common/animator.cc:117`), and `_beginFrame` stores it in
/// `frameData` (`lib/ui/hooks.dart:401`). `Shell::OnFrameRasterized` reports
/// the same recorder's number in the frame's timing (`shell/common/shell.cc`,
/// `timing.GetFrameNumber()`). So both sides hold one number per frame.
final class EngineFrameSource implements FrameSource {
  /// Creates a source that reads the refresh rate of `view`'s display, or of
  /// the implicit view's when `view` is null.
  new({this._view});

  final FlutterView? _view;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void addTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.removeTimingsCallback(callback);
  }

  @override
  int get currentFrameNumber {
    return PlatformDispatcher.instance.frameData.frameNumber;
  }

  @override
  double get declaredRefreshRate {
    final view = _view ?? PlatformDispatcher.instance.implicitView;
    if (view == null) {
      throw StateError('The app has no implicit view; pass a view.');
    }
    return view.display.refreshRate;
  }

  @override
  int get nowMicros => _clock.elapsedMicroseconds;
}
