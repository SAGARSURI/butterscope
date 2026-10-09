import 'package:flutter_test/flutter_test.dart';

import '../tool/m5/report_log.dart';

void main() {
  group('readReports', () {
    test('joins a run whose lines came twice and out of order', () {
      // The transcript and logcat each carry the run; logcat's prefix
      // differs and its copy comes after.
      const log = '''
I/flutter: BSCOPE-REPORT 7 2 2 "frames":3}
flutter: BSCOPE-REPORT 7 1 2 {"schema":0,
other output
I/flutter: BSCOPE-REPORT 7 1 2 {"schema":0,
''';

      final report = readReports(log).single;

      expect(report.problems, isEmpty);
      expect(report.json, {'schema': 0, 'frames': 3});
    });

    test('names the chunks a run is missing', () {
      const log = '''
BSCOPE-REPORT 7 1 3 {"schema":0,
BSCOPE-REPORT 7 3 3 }
''';

      final report = readReports(log).single;

      expect(report.json, isNull);
      expect(report.problems, ['Run 7: missing chunk(s) 2 of 3']);
    });
  });

  group('LoggedReport.unusable', () {
    LoggedReport reportOf(Map<String, Object?> json) {
      return LoggedReport('7', json, const []);
    }

    Map<String, Object?> testPart(Object? observedHz, {int frames = 40}) {
      return {
        'kind': 'test',
        'name': 'Feed scrolls',
        'frames': frames,
        'metrics': {'observedHz': observedHz},
      };
    }

    test('accepts a profile report with frames and a test', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 120,
        'flushTimedOut': false,
        'parts': [testPart(119.6)],
      });

      expect(report.unusable(minHz: 114), isEmpty);
    });

    test('rejects a report that measured nothing', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 0,
        'flushTimedOut': false,
        'parts': <Object?>[],
      });

      expect(report.unusable(), [
        'The report holds no frames',
        'The report holds no tests',
      ]);
    });

    test('fails the warm-up on a test with no observed rate', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 3,
        'flushTimedOut': false,
        'parts': [testPart(null)],
      });

      expect(report.unusable(minHz: 114), [
        'Feed scrolls has no observed rate',
      ]);
      expect(report.unusable(), isEmpty);
    });

    test('leaves a test too short for a rate out of the warm-up', () {
      // 10 frames give 9 gaps, one short of the 10 a rate needs (0001,
      // decision 6). The app launching at 60 Hz is not a capped screen.
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 50,
        'flushTimedOut': false,
        'parts': [testPart(60, frames: 10), testPart(119.8, frames: 11)],
      });

      expect(report.unusable(minHz: 114), isEmpty);
    });

    test('checks the rate of a test of 11 frames', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 11,
        'flushTimedOut': false,
        'parts': [testPart(60, frames: 11)],
      });

      expect(report.unusable(minHz: 114), [
        'Feed scrolls drew at 60.0 Hz, under 114.0',
      ]);
    });

    test('fails the warm-up when no test is long enough to check', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 10,
        'flushTimedOut': false,
        'parts': [testPart(60, frames: 10)],
      });

      expect(report.unusable(minHz: 114), [
        'No test drew 11 frames, enough to check its rate',
      ]);
      expect(report.unusable(), isEmpty);
    });

    test('rejects a span with no metrics', () {
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 3,
        'flushTimedOut': false,
        'parts': [
          testPart(119.6),
          {'kind': 'span', 'name': 'feed scroll'},
        ],
      });

      expect(report.unusable(), ['Span feed scroll has no metrics']);
    });

    test('holds only tests to the warm-up rate', () {
      // A short span can have too few frames for an observed rate.
      final report = reportOf({
        'buildMode': 'profile',
        'frames': 3,
        'flushTimedOut': false,
        'parts': [
          testPart(119.6),
          {
            'kind': 'span',
            'name': 'feed scroll',
            'metrics': {'observedHz': null},
          },
        ],
      });

      expect(report.unusable(minHz: 114), isEmpty);
    });
  });
}
