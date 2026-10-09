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
}
