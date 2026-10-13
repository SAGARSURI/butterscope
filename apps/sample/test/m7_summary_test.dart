import 'package:flutter_test/flutter_test.dart';

import '../tool/m7/summary.dart';

void main() {
  Map<String, Object?> runOf({
    List<Object?> framesMissing = const [],
    bool valid = true,
    List<Object?> reasons = const [],
  }) {
    return {
      'runId': 7,
      'identity': {'platform': 'ios', 'buildMode': 'release'},
      'valid': valid,
      'reasons': reasons,
      'frameCount': 45,
      'parts': [
        {'kind': 'test', 'name': 'a'},
        {'kind': 'span', 'name': 'b'},
      ],
      'issues': [
        [0, 6, 41.665, 'ui', 0.44, 'janky'],
      ],
      'framesMissing': framesMissing,
    };
  }

  test('names the run, its frames and parts, and calls it valid', () {
    expect(
      summarise(runOf()),
      '7  ios release  45 frames, 0 lost, 2 parts, 1 issues, valid',
    );
  });

  test('adds up the frames lost across gaps', () {
    // 20 frames from frame 20, and 5 from frame 40: 25 lost.
    final run = runOf(
      framesMissing: [
        [20, 20],
        [40, 5],
      ],
    );

    expect(summarise(run), contains('45 frames, 25 lost'));
  });

  test('names the guards that voided a run', () {
    final run = runOf(
      valid: false,
      reasons: [
        ['thermal', 'run start', 'serious'],
      ],
    );

    expect(summarise(run), endsWith('void ([thermal])'));
  });
}
