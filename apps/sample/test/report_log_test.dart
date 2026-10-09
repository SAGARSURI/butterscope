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

    Map<String, Object?> testPart(Object? observedHz) {
      return {
        'kind': 'test',
        'name': 'Feed scrolls',
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
