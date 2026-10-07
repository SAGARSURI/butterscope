// A test file that attaches as a team would, with a fake frame source in
// place of the engine. Butterscope's report is printed after the last test,
// so the checks run in a tearDownAll registered before the attach: those
// run in reverse order, so it runs after the report is printed.

import 'dart:convert';
import 'dart:ui';

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/attach.dart';
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// A frame source the tests advance by hand.
class FakeFrameSource implements FrameSource {
  TimingsCallback? _callback;

  @override
  int currentFrameNumber = 0;

  @override
  double declaredRefreshRate = 120;

  @override
  void addTimingsCallback(TimingsCallback callback) => _callback = callback;

  @override
  void removeTimingsCallback(TimingsCallback callback) => _callback = null;

  /// Begins and reports [count] frames, 8333 µs apart, each with
  /// [buildMicros] of build time.
  void render(int count, {int buildMicros = 2000}) {
    final timings = <FrameTiming>[];
    for (var i = 0; i < count; i++) {
      final number = ++currentFrameNumber;
      final vsync = number * 8333;
      timings.add(
        FrameTiming(
          vsyncStart: vsync,
          buildStart: vsync,
          buildFinish: vsync + buildMicros,
          rasterStart: vsync + buildMicros,
          rasterFinish: vsync + buildMicros + 1000,
          rasterFinishWallTime: vsync + buildMicros + 1000,
          frameNumber: number,
        ),
      );
    }
    _callback?.call(timings);
  }
}

/// Joins the printed chunks of the one run in [lines] and decodes it.
Map<String, Object?> reportIn(List<String> lines) {
  final chunks = [
    for (final line in lines)
      if (line.startsWith('$reportTag ')) line.split(' ').skip(4).join(' '),
  ];
  return jsonDecode(chunks.join()) as Map<String, Object?>;
}

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
        'Feed scrolls smoothly',
        'Feed janks once',
      ],
    );
    expect([for (final test in tests) test['kind']], ['test', 'test', 'test']);
    // Each test keeps its own frames. The 4 rendered after each test belong
    // to none, but are in the run: 2 + 10 + 6 + 3 × 4 = 30.
    expect([for (final test in tests) test['frames']], [2, 10, 6]);
    expect(report['frames'], 30);

    final smooth = tests[1]['metrics']! as Map<String, Object?>;
    expect(smooth['janky'], 0);
    expect(smooth['hitchRatio'], 0);

    // One frame of 12 ms against a budget of 8.33 ms at 120 Hz.
    final janky = tests[2]['metrics']! as Map<String, Object?>;
    expect(janky['janky'], 1);
    expect(janky['jankyRate'], 1 / 6);
    final diagnostics = tests[2]['diagnostics']! as Map<String, Object?>;
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
