// A test file that attaches and opens spans as a team would, with a fake
// frame source in place of the engine. The checks run in a tearDownAll
// registered before the attach, so they run after the report is printed.

import 'package:butterscope_test/butterscope_test.dart';
import 'package:butterscope_test/src/attach.dart' show attachTo;
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_run.dart';

void main() {
  final printed = <String>[];
  final source = FakeFrameSource();

  tearDownAll(() {
    final parts = [
      for (final part in reportIn(printed)['parts']! as List<Object?>)
        part! as Map<String, Object?>,
    ];

    // In the order they ended: each span before the test it is in. The
    // inner span that was refused and the repeated name are not there.
    expect(
      [for (final part in parts) '${part['kind']} ${part['name']}'],
      [
        'span feed scroll',
        'test a span holds the frames its body produced',
        'span answer',
        'test a span returns what its body returns',
        'span failing',
        'test a span ends when its body throws',
        'span outer',
        'test spans do not nest',
        'test a span name is used once per run',
      ],
    );
    expect(
      [for (final part in parts) part['frames']],
      [4, 7, 0, 0, 3, 3, 2, 2, 0],
    );

    // The span's 4 frames hold the one 12 ms frame; its test's 7 add the 2
    // before and the 1 after, all smooth.
    final scroll = parts[0]['metrics']! as Map<String, Object?>;
    expect(scroll['janky'], 1);
    expect(scroll['jankyRate'], 1 / 4);
    final test = parts[1]['metrics']! as Map<String, Object?>;
    expect(test['jankyRate'], 1 / 7);

    // A span carries the same metrics as a test: every gate metric and
    // every diagnostic in DESIGN section 5.
    expect(scroll.keys, unorderedEquals(test.keys));
    expect(scroll.keys, hasLength(19));
    final diagnostics = parts[0]['diagnostics']! as Map<String, Object?>;
    expect(
      diagnostics.keys,
      unorderedEquals(<String>[
        'avgUiMs',
        'avgBuildMs',
        'avgRasterMs',
        'vsyncOverheadP90Ms',
        'vsyncOverheadP99Ms',
        'totalSpanP90Ms',
        'totalSpanP99Ms',
        'rasterCachePeak',
      ]),
    );
    // Builds of 2, 2, 2 and 12 ms: 18 ms over 4 frames.
    expect(diagnostics['avgBuildMs'], closeTo(18 / 4, 1e-9));
  });

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachTo(binding, source, ReportWriter(printed.add));

  setUpAll(() async {
    await expectLater(span('outside', () async {}), throwsStateError);
  });

  testWidgets('a span holds the frames its body produced', (tester) async {
    source.render(2);
    await span('feed scroll', () async {
      source
        ..render(3)
        ..render(1, buildMicros: 12000);
    });
    source.render(1);
  });

  testWidgets('a span returns what its body returns', (tester) async {
    expect(await span('answer', () async => 42), 42);
  });

  testWidgets('a span ends when its body throws', (tester) async {
    await expectLater(
      span('failing', () async {
        source.render(3);
        throw const FormatException('body failed');
      }),
      throwsFormatException,
    );
  });

  testWidgets('spans do not nest', (tester) async {
    await span('outer', () async {
      source.render(2);
      await expectLater(span('inner', () async {}), throwsStateError);
    });
  });

  testWidgets('a span name is used once per run', (tester) async {
    await expectLater(span('feed scroll', () async {}), throwsArgumentError);
  });
}
