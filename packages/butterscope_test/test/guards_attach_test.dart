// A test file that attaches as a team would and trips span guards, with
// fakes for the engine and the phone. The checks run in a tearDownAll
// registered before the attach, so they run after the report is printed.

import 'dart:async';

import 'package:butterscope_test/butterscope_test.dart';
import 'package:butterscope_test/src/attach.dart' show attachTo;
import 'package:butterscope_test/src/report_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fake_run.dart';

void main() {
  final printed = <String>[];
  final source = FakeFrameSource();
  final reader = FakeGuardReader();
  final never = Completer<void>();

  tearDownAll(() {
    final report = reportIn(printed);
    final spans = {
      for (final part in report['parts']! as List<Object?>)
        if (part case {'kind': 'span', 'name': final String name})
          name: part as Map<String, Object?>,
    };

    // The last test left the frame policy, which voids the whole run.
    expect(report['valid'], isFalse);
    expect(report['reasons'], [
      ['framePolicy', 'end of a test that leaves the frame policy'],
    ]);

    // So no span is valid, but each lists only its own failures.
    expect([
      for (final span in spans.values) span['valid'],
    ], everyElement(false));
    expect(spans['scroll']!['reasons'], isEmpty);
    expect(spans['scroll']!['semantics'], [true, false]);
    // 3 frames, back to back: 3 vsyncs.
    expect(spans['tap']!['reasons'], [
      ['tooFewVsyncs', 'span', '3.0'],
    ]);
    expect(spans['stuck']!['reasons'], [
      ['openAtTestEnd', 'end of a span still open when its test ends'],
    ]);
    // The stuck span holds its test's frames up to the test's end.
    expect(spans['stuck']!['frames'], 12);
    expect(spans['after']!['reasons'], isEmpty);
  });

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  attachTo(
    binding,
    source,
    FakeActivitySource(),
    reader,
    ReportWriter(printed.add),
  );

  testWidgets('a span records whether semantics was on', (tester) async {
    reader.semanticsOn = true;
    await span('scroll', () async {
      source.render(12);
      reader.semanticsOn = false;
    });
  });

  testWidgets('a short span is void', (tester) async {
    await span('tap', () async => source.render(3));
  });

  testWidgets('a span still open when its test ends', (tester) async {
    // As when a test times out: its span's body never completes.
    unawaited(span('stuck', () => never.future));
    source.render(12);
  });

  testWidgets('a later span is not blocked by it', (tester) async {
    await span('after', () async => source.render(12));
  });

  testWidgets('a test that leaves the frame policy', (tester) async {
    reader.benchmarkLive = false;
  });
}
