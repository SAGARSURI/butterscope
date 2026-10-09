import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/activity_source.dart';
import 'package:butterscope_test/src/report_writer.dart';
import 'package:butterscope_test/src/run_recording.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_api/hooks.dart' show TestHandle;

/// This run's recording, once attached.
RunRecording? _run;

/// Attaches Butterscope to this test file: call it once at the top of
/// `main`, before any `testWidgets` and outside any `group`.
///
/// It switches the binding to the `benchmarkLive` frame policy, so frames
/// run back to back at vsync for the whole run and every missed vsync shows
/// (`docs/DESIGN.md` section 6.2). It also holds text cursors still: see
/// [attachTo]. It records every frame from the first
/// test to the last, attributes them to the test that produced them,
/// splits each test into episodes on input, and prints the
/// report after the last test. With a [ButterscopeRouteObserver] in the
/// app, a change of page splits an episode too and tags it.
///
/// Calling it again in the same run does nothing, so a file that runs other
/// files' `main`s, each of which attaches, still records one run.
void attachButterscope() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Printed at once: debugPrint queues long output on a timer, which could
  // still be printing when the driver stops reading.
  attachTo(
    binding,
    EngineFrameSource(),
    EngineActivitySource(),
    ReportWriter(debugPrintSynchronously),
  );
}

/// Attaches to [binding], reading frames from [source] and activity from
/// [activity], and printing the report with [writer]. [attachButterscope]
/// passes the real ones.
///
/// The binding must be created before this runs. It registers a
/// `tearDownAll` that tells the driver the run is over
/// (`packages/integration_test/lib/integration_test.dart` in Flutter
/// 3.47.5), and `tearDownAll` callbacks run in reverse order
/// (`Invoker.runTearDowns` in test_api 0.7.12), so the report registered
/// here is printed before the driver stops reading the device's output.
///
/// It sets [EditableText.debugDeterministicCursor], so a focused text
/// field's cursor stops blinking. On iOS the cursor fades with an animation
/// that restarts from a zero-length timer (`_onCursorTick` in
/// `editable_text.dart`, Flutter 3.47.5). Under `benchmarkLive` a pump only
/// waits while frames keep running, so `pumpAndSettle` almost never lands
/// in that gap and a test that types waits until its timeout. Without
/// Butterscope, each pump draws one frame and checks right after it, so
/// the gap is found and the test settles.
void attachTo(
  LiveTestWidgetsFlutterBinding binding,
  FrameSource source,
  ActivitySource activity,
  ReportWriter writer,
) {
  if (_run != null) return;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  EditableText.debugDeterministicCursor = true;
  final run = _run = RunRecording(FrameRecorder(source));
  setUpAll(() {
    run.start();
    activity.start(run);
  });
  // The test's full name, group names included, from test_api's public
  // hook: flutter_test keeps the description it is given private.
  setUp(() => run.testStarted(TestHandle.current.name));
  tearDown(run.testEnded);
  tearDownAll(() async {
    activity.stop();
    final report = await run.finish();
    final runId = DateTime.now().microsecondsSinceEpoch;
    writer.write(report.toJson(), runId: runId);
  });
}

/// Gates the flow [body] runs as the span named [name], and returns what
/// [body] returns:
///
/// ```dart
/// await span('feed scroll', () async {
///   await tester.scrollUntilVisible(card, 400);
/// });
/// ```
///
/// Its frames are those [body] produces, from when it starts to when it
/// completes. Span names are stable across runs, so spans are what a
/// baseline compares (`docs/DESIGN.md` section 6.4).
///
/// The returned future fails with a [StateError] before
/// [attachButterscope], outside a test, or inside another span, since
/// spans are flat, and with an [ArgumentError] when [name] is already a
/// span in this run.
Future<T> span<T>(String name, Future<T> Function() body) async {
  final run = _run;
  if (run == null) {
    throw StateError('Call attachButterscope() before span("$name").');
  }
  return await run.span(name, body);
}
