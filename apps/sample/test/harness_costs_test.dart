import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/m5/harness_costs.dart';

void main() {
  group('readCallTimes', () {
    test("reads each span's times, whatever comes before the tag", () {
      const log = '''
I/flutter (12345): BSCOPE-HARNESS still: tap 310,295,402
flutter: BSCOPE-HARNESS feed: find.byKey 1200,1180
a line about something else
''';

      expect(readCallTimes(log), {
        'still: tap': [310, 295, 402],
        'feed: find.byKey': [1200, 1180],
      });
    });

    test('keeps one copy of a line printed twice', () {
      const line = 'BSCOPE-HARNESS search: enterText 2500,2600';

      expect(readCallTimes('$line\n$line\n'), {
        'search: enterText': [2500, 2600],
      });
    });
  });

  group('percentile', () {
    test('takes the nearest rank', () {
      final values = [50, 10, 40, 20, 30, 60, 70, 80, 90, 100];

      // 10 values: the median is the 5th smallest, 50, and p90 the 9th, 90.
      expect(percentile(values, 50), 50);
      expect(percentile(values, 90), 90);
      expect(percentile(values, 100), 100);
    });

    test('has none for no values', () {
      expect(percentile([], 50), isNull);
    });
  });

  group('spanCosts', () {
    Map<String, Object?> run(int tapJanky, int tapMissed) => {
      'parts': [
        {'kind': 'test', 'name': 'still screen'},
        {
          'kind': 'span',
          'name': 'still: empty before',
          'metrics': {'janky': 0, 'missedVsyncs': 0},
        },
        {
          'kind': 'span',
          'name': 'still: tap',
          'metrics': {'janky': tapJanky, 'missedVsyncs': tapMissed},
        },
      ],
    };

    test("lists each span's frames per run beside its call times", () {
      final costs = spanCosts(
        [run(2, 3), run(1, 0)],
        {
          'still: tap': [300, 310, 320],
        },
      );

      expect(
        [for (final cost in costs) cost.name],
        ['still: empty before', 'still: tap'],
      );
      expect(costs.first.callMicros, isEmpty);
      expect(costs.last.callMicros, [300, 310, 320]);
      expect(costs.last.janky, [2, 1]);
      expect(costs.last.missedVsyncs, [3, 0]);
    });

    test('prints a row per span, times in ms', () {
      final table = costTable(
        spanCosts(
          [run(2, 3)],
          {
            'still: tap': [300, 310, 320],
          },
        ),
      );

      // Of 3 calls the median is the 2nd smallest (310 µs) and p90 the
      // 3rd (ceil(2.7) = 3), 320 µs.
      expect(
        table,
        contains('| still: tap | 3 | 0.31 | 0.32 | 0.32 | 2 | 3 |'),
      );
      expect(table, contains('| still: empty before | 0 |  |  |  | 0 | 0 |'));
    });
  });
  group('readRun', () {
    // One usable report: profile mode, frames, a test, and spans with
    // metrics, of which only the tap is a step.
    Map<String, Object?> report({bool flushTimedOut = false}) => {
      'buildMode': 'profile',
      'frames': 1800,
      'flushTimedOut': flushTimedOut,
      'parts': [
        {'kind': 'test', 'name': 'still screen', 'frames': 1800},
        for (final name in ['still: $emptyBefore', 'still: tap'])
          {
            'kind': 'span',
            'name': name,
            'metrics': {'janky': 0, 'missedVsyncs': 0},
          },
      ],
    };
    String reportLine(Map<String, Object?> json) =>
        'BSCOPE-REPORT 7 1 1 ${jsonEncode(json)}';
    final tapLine =
        '$harnessTag still: tap ${List.filled(harnessCalls, 300).join(',')}';

    test('counts a run with a usable report and every call time', () {
      final run = readRun('${reportLine(report())}\n$tapLine\n');

      expect(run.problems, isEmpty);
      expect(run.report, isNotNull);
      expect(run.calls['still: tap'], hasLength(harnessCalls));
    });

    test('does not count a run whose flush timed out', () {
      final run = readRun(
        '${reportLine(report(flushTimedOut: true))}\n$tapLine\n',
      );

      expect(run.problems, ['A flush timed out']);
      expect(run.report, isNull);
    });

    test("does not count a run whose log lost a step's call times", () {
      final run = readRun('${reportLine(report())}\n');

      expect(run.problems, ['still: tap has 0 call times, not $harnessCalls']);
      expect(run.report, isNull);
    });

    test('does not count a run with a call time missing', () {
      final short = List.filled(harnessCalls - 1, 300).join(',');
      final run = readRun(
        '${reportLine(report())}\n$harnessTag still: tap $short\n',
      );

      expect(run.problems, [
        'still: tap has ${harnessCalls - 1} call times, not $harnessCalls',
      ]);
      expect(run.report, isNull);
    });

    test('does not count a log without a report', () {
      final run = readRun('$tapLine\n');

      expect(run.problems, ['Expected one report, found 0']);
      expect(run.report, isNull);
    });
  });
}
