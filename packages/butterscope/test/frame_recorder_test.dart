import 'dart:ui';

import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

/// A frame source a test drives by hand.
class FakeFrameSource implements FrameSource {
  @override
  int currentFrameNumber = 10;

  @override
  double declaredRefreshRate = 120;

  TimingsCallback? callback;

  @override
  void addTimingsCallback(TimingsCallback callback) {
    this.callback = callback;
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    if (this.callback == callback) this.callback = null;
  }

  /// Reports one batch with a timing for each of [frameNumbers].
  void report(List<int> frameNumbers) {
    callback!([for (final number in frameNumbers) timingOf(number)]);
  }
}

/// A timing for frame [number], 8333 µs after the one before it.
FrameTiming timingOf(int number) {
  final vsync = number * 8333;
  return FrameTiming(
    vsyncStart: vsync,
    buildStart: vsync + 100,
    buildFinish: vsync + 3000,
    rasterStart: vsync + 3100,
    rasterFinish: vsync + 6000,
    rasterFinishWallTime: vsync + 6000,
    frameNumber: number,
  );
}

/// A stopwatch that adds [tick] microseconds each time it is stopped while
/// running, so a test knows exactly what it measured.
class FakeStopwatch implements Stopwatch {
  static const int tick = 7;

  int _micros = 0;
  bool _running = false;

  @override
  void start() => _running = true;

  @override
  void stop() {
    if (_running) _micros += tick;
    _running = false;
  }

  @override
  void reset() => _micros = 0;

  @override
  bool get isRunning => _running;

  @override
  int get elapsedMicroseconds => _micros;

  @override
  int get elapsedMilliseconds => _micros ~/ 1000;

  @override
  int get elapsedTicks => _micros;

  @override
  int get frequency => Duration.microsecondsPerSecond;

  @override
  Duration get elapsed => Duration(microseconds: _micros);
}

/// Long enough that a test reaching it would time out first.
const Duration never = Duration(hours: 1);

const Duration short = Duration(milliseconds: 10);

List<int> frameNumbersOf(RecordedWindow window) {
  return [for (final sample in window.samples) sample.frameNumber];
}

