import 'dart:convert';

import 'package:butterscope/butterscope.dart';
import 'package:flutter_test/flutter_test.dart';

const identity = RunIdentity(
  platform: 'android',
  device: null,
  buildMode: 'profile',
  flutterVersion: '3.47.6',
  engineRevision: 'abc',
  appCommit: 'unknown',
  textScale: 1,
  locale: 'en-GB',
);

void main() {
  RecordedWindow windowOf(List<int> frameNumbers) {
    return RecordedWindow(
      startFrameNumber: 0,
      endFrameNumber: frameNumbers.last,
      samples: [
        for (final number in frameNumbers)
          FrameSample(
            vsyncStartMicros: number * 8333,
            buildMicros: 2000,
            rasterMicros: 2000,
            frameNumber: number,
          ),
      ],
      refreshRateReads: const [],
      flushTimedOut: false,
      flushMicros: 0,
      callbackMicros: 0,
    );
  }

  test('reports a part with no metrics when its rate gives no budget', () {
    final report = RunReport(
      windowOf([1, 2, 3]),
      const [
        MarkedPart(
          PartKind.test,
          'opens',
          FrameMark(frameNumber: 0, declaredRefreshRate: 0, micros: 0),
          FrameMark(frameNumber: 3, declaredRefreshRate: 0, micros: 0),
        ),
      ],
      runId: 7,
      identity: identity,
    ).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    expect(part['frames'], 3);
    expect(part['declaredHz'], 0);
    expect(part.containsKey('metrics'), isFalse);
  });

  test("judges a part against its start's declared rate", () {
    // Builds of 2 ms are smooth at 120 Hz (8.33 ms) and janky at 600 Hz
    // (1.67 ms), whatever the rate read at the end.
    final report = RunReport(
      windowOf([1, 2]),
      const [
        MarkedPart(
          PartKind.test,
          'opens',
          FrameMark(frameNumber: 0, declaredRefreshRate: 600, micros: 0),
          FrameMark(frameNumber: 2, declaredRefreshRate: 120, micros: 0),
        ),
      ],
      runId: 7,
      identity: identity,
    ).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['janky'], 2);
    expect(part['declaredHzAtEnd'], 120);
  });

  test('writes a rate that is not finite as null, so JSON can hold it', () {
    final report = RunReport(
      windowOf([1]),
      const [
        MarkedPart(
          PartKind.test,
          'opens',
          FrameMark(frameNumber: 0, declaredRefreshRate: double.nan, micros: 0),
          FrameMark(
            frameNumber: 1,
            declaredRefreshRate: double.infinity,
            micros: 0,
          ),
        ),
      ],
      runId: 7,
      identity: identity,
    ).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    expect(part['declaredHz'], isNull);
    expect(part['declaredHzAtEnd'], isNull);
    expect(part.containsKey('metrics'), isFalse);
    expect(() => jsonEncode(report), returnsNormally);
  });

  test('lists the seconds whose rate is off the declared one', () {
    // 12 smooth frames 16 667 µs apart, judged at a declared 120 Hz: one
    // slice of 11 gaps reading 1 000 000 ÷ 16 667 = 59.999 Hz.
    final window = RecordedWindow(
      startFrameNumber: 0,
      endFrameNumber: 12,
      samples: [
        for (var i = 0; i < 12; i++)
          FrameSample(
            vsyncStartMicros: i * 16667,
            buildMicros: 2000,
            rasterMicros: 2000,
            frameNumber: i + 1,
          ),
      ],
      refreshRateReads: const [],
      flushTimedOut: false,
      flushMicros: 0,
      callbackMicros: 0,
    );
    final report = RunReport(
      window,
      const [
        MarkedPart(
          PartKind.span,
          'feed scroll',
          FrameMark(frameNumber: 0, declaredRefreshRate: 120, micros: 0),
          FrameMark(frameNumber: 12, declaredRefreshRate: 120, micros: 0),
        ),
      ],
      runId: 7,
      identity: identity,
    ).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['rateSlicesJudged'], 1);
    final mismatch = (metrics['rateMismatches']! as List).single as List;
    expect(mismatch[0], 0);
    expect(mismatch[1], 11);
    expect(mismatch[2] as double, closeTo(59.999, 0.001));
  });

  test('says a part too short for a slice was not checked', () {
    final report = RunReport(
      windowOf([1, 2, 3]),
      const [
        MarkedPart(
          PartKind.span,
          'tap',
          FrameMark(frameNumber: 0, declaredRefreshRate: 120, micros: 0),
          FrameMark(frameNumber: 3, declaredRefreshRate: 120, micros: 0),
        ),
      ],
      runId: 7,
      identity: identity,
    ).toJson();

    final part = (report['parts']! as List).single as Map<String, Object?>;
    final metrics = part['metrics']! as Map<String, Object?>;
    expect(metrics['rateSlicesJudged'], 0);
    expect(metrics['rateMismatches'], isEmpty);
  });

  group('validity', () {
    // Frames 8000 µs apart, judged at a declared 125 Hz, where B is
    // exactly 8 ms, so elapsed vsyncs come out whole.
    RecordedWindow windowAt(
      List<int> vsyncs, {
      List<RefreshRateRead> reads = const [],
    }) {
      return RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: vsyncs.length,
        samples: [
          for (var i = 0; i < vsyncs.length; i++)
            FrameSample(
              vsyncStartMicros: vsyncs[i] * 8000,
              buildMicros: 2000,
              rasterMicros: 2000,
              frameNumber: i + 1,
            ),
        ],
        refreshRateReads: reads,
        flushTimedOut: false,
        flushMicros: 0,
        callbackMicros: 0,
      );
    }

    MarkedPart partOf(
      PartKind kind,
      int frames, {
      double endHz = 125,
      ({bool atStart, bool atEnd})? semantics,
      List<GuardFailure> failures = const [],
    }) {
      return MarkedPart(
        kind,
        kind.name,
        const FrameMark(frameNumber: 0, declaredRefreshRate: 125, micros: 0),
        FrameMark(frameNumber: frames, declaredRefreshRate: endHz, micros: 0),
        semantics: semantics,
        failures: failures,
      );
    }

    Map<String, Object?> onlyPart(Map<String, Object?> report) {
      return (report['parts']! as List).single as Map<String, Object?>;
    }

    final twelve = [for (var i = 0; i < 12; i++) i];

    test('a clean run and its span are valid', () {
      final report = RunReport(
        windowAt(twelve),
        [partOf(PartKind.span, 12, semantics: (atStart: false, atEnd: false))],
        runId: 7,
        identity: identity,
      ).toJson();

      expect(report['valid'], isTrue);
      expect(report['reasons'], isEmpty);
      expect((report['identity']! as Map<String, Object?>)['locale'], 'en-GB');
      final span = onlyPart(report);
      expect(span['valid'], isTrue);
      expect(span['reasons'], isEmpty);
      expect(span['semantics'], [false, false]);
    });

    test("a run guard voids the run's spans without naming them", () {
      final report = RunReport(
        windowAt(twelve),
        [partOf(PartKind.span, 12)],
        runId: 7,
        identity: identity,
        failures: const [GuardFailure(Guard.lowPower, 'run start')],
      ).toJson();

      expect(report['valid'], isFalse);
      expect(report['reasons'], [
        ['lowPower', 'run start'],
      ]);
      final span = onlyPart(report);
      expect(span['valid'], isFalse);
      expect(span['reasons'], isEmpty);
    });

    test('a declared rate of 0 anywhere voids the run', () {
      final report = RunReport(
        windowAt(
          twelve,
          reads: const [RefreshRateRead(hertz: 0, afterSamples: 5)],
        ),
        [partOf(PartKind.test, 12)],
        runId: 7,
        identity: identity,
      ).toJson();

      expect(report['valid'], isFalse);
      expect(report['reasons'], [
        ['declaredRate', 'recording', '0.0'],
      ]);
    });

    test('a span under 11 vsyncs is void, missed vsyncs counted', () {
      // Frames at vsyncs 0, 1 and 9: the 8-interval gap is 7 missed
      // vsyncs, so 3 frames + 7 = 10 vsyncs elapsed.
      final short = RunReport(
        windowAt([0, 1, 9]),
        [partOf(PartKind.span, 3)],
        runId: 7,
        identity: identity,
      ).toJson();
      expect(onlyPart(short)['valid'], isFalse);
      expect(onlyPart(short)['reasons'], [
        ['tooFewVsyncs', 'span', '10.0'],
      ]);

      // Frames at vsyncs 0, 1 and 10: 3 frames + 8 missed = 11.
      final enough = RunReport(
        windowAt([0, 1, 10]),
        [partOf(PartKind.span, 3)],
        runId: 7,
        identity: identity,
      ).toJson();
      expect(onlyPart(enough)['valid'], isTrue);
    });

    test('a span of exactly 11 vsyncs at 119.88 Hz is valid', () {
      // B = 1 000 000 / 119.88 = 8341.67 µs. Frames 83 417 µs apart are 10
      // intervals, so 9 missed vsyncs: 2 frames + 9 = 11, which the
      // fractional budget sums to 10.999999999999998 unrounded.
      final window = RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: 2,
        samples: [
          for (final (number, micros) in [(1, 0), (2, 83417)])
            FrameSample(
              vsyncStartMicros: micros,
              buildMicros: 2000,
              rasterMicros: 2000,
              frameNumber: number,
            ),
        ],
        refreshRateReads: const [],
        flushTimedOut: false,
        flushMicros: 0,
        callbackMicros: 0,
      );
      final report = RunReport(
        window,
        [
          const MarkedPart(
            PartKind.span,
            'span',
            FrameMark(frameNumber: 0, declaredRefreshRate: 119.88, micros: 0),
            FrameMark(frameNumber: 2, declaredRefreshRate: 119.88, micros: 0),
          ),
        ],
        runId: 7,
        identity: identity,
      ).toJson();

      final span = onlyPart(report);
      expect((span['metrics']! as Map<String, Object?>)['missedVsyncs'], 9);
      expect(span['reasons'], isEmpty);
    });

    test('a span whose declared rate moved is void', () {
      final report = RunReport(
        windowAt(twelve),
        [partOf(PartKind.span, 12, endHz: 60)],
        runId: 7,
        identity: identity,
      ).toJson();

      expect(report['valid'], isTrue);
      expect(onlyPart(report)['reasons'], [
        ['declaredRateChange', 'span', '125.0 to 60.0'],
      ]);
    });

    test('an episode whose declared rate moved says so, without metrics', () {
      final report = RunReport(
        windowAt(twelve),
        [partOf(PartKind.episode, 12, endHz: 60)],
        runId: 7,
        identity: identity,
      ).toJson();

      final episode = onlyPart(report);
      expect(episode['declaredRateChanged'], isTrue);
      expect(episode.containsKey('metrics'), isFalse);
      expect(episode.containsKey('valid'), isFalse);
    });

    test('a span keeps the failures its recording saw', () {
      final report = RunReport(
        windowAt(twelve),
        [
          partOf(
            PartKind.span,
            12,
            failures: const [GuardFailure(Guard.openAtTestEnd, 'end of opens')],
          ),
        ],
        runId: 7,
        identity: identity,
      ).toJson();

      expect(onlyPart(report)['valid'], isFalse);
      expect(onlyPart(report)['reasons'], [
        ['openAtTestEnd', 'end of opens'],
      ]);
    });
  });

  group('issues', () {
    // Frames 8333 µs apart at a declared 120 Hz, where B is 8333.33 µs.
    RecordedWindow windowWithBuilds(List<int> builds) {
      return RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: builds.length,
        samples: [
          for (final (i, build) in builds.indexed)
            FrameSample(
              vsyncStartMicros: (i + 1) * 8333,
              buildMicros: build,
              rasterMicros: 2000,
              frameNumber: i + 1,
            ),
        ],
        refreshRateReads: const [],
        flushTimedOut: false,
        flushMicros: 0,
        callbackMicros: 0,
      );
    }

    MarkedPart partOf(PartKind kind, int frames, {double endHz = 120}) {
      return MarkedPart(
        kind,
        kind.name,
        const FrameMark(frameNumber: 0, declaredRefreshRate: 120, micros: 0),
        FrameMark(frameNumber: frames, declaredRefreshRate: endHz, micros: 0),
      );
    }

    test('lists the janky frames of spans and episodes, not tests', () {
      final report = RunReport(
        windowWithBuilds([2000, 12000, 2000, 20000]),
        [
          partOf(PartKind.span, 4),
          partOf(PartKind.episode, 4),
          partOf(PartKind.test, 4),
        ],
        runId: 7,
        identity: identity,
      ).toJson();

      // Frame 2 builds in 12 000 µs: 12 000 × 120 / 1 000 000 = 1.44 B,
      // over by 0.44 B and under 2 B, so janky. Frame 4 builds in
      // 20 000 µs: 2.4 B, over by 1.4 B, so severe. Offsets run from frame
      // 1's vsync: 8333 µs and 3 × 8333 = 24 999 µs.
      final issues = (report['issues']! as List).cast<List<Object?>>();
      expect([for (final issue in issues) issue[0]], [0, 0, 1, 1]);
      final span = issues.take(2).toList();
      expect([for (final issue in span) issue[1]], [2, 4]);
      expect(span[0][2], closeTo(8.333, 1e-9));
      expect(span[1][2], closeTo(24.999, 1e-9));
      expect([for (final issue in span) issue[3]], ['ui', 'ui']);
      expect(span[0][4], closeTo(0.44, 1e-9));
      expect(span[1][4], closeTo(1.4, 1e-9));
      expect([for (final issue in span) issue[5]], ['janky', 'severe']);
    });

    test('leaves out a span whose declared rate moved', () {
      final report = RunReport(
        windowWithBuilds([2000, 12000]),
        [partOf(PartKind.span, 2, endHz: 60)],
        runId: 7,
        identity: identity,
      ).toJson();

      expect(report['issues'], isEmpty);
    });
  });

  group('recording', () {
    final report = RunReport(
      const RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: 9,
        samples: [
          FrameSample(
            vsyncStartMicros: 1000,
            buildMicros: 3000,
            rasterMicros: 4000,
            vsyncOverheadMicros: 200,
            frameNumber: 9,
            totalSpanMicros: 7500,
            rasterCache: RasterCacheUse(
              layerCount: 1,
              layerBytes: 2048,
              pictureCount: 3,
              pictureBytes: 4096,
            ),
          ),
        ],
        refreshRateReads: [
          RefreshRateRead(hertz: 120, afterSamples: 0, micros: 500),
          RefreshRateRead(hertz: double.nan, afterSamples: 1),
        ],
        flushTimedOut: false,
        flushMicros: 0,
        callbackMicros: 0,
      ),
      const [],
      runId: 7,
      identity: identity,
    );

    test('writes the frames as rows, apart from the report', () {
      expect(report.frameRows, [
        [9, 1000, 200, 3000, 4000, 7500, 1, 2048, 3, 4096],
      ]);
      final json = report.toJson();
      expect(json['frameCount'], 1);
      expect(json.containsKey('frames'), isFalse);
    });

    test('writes each rate read, a rate that is not finite as null', () {
      expect(report.toJson()['rateReads'], [
        [0, 500, 120.0],
        [1, null, null],
      ]);
    });
  });
}
