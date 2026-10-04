import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:butterscope/src/frame_sample.dart';
import 'package:butterscope/src/frame_source.dart';
import 'package:butterscope/src/recorded_window.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

/// Records the frames rendered inside a window, from [FrameTiming]s alone.
///
/// While recording it only stores samples and refresh-rate reads; metrics
/// are computed later, so they never cost a measured frame (`docs/DESIGN.md`
/// section 6.9).
///
/// The window is bounded by frame numbers: it holds the frames begun after
/// [start] up to the last one begun before [stop]. Timings of earlier
/// frames, still queued in the engine at the start, are dropped, and so are
/// timings of later frames.
final class FrameRecorder {
  /// Creates a recorder that reads frames from [_source].
  ///
  /// The engine batches timings, so after [stop] the recorder waits for
  /// the window's last ones. `Shell::OnFrameRasterized` (Flutter 3.47.5,
  /// `shell/common/shell.cc`) reports a batch every 100 ms in debug and
  /// profile builds and every 1000 ms in release, or at 100 frames. The wait
  /// gives up after [profileFlushTimeout] (also used in debug) or
  /// [releaseFlushTimeout], chosen by [releaseMode]. The defaults are
  /// provisional. **(open, M2: set from device runs.)**
  ///
  /// [callbackStopwatch] measures the recorder's own cost; a test can pass a
  /// fake one.
  new(
    this._source, {
    Duration profileFlushTimeout = const Duration(milliseconds: 500),
    Duration releaseFlushTimeout = const Duration(seconds: 2),
    bool releaseMode = kReleaseMode,
    Stopwatch? callbackStopwatch,
  }) : _flushTimeout = releaseMode ? releaseFlushTimeout : profileFlushTimeout,
       _callbackStopwatch = callbackStopwatch ?? Stopwatch();

  final FrameSource _source;
  final Duration _flushTimeout;
  final Stopwatch _callbackStopwatch;

  var _recording = false;
  var _startFrame = 0;
  int? _endFrame;
  var _samples = <FrameSample>[];
  var _rateReads = <RefreshRateRead>[];
  var _flushed = Completer<bool>();

  /// Starts a window at the frame begun most recently.
  ///
  /// Throws a [StateError] if a window is already open.
  void start() {
    if (_recording) throw StateError('The recorder is already recording.');
    _recording = true;
    _startFrame = _source.currentFrameNumber;
    _endFrame = null;
    _samples = [];
    _rateReads = [];
    _flushed = Completer<bool>();
    _callbackStopwatch
      ..stop()
      ..reset();
    _readRefreshRate();
    _source.addTimingsCallback(_onTimings);
  }

  /// Ends the window at the frame begun most recently, waits for its last
  /// timings, and returns what was recorded.
  ///
  /// The wait ends when a timing from after the window arrives, which means
  /// every frame in it has been reported, or when the flush timeout passes.
  ///
  /// Throws a [StateError] if no window is open, or it is already stopping.
  Future<RecordedWindow> stop() async {
    if (!_recording || _endFrame != null) {
      throw StateError('The recorder is not recording.');
    }
    final end = _endFrame = _source.currentFrameNumber;
    _readRefreshRate();

    final flushClock = Stopwatch()..start();
    final timedOut = await _flushed.future.timeout(
      _flushTimeout,
      onTimeout: () => true,
    );
    _source.removeTimingsCallback(_onTimings);
    _recording = false;

    return RecordedWindow(
      startFrameNumber: _startFrame,
      endFrameNumber: end,
      samples: List.unmodifiable(_samples),
      refreshRateReads: List.unmodifiable(_rateReads),
      flushTimedOut: timedOut,
      flushMicros: flushClock.elapsedMicroseconds,
      callbackMicros: _callbackStopwatch.elapsedMicroseconds,
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    _callbackStopwatch.start();
    final end = _endFrame;
    for (final timing in timings) {
      final frameNumber = timing.frameNumber;
      if (frameNumber <= _startFrame) continue;
      if (end != null && frameNumber > end) {
        if (!_flushed.isCompleted) _flushed.complete(false);
        continue;
      }
      _samples.add(FrameSample.fromTiming(timing));
    }
    // Batches during the wait after stop are past the window's end read.
    if (end == null) _readRefreshRate();
    _callbackStopwatch.stop();
  }

  void _readRefreshRate() {
    _rateReads.add(
      RefreshRateRead(
        hertz: _source.declaredRefreshRate,
        afterSamples: _samples.length,
      ),
    );
  }
}
