// A test file that attaches as a team would, with fake frame and activity
// sources in place of the engine, and checks the episodes in the printed
// report. Frames run 8333 µs apart, so 36 frames (300 ms less 12 µs) are
// just short of the 300 ms without input that starts an episode, and 37
// frames (308 321 µs) are enough.

import 'package:butterscope_test/src/attach.dart';
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_run.dart';

void main() {
  final printed = <String>[];
  final source = FakeFrameSource();
  final activity = FakeActivitySource();

  tearDownAll(() {
    final report = reportIn(printed);
    final parts = (report['parts']! as List<Object?>)
        .cast<Map<String, Object?>>();
    String describe(Map<String, Object?> part) {
      final page = part['page'] == null ? '' : ' on ${part['page']}';
      return '${part['kind']} ${part['name']}$page: '
          '${part['startFrame']}-${part['endFrame']}';
    }

    // Each test's episodes come just before it.
    expect(
      [for (final part in parts) describe(part)],
      [
        'episode episode 1: 0-50',
        'test a test with no activity is one episode: 0-50',
        // Taps at frames 52 and 53 are one stretch; 36 quiet frames later
        // (89) is too soon; 37 after 89 (126) starts episode 2.
        'episode episode 1: 50-126',
        'episode episode 2: 126-180',
        'test input after a quiet stretch starts an episode: 50-180',
        // Episodes split on input only, so animations from 185 to 200 and
        // from 237, 37 frames later, start none.
        'episode episode 1: 180-260',
        'test animation alone starts no episode: 180-260',
        // The app's first page cuts nothing. The tap at 302, 40 frames
        // after the one at 262, starts episode 2, and the page it opens at
        // 304 joins it.
        'episode episode 1 on /: 260-302',
        'episode episode 2 on detail: 302-340',
        'test a page change tags the episode: 260-340',
      ],
    );
    // Each part has its times, so a reader can split the tests again.
    expect(parts.first['startMicros'], 0);
    expect(parts.first['endMicros'], 50 * 8333);
    for (final part in parts) {
      if (part['kind'] != 'episode') continue;
      expect(part['metrics'], isA<Map<String, Object?>>());
      expect(part['diagnostics'], isA<Map<String, Object?>>());
    }
    final episodeTests = {
      for (final part in parts)
        if (part['kind'] == 'episode') part['test'],
    };
    expect(episodeTests, hasLength(4));
    // The activity itself is in the report, so a reader can split again.
    expect(
      report['activity'],
      contains(equals(['input', 52, 52 * 8333, 53, 53 * 8333])),
    );
    expect(report['pages'], [
      [262, 262 * 8333, '/', false],
      [304, 304 * 8333, 'detail', true],
    ]);
  });

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachTo(binding, source, activity, ReportWriter(printed.add));

  test('a test with no activity is one episode', () {
    source.render(50);
  });

  test('input after a quiet stretch starts an episode', () {
    source.render(2);
    final reads = source.rateReads;
    activity
      ..input()
      ..input()
      ..input();
    // Three events in one frame are one mark, with one read of the rate.
    expect(source.rateReads - reads, 1);
    source.render(1);
    activity.input();
    source.render(36);
    activity.input();
    source.render(37);
    activity.input();
    source.render(54);
  });

  test('animation alone starts no episode', () {
    source.render(5);
    activity.animating(animating: true);
    source.render(15);
    activity.animating(animating: false);
    source.render(37);
    activity.animating(animating: true);
    source.render(23);
    activity.animating(animating: false);
  });

  test('a page change tags the episode', () {
    source.render(2);
    activity
      ..pageShown('/', first: true)
      ..input();
    source.render(40);
    activity.input();
    source.render(2);
    activity.pageShown('detail');
    source.render(36);
  });
}