void main() {
  late FakeFrameSource source;

  setUp(() => source = FakeFrameSource());

  FrameRecorder recorder({Stopwatch? stopwatch}) {
    return FrameRecorder(
      source,
      profileFlushTimeout: never,
      callbackStopwatch: stopwatch,
    );
  }

  group('FrameRecorder window', () {
    test('drops frames from before the start that arrive late', () async {
      final frames = recorder()..start();
      source
        ..report([8, 9, 10, 11])
        ..currentFrameNumber = 12;
      final window = frames.stop();
      source.report([12, 13]);

      expect(frameNumbersOf(await window), [11, 12]);
    });

    test('drops frames from after the end', () async {
      final frames = recorder()..start();
      source
        ..report([11])
        ..currentFrameNumber = 12;
      final window = frames.stop();
      source.report([12, 13, 14]);

      expect(frameNumbersOf(await window), [11, 12]);
    });

    test('keeps the window frame numbers it was given', () async {
      final frames = recorder()..start();
      source.currentFrameNumber = 15;
      final window = frames.stop();
      source.report([11, 13, 14, 15, 16]);

      final recorded = await window;
      expect(recorded.startFrameNumber, 10);
      expect(recorded.endFrameNumber, 15);
      expect(frameNumbersOf(recorded), [11, 13, 14, 15]);
    });

    test('stores each sample from its timing', () async {
      final frames = recorder()..start();
      source.currentFrameNumber = 11;
      final window = frames.stop();
      source.report([11, 12]);

      final sample = (await window).samples.single;
      expect(sample.vsyncStartMicros, 11 * 8333);
      expect(sample.vsyncOverheadMicros, 100);
      expect(sample.buildMicros, 2900);
      expect(sample.rasterMicros, 2900);
    });

    test('stops listening once the window is recorded', () async {
      final frames = recorder()..start();
      expect(source.callback, isNotNull);
      final window = frames.stop();
      source.report([11]);
      await window;

      expect(source.callback, isNull);
    });
  });

  group('FrameRecorder refresh-rate reads', () {
    test('are placed after the samples reported before them', () async {
      final frames = recorder()..start();
      source
        ..report([11, 12])
        ..declaredRefreshRate = 90
        ..report([13])
        ..currentFrameNumber = 14;
      final window = frames.stop();
      source.report([14, 15]);

      final reads = (await window).refreshRateReads;
      expect([for (final read in reads) read.hertz], [120, 120, 90, 90]);
      expect([for (final read in reads) read.afterSamples], [0, 2, 3, 3]);
    });

    test('are taken on a batch of stale frames too', () async {
      final frames = recorder()..start();
      source.report([9, 10]);
      final window = frames.stop();
      source.report([11]);

      final reads = (await window).refreshRateReads;
      expect([for (final read in reads) read.afterSamples], [0, 0, 0]);
    });

    test('are not taken during the wait after the end', () async {
      final frames = recorder()..start();
      source.currentFrameNumber = 12;
      final window = frames.stop();
      source
        ..declaredRefreshRate = 60
        ..report([11])
        ..report([12, 13]);

      final reads = (await window).refreshRateReads;
      expect([for (final read in reads) read.hertz], [120, 120]);
    });

    test('keep a rate that is not valid, for the guards', () async {
      source.declaredRefreshRate = 0;
      final frames = recorder()..start();
      final window = frames.stop();
      source.report([11]);

      final reads = (await window).refreshRateReads;
      expect([for (final read in reads) read.hertz], [0, 0]);
    });
  });

  group('FrameRecorder flush', () {
    test('ends when a frame from after the window arrives', () async {
      // The timeout is an hour, so the test would time out if this waited.
      final frames = recorder()..start();
      source.currentFrameNumber = 12;
      final window = frames.stop();
      source
        ..report([11, 12])
        ..report([13]);

      final recorded = await window;
      expect(recorded.flushTimedOut, isFalse);
      expect(frameNumbersOf(recorded), [11, 12]);
    });

    test('keeps waiting while only window frames arrive', () async {
      final frames = FrameRecorder(source, profileFlushTimeout: short)..start();
      source.currentFrameNumber = 12;
      final window = frames.stop();
      source.report([11, 12]);

      expect((await window).flushTimedOut, isTrue);
    });

    test('ends by timeout when no later frame arrives', () async {
      final frames = FrameRecorder(source, profileFlushTimeout: short)..start();
      final recorded = await frames.stop();

      expect(recorded.flushTimedOut, isTrue);
      expect(recorded.flushMicros, greaterThanOrEqualTo(short.inMicroseconds));
    });

    test('uses the release timeout in a release build', () async {
      final frames = FrameRecorder(
        source,
        profileFlushTimeout: never,
        releaseFlushTimeout: short,
        releaseMode: true,
      )..start();

      expect((await frames.stop()).flushTimedOut, isTrue);
    });

    test('uses the profile timeout outside a release build', () async {
      // Tests run in debug, where the profile timeout applies.
      final frames = FrameRecorder(
        source,
        profileFlushTimeout: short,
        releaseFlushTimeout: never,
      )..start();

      expect((await frames.stop()).flushTimedOut, isTrue);
    });
  });

  group('FrameRecorder cost', () {
    test('counts the time spent in every callback of the window', () async {
      final frames = recorder(stopwatch: FakeStopwatch())..start();
      source
        ..report([11])
        ..report([12])
        ..currentFrameNumber = 12;
      final window = frames.stop();
      source.report([13]);

      // Three callbacks, two while recording and one during the wait, each
      // measured as one tick.
      expect((await window).callbackMicros, 3 * FakeStopwatch.tick);
    });

    test('starts from zero for each window', () async {
      final frames = recorder(stopwatch: FakeStopwatch())..start();
      source.report([11]);
      var window = frames.stop();
      source.report([12]);
      await window;

      frames.start();
      window = frames.stop();
      source.report([13]);

      expect((await window).callbackMicros, FakeStopwatch.tick);
    });
  });

  group('FrameRecorder state', () {
    test('cannot start twice', () {
      final frames = recorder()..start();
      expect(frames.start, throwsStateError);
    });

    test('cannot stop before it starts', () async {
      await expectLater(recorder().stop, throwsStateError);
    });

    test('cannot stop while stopping', () async {
      final frames = recorder()..start();
      final window = frames.stop();
      await expectLater(frames.stop, throwsStateError);
      source.report([11]);
      await window;
    });
  });

  group('EngineFrameSource', () {
    testWidgets('reads the refresh rate of the view it is given', (
      tester,
    ) async {
      tester.view.display.refreshRate = 90;
      addTearDown(tester.view.display.resetRefreshRate);

      final source = EngineFrameSource(view: tester.view);
      expect(source.declaredRefreshRate, 90);
    });
  });
}
