// The fake engine and report reader the attach and span tests share.

import 'dart:convert';
import 'dart:ui';

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/activity_source.dart';
import 'package:butterscope_test/src/report_writer.dart';

/// A frame source the tests advance by hand.
class FakeFrameSource implements FrameSource {
  TimingsCallback? _callback;

  @override
  int currentFrameNumber = 0;

  @override
  double declaredRefreshRate = 120;

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

/// Joins the printed chunks of the one run in [lines] and decodes it.
Map<String, Object?> reportIn(List<String> lines) {
  final chunks = [
    for (final line in lines)
      if (line.startsWith('$reportTag ')) line.split(' ').skip(4).join(' '),
  ];
  return jsonDecode(chunks.join()) as Map<String, Object?>;
}
