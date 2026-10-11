import 'package:flutter_test/flutter_test.dart';

import '../tool/m6/validity.dart';

void main() {
  Map<String, Object?> span(
    String name, {
    List<List<Object?>> reasons = const [],
    List<List<Object?>> mismatches = const [],
    int slices = 1,
  }) {
    return {
      'kind': 'span',
      'name': name,
      'valid': reasons.isEmpty,
      'reasons': reasons,
      'metrics': {'rateSlicesJudged': slices, 'rateMismatches': mismatches},
    };
  }

  Map<String, Object?> report(
    List<Map<String, Object?>> parts, {
    List<List<Object?>> reasons = const [],
  }) {
    return {'valid': reasons.isEmpty, 'reasons': reasons, 'parts': parts};
  }

  group('notClean', () {
    test('accepts a valid run whose spans are valid and flag nothing', () {
      expect(notClean(report([span('feed scroll')])), isEmpty);
    });

    test('names a run guard, a void span and a mismatch', () {
      final json = report(
        [
          span(
            'tap',
            reasons: [
              ['tooFewVsyncs', 'span', '3.0'],
            ],
          ),
          span(
            'scroll',
            mismatches: [
              [1, 59, 60.1],
            ],
          ),
        ],
        reasons: [
          ['lowPower', 'run start'],
        ],
      );
      expect(notClean(json), [
        'The run is void: lowPower',
        'Span tap is void: tooFewVsyncs',
        'span scroll flags a rate mismatch: [[1, 59, 60.1]]',
      ]);
    });

    test('accepts a span void by the guard it should be', () {
      final json = report([
        span(
          'empty',
          reasons: [
            ['tooFewVsyncs', 'span', '0.0'],
          ],
        ),
      ]);
      expect(notClean(json, voidSpans: {'empty': 'tooFewVsyncs'}), isEmpty);
      expect(notClean(report([span('empty')]), voidSpans: {'empty': 'x'}), [
        'Span empty should be void by x alone, not []',
      ]);
    });

    test('names a span it should check that the report lacks', () {
      expect(
        notClean(
          report([span('feed scroll')]),
          voidSpans: {'empty': 'tooFewVsyncs'},
        ),
        ['Span empty is not in the report'],
      );
    });
  });

  group('notVoidedBy', () {
    test('accepts a run void by the forced guard alone', () {
      final json = report(
        [span('scroll')],
        reasons: [
          ['thermal', 'run start', 'serious'],
        ],
      );
      expect(notVoidedBy(json, 'thermal'), isEmpty);
    });

    test('names a missing guard and any other', () {
      final json = report(
        [span('scroll')],
        reasons: [
          ['lowPower', 'run start'],
        ],
      );
      expect(notVoidedBy(json, 'thermal'), [
        'The run is not void by thermal',
        'The run is also void by lowPower',
      ]);
    });
  });

  group('notFlagged', () {
    test('accepts a run where every judged part flags a mismatch', () {
      final json = report([
        span(
          'scroll',
          mismatches: [
            [0, 59, 60.0],
          ],
        ),
        span('tap', slices: 0),
      ]);
      expect(notFlagged(json), isEmpty);
    });

    test('names a judged part that flags nothing, or no judged part', () {
      expect(notFlagged(report([span('scroll')])), [
        'span scroll flags no mismatch',
      ]);
      expect(notFlagged(report([span('tap', slices: 0)])), [
        'No part had a slice to judge',
      ]);
    });
  });

  test('unexpectedIncomplete lets a frame-policy run time out its flush', () {
    const problems = ['A flush timed out', 'The report holds no tests'];

    expect(unexpectedIncomplete(problems, 'framePolicy'), [
      'The report holds no tests',
    ]);
    expect(unexpectedIncomplete(problems, 'lowPower'), problems);
    expect(unexpectedIncomplete(problems, 'clean'), problems);
  });
}
