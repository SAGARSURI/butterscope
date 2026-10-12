import 'package:flutter_test/flutter_test.dart';

import '../tool/m6/semantics_spread.dart';

void main() {
  Map<String, Object?> span(
    String name, {
    Map<String, Object?> metrics = const {},
    List<bool> semantics = const [true, true],
    bool valid = true,
  }) {
    return {
      'kind': 'span',
      'name': name,
      'valid': valid,
      'reasons': valid
          ? const []
          : const [
              ['tooFewVsyncs', 'span', '3.0'],
            ],
      'semantics': semantics,
      'metrics': metrics,
    };
  }

  Map<String, Object?> report(
    List<Map<String, Object?>> parts, {
    List<List<Object?>> reasons = const [],
  }) {
    return {'valid': reasons.isEmpty, 'reasons': reasons, 'parts': parts};
  }

  group('Spread', () {
    test('takes the middle value of an odd count, and max less min', () {
      final spread = Spread([3, 1, 2, 5, 4]);

      expect(spread.median, 3);
      expect(spread.width, 4);
    });

    test('takes the lower middle value of an even count', () {
      // Nearest rank: ceil(4 / 2) = 2, so the 2nd smallest value.
      expect(Spread([4, 1, 3, 2]).median, 2);
    });
  });

  test('spanValues gathers each span over the runs, skipping a gap', () {
    final values = spanValues([
      report([
        span('feed scroll', metrics: {'hitchRatio': 2.5}),
        span('search typing', metrics: {'hitchRatio': 7}),
        {
          'kind': 'test',
          'name': 'Feed',
          'metrics': {'hitchRatio': 9},
        },
      ]),
      report([
        span('feed scroll', metrics: {'hitchRatio': 3.5}),
        span('search typing'),
      ]),
    ], 'hitchRatio');

    expect(values, {
      'feed scroll': [2.5, 3.5],
      'search typing': [7.0],
    });
  });

  group('semanticsProblems', () {
    test('accepts a valid run whose spans all read its group', () {
      final json = report([
        span('feed scroll', semantics: [false, false]),
      ]);

      expect(semanticsProblems(json, on: false), isEmpty);
    });

    test('names a void run, a void span and a span that read otherwise', () {
      final json = report(
        [
          span('detail open', valid: false),
          span('feed scroll', semantics: [true, false]),
        ],
        reasons: [
          ['thermal', 'run end', 'fair'],
        ],
      );

      expect(semanticsProblems(json, on: true), [
        'The run is void: thermal',
        'Span detail open is void',
        'Span feed scroll read semantics [true, false], not true',
      ]);
    });

    test('counts a run void by an allowed guard, not a span of its own', () {
      // The writer marks every span of a void run invalid with no span
      // reason, as feed scroll here; detail open names its own guard.
      final json = report(
        [
          span('detail open', valid: false),
          {...span('feed scroll'), 'valid': false},
        ],
        reasons: [
          ['thermal', 'run end', 'fair'],
        ],
      );

      expect(semanticsProblems(json, on: true, allow: {'thermal'}), [
        'Span detail open is void',
      ]);
    });

    test('names a void run that gives no reason', () {
      final json = {
        ...report([span('feed scroll')]),
        'valid': false,
      };

      expect(semanticsProblems(json, on: true), [
        'The run is void with no reason given',
      ]);
    });

    test('names a part that flags a rate mismatch', () {
      // A screen held at 60 Hz under a declared 120 Hz, as the iPhone's
      // Limit Frame Rate does: the span is valid but flags the slice.
      final json = report([
        span(
          'feed scroll',
          metrics: {
            'rateMismatches': [
              [0, 60, 60.0],
            ],
          },
        ),
      ]);

      expect(semanticsProblems(json, on: true), [
        'span feed scroll flags a rate mismatch: [[0, 60, 60.0]]',
      ]);
    });
  });

  test('spreadTable puts on and off side by side, and a missing side', () {
    final table = spreadTable(
      'missedVsyncs',
      {
        'feed scroll': [4, 0, 2],
        'search typing': [12, 10, 20],
      },
      {
        'feed scroll': [1, 0, 1],
      },
    );

    // feed scroll on: sorted 0, 2, 4, so median 2 and spread 4 - 0 = 4.
    // feed scroll off: sorted 0, 1, 1, so median 1 and spread 1.
    // search typing on: sorted 10, 12, 20, so median 12 and spread 10.
    const header =
        '| Span | Runs on | Median on | Spread on | Runs off | Median off '
        '| Spread off |';
    expect(table.split('\n'), [
      '#### missedVsyncs',
      '',
      header,
      '| --- | --- | --- | --- | --- | --- | --- |',
      '| feed scroll | 3 | 2.00 | 4.00 | 3 | 1.00 | 1.00 |',
      '| search typing | 3 | 12.00 | 10.00 | 0 |  |  |',
    ]);
  });
}
