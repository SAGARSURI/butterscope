// The fake engine and report reader the attach and span tests share.

import 'dart:ui';

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_report/butterscope_report.dart';
import 'package:butterscope_test/src/activity_source.dart';
import 'package:butterscope_test/src/guard_reader.dart';

/// A frame source the tests advance by hand.
class FakeFrameSource implements FrameSource {
  TimingsCallback? _callback;

  @override
  int currentFrameNumber = 0;

  /// How many times the refresh rate has been read.
  int rateReads = 0;

  @override
  double get declaredRefreshRate {
    rateReads++;
    return 120;
  }

  /// Frames run back to back, 8333 µs apart, as under `benchmarkLive`, so
  /// the time is the current frame's vsync.
  @override
  int get nowMicros => currentFrameNumber * 8333;

  @override
  void addTimingsCallback(TimingsCallback callback) => _callback = callback;

  @override
  void removeTimingsCallback(TimingsCallback callback) => _callback = null;

  /// Begins and reports [count] frames, 8333 µs apart, each with
  /// [buildMicros] of build time.
  void render(int count, {int buildMicros = 2000}) {
    final timings = <FrameTiming>[];
    for (var i = 0; i < count; i++) {
      final number = ++currentFrameNumber;
      final vsync = number * 8333;
      timings.add(
        FrameTiming(
          vsyncStart: vsync,
          buildStart: vsync,
          buildFinish: vsync + buildMicros,
          rasterStart: vsync + buildMicros,
          rasterFinish: vsync + buildMicros + 1000,
          rasterFinishWallTime: vsync + buildMicros + 1000,
          frameNumber: number,
        ),
      );
    }
    _callback?.call(timings);
  }
}

/// An activity source the tests drive by hand.
class FakeActivitySource implements ActivitySource {
  ActivityListener? _listener;

  @override
  void start(ActivityListener listener) => _listener = listener;

  @override
  void stop() => _listener = null;

  /// Sends a pointer event.
  void input() => _listener?.input();

  /// Says whether tickers wait for the next frame.
  void animating({required bool animating}) {
    _listener?.animating(animating: animating);
  }

  /// Says the page on top is now [page].
  void pageShown(String? page, {bool first = false}) {
    _listener?.pageShown(page, first: first);
  }
}

/// A guard reader the tests set by hand. It starts as a clean phone in
/// profile mode.
class FakeGuardReader implements GuardReader {
  @override
  String platform = 'android';

  @override
  String buildMode = 'profile';

  @override
  bool benchmarkLive = true;

  @override
  bool animationsOff = false;

  @override
  double textScale = 1;

  @override
  String locale = 'en-GB';

  @override
  bool semanticsOn = false;

  /// What [readDevice] returns; `null` reads as a missing plugin.
  DeviceState? device = const DeviceState(
    model: 'samsung SM-S921B',
    osVersion: 'Android 16 (API 36)',
    thermal: 'none',
    thermalNominal: true,
    lowPower: false,
  );

  @override
  ({String? version, String? engineRevision}) get flutter {
    return (version: '3.47.6', engineRevision: 'abc123');
  }

  @override
  Future<DeviceState?> readDevice() async => device;
}

/// Reads back the one run in [lines], which must have arrived whole and
/// match schema v1.
CollectedRun runIn(List<String> lines) {
  final read = readLog(lines);
  if (read.strays.isNotEmpty || read.runs.length != 1) {
    throw StateError('Expected one run in the lines, read ${read.runs}.');
  }
  final run = read.runs.single;
  if (!run.started || !run.isWhole) {
    throw StateError('The run did not arrive whole: ${run.problems}.');
  }
  final problems = [...checkReport(run.report), ...checkFrames(run.frames)];
  if (problems.isNotEmpty) {
    throw StateError('The run does not match schema v1: $problems.');
  }
  return run;
}

/// The report of the one run in [lines].
Map<String, Object?> reportIn(List<String> lines) {
  return runIn(lines).report! as Map<String, Object?>;
}
