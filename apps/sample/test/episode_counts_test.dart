import 'package:butterscope/episodes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/m5/episode_counts.dart';

void main() {
  group('episodeCounts', () {
    // Two tests at 8333 µs a frame. The first has input at frames 10 and
    // 60, 50 frames (416 650 µs) apart; the second an animation from frame
    // 150 to 160 after input at 110 to 112, 38 frames (316 654 µs) apart.
    final json = <String, Object?>{
      'parts': [
        for (final (name, start, end) in [
          ('Feed', 0, 100),
          ('Search', 100, 200),
        ])
          {
            'kind': 'test',
            'name': name,
            'startFrame': start,
            'endFrame': end,
            'startMicros': start * 8333,
            'endMicros': end * 8333,
          },
        {'kind': 'span', 'name': 'feed scroll'},
      ],
      'activity': [
        ['input', 10, 10 * 8333, 10, 10 * 8333],
        ['input', 60, 60 * 8333, 60, 60 * 8333],
        ['input', 110, 110 * 8333, 112, 112 * 8333],
        ['animation', 150, 150 * 8333, 160, 160 * 8333],
      ],
      'pages': <Object?>[],
    };

    test('splits each test again by the rule given', () {
      expect(episodeCounts(json, EpisodeRule.inputOrAnimation), {
        'Feed': 2,
        'Search': 2,
      });
      expect(episodeCounts(json, EpisodeRule.inputOnly), {
        'Feed': 2,
        'Search': 1,
      });
      const halfSecond = EpisodeRule(
        countsAnimation: true,
        quiet: Duration(milliseconds: 500),
      );
      expect(episodeCounts(json, halfSecond), {'Feed': 1, 'Search': 1});
    });

    test('splits on page changes in the report', () {
      final withPage = {
        ...json,
        'pages': [
          [50, 50 * 8333, '/detail', true],
        ],
      };

      // Frame 50 is 40 frames after the input at 10, so the page cuts.
      expect(episodeCounts(withPage, EpisodeRule.inputOnly)['Feed'], 3);
    });
  });

  test('repeats counts the runs with the most common count', () {
    expect(repeats([2, 2, 3, 2, 2]), 4);
    expect(repeats([1, 2, 3]), 1);
    expect(repeats([]), 0);
  });

  test('compares rules A and B at four quiet stretches', () {
    expect(
      [for (final (label, _) in candidateRules) label],
      [
        'A 150ms',
        'A 300ms',
        'A 500ms',
        'A 1000ms',
        'B 150ms',
        'B 300ms',
        'B 500ms',
        'B 1000ms',
      ],
    );
  });
}
