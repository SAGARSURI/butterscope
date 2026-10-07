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
}
