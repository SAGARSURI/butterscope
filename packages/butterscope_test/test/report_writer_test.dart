import 'dart:convert';

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_report/butterscope_report.dart';
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RunReport reportOf(int frames) {
    return RunReport(
      RecordedWindow(
        startFrameNumber: 0,
        endFrameNumber: frames,
        samples: [
          for (var number = 1; number <= frames; number++)
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
      ),
      const [],
      runId: 42,
      identity: const RunIdentity(
        platform: 'android',
        device: null,
        buildMode: 'profile',
        flutterVersion: '3.47.6',
        engineRevision: 'abc',
        appCommit: 'unknown',
        textScale: 1,
        locale: 'en-GB',
      ),
    );
  }

  test('prints the start line for the run id it is given', () {
    final lines = <String>[];
    ReportWriter(lines.add).start(42);

    expect(lines, ['BSCOPE 42 start']);
  });

  test('prints the report lines, then the frame lines', () async {
    final lines = <String>[];
    // 5 frames at 2 a line: lines of 2, 2 and 1.
    await ReportWriter(
      lines.add,
      chunkLength: 100,
      framesPerLine: 2,
    ).write(reportOf(5));

    final kinds = [for (final line in lines) line.split(' ')[2]];
    expect(kinds.where((kind) => kind == 'frames'), hasLength(3));
    expect(kinds.indexOf('frames'), kinds.lastIndexOf('report') + 1);
  });

  test('prints lines a reader reads back whole', () async {
    final lines = <String>[];
    final report = reportOf(5);
    final writer = ReportWriter(lines.add, framesPerLine: 2)..start(42);
    await writer.write(report);

    final run = readLog(lines).runs.single;
    expect(run.isWhole, isTrue);
    expect(run.started, isTrue);
    // Doubles such as the text scale come back as JSON wrote them.
    expect(run.report, jsonDecode(jsonEncode(report.toJson())));
    expect(run.frames, report.frameRows);
  });

  test('pauses after every few lines, and not after the last', () async {
    final events = <String>[];
    // 5 frames at 1 a line, after the report's lines.
    await ReportWriter(
      (_) => events.add('line'),
      framesPerLine: 1,
      linesPerPause: 2,
      pause: const Duration(milliseconds: 7),
      wait: (pause) async => events.add('pause ${pause.inMilliseconds}'),
    ).write(reportOf(5));

    final lines = events.where((event) => event == 'line').length;
    // A pause between each pair of lines: (lines - 1) ~/ 2 of them.
    expect(events.length - lines, (lines - 1) ~/ 2);
    for (final (i, event) in events.indexed) {
      // Two lines, then a pause: every third event is a pause.
      expect(event, i % 3 == 2 ? 'pause 7' : 'line');
    }
    expect(events.last, 'line');
  });

  test('refuses a line that could not carry anything', () {
    expect(() => ReportWriter((_) {}, chunkLength: 0), throwsRangeError);
    expect(() => ReportWriter((_) {}, framesPerLine: 0), throwsRangeError);
    expect(() => ReportWriter((_) {}, linesPerPause: 0), throwsRangeError);
  });
}
