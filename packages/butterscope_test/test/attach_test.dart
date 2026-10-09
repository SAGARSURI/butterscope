// A test file that attaches as a team would, with a fake frame source in
// place of the engine. Butterscope's report is printed after the last test,
// so the checks run in a tearDownAll registered before the attach: those
// run in reverse order, so it runs after the report is printed.

import 'package:butterscope_test/src/attach.dart';
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_run.dart';

void main() {
  final printed = <String>[];
  final source = FakeFrameSource();

  tearDownAll(() {
    final report = reportIn(printed);
    final parts = report['parts']! as List<Object?>;
    final tests = [for (final part in parts) part! as Map<String, Object?>];

    expect(report['schema'], 0);
    expect(report['buildMode'], 'debug');
    expect(
      [for (final test in tests) test['name']],
      [
        'the frame policy is benchmarkLive',
        'the text cursor holds still',
        'Feed scrolls smoothly',
        'Feed janks once',
      ],
    );
    expect(
      [for (final test in tests) test['kind']],
      [for (var i = 0; i < 4; i++) 'test'],
    );
    // Each test keeps its own frames. The 4 rendered after each test belong
    // to none, but are in the run: 2 + 0 + 10 + 6 + 4 × 4 = 34.
    expect([for (final test in tests) test['frames']], [2, 0, 10, 6]);
    expect(report['frames'], 34);

    final smooth = tests[2]['metrics']! as Map<String, Object?>;
    expect(smooth['janky'], 0);
    expect(smooth['hitchRatio'], 0);

    // One frame of 12 ms against a budget of 8.33 ms at 120 Hz.
    final janky = tests[3]['metrics']! as Map<String, Object?>;
    expect(janky['janky'], 1);
    expect(janky['jankyRate'], 1 / 6);
    final diagnostics = tests[3]['diagnostics']! as Map<String, Object?>;
    // Builds of 2, 2, 2, 2, 2 and 12 ms: 22 ms over 6 frames.
    expect(diagnostics['avgBuildMs'], closeTo(22 / 6, 1e-9));
  });

  // Registered before the attach, so it runs after the test has ended.
  tearDown(() => source.render(4));

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachTo(binding, source, ReportWriter(printed.add, chunkLength: 100));
  // A second attach, as from another file's main, changes nothing.
  attachTo(binding, source, ReportWriter(printed.add));

  test('the frame policy is benchmarkLive', () {
    expect(
      binding.framePolicy,
      LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive,
    );
    source.render(2);
  });

  test('the text cursor holds still', () {
    expect(EditableText.debugDeterministicCursor, isTrue);
  });

  group('Feed', () {
    testWidgets('scrolls smoothly', (tester) async {
      source.render(10);
    });

    testWidgets('janks once', (tester) async {
      source
        ..render(4)
        ..render(1, buildMicros: 12000)
        ..render(1);
    });
  });
}
