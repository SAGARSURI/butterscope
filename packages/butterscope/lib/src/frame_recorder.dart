import 'dart:async';
import 'dart:math' as math;
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
  var _lastReportedFrame = 0;
  int? _endFrame;
  var _samples = <FrameSample>[];
  var _rateReads = <RefreshRateRead>[];
  var _flushed = Completer<bool>();

  /// Starts a window at the frame begun most recently.
  ///
  /// Throws a [StateError] if a window is already open. If reading the
  /// source throws, the error is passed on and no window is opened.
  void start() {
    if (_recording) throw StateError('The recorder is already recording.');
    // Read first, so a source that throws leaves the recorder idle.
    final startFrame = _source.currentFrameNumber;
    final startRate = _source.declaredRefreshRate;
    _recording = true;
    _startFrame = startFrame;
    _lastReportedFrame = startFrame;
    _endFrame = null;
    _samples = [];
    _rateReads = [RefreshRateRead(hertz: startRate, afterSamples: 0)];
    _flushed = Completer<bool>();
    _callbackStopwatch
      ..stop()
      ..reset();
    _source.addTimingsCallback(_onTimings);
  }

  /// Ends the window at the frame begun most recently, waits for its last
  /// timings, and returns what was recorded.
  ///
  /// The raster thread reports timings in frame order
  /// (`Shell::OnFrameRasterized` appends each to one list), so every frame
  /// in the window has been reported once a timing numbered at or past its
  /// last frame arrives. The wait ends then, at once if that timing came
  /// before the stop or the window is empty, or when the flush timeout
  /// passes.
  ///
  /// Throws a [StateError] if no window is open, or it is already stopping.
  /// If reading the source throws, the error is passed on and the recorder
  /// is left idle, ready to start again.
  Future<RecordedWindow> stop() async {
    if (!_recording || _endFrame != null) {
      throw StateError('The recorder is not recording.');
    }
    final flushClock = Stopwatch()..start();
    final int end;
    final bool timedOut;
    try {
      end = _endFrame = _source.currentFrameNumber;
      _readRefreshRate();
      if (_lastReportedFrame >= end) _completeFlush();
      timedOut = await _flushed.future.timeout(
        _flushTimeout,
        onTimeout: () => true,
      );
    } finally {
      _source.removeTimingsCallback(_onTimings);
      _recording = false;
    }

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
      _lastReportedFrame = math.max(_lastReportedFrame, frameNumber);
      if (end != null && frameNumber >= end) _completeFlush();
      if (frameNumber <= _startFrame) continue;
      if (end != null && frameNumber > end) continue;
      _samples.add(FrameSample.fromTiming(timing));
    }
    // Batches during the wait after stop are past the window's end read.
    if (end == null) _readRefreshRate();
    _callbackStopwatch.stop();
  }

  void _completeFlush() {
    if (!_flushed.isCompleted) _flushed.complete(false);
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
