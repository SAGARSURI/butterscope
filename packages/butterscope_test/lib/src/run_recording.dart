import 'package:butterscope/butterscope.dart';

/// One run's recording, split into parts as the tests go.
///
/// The whole run is one window of [FrameRecorder]; each test is the frames
/// between a mark at its start and a mark at its end. Nothing is measured
/// until [finish], so recording costs a measured frame nothing beyond the
/// recorder's own callback (`docs/DESIGN.md` section 6.9).
final class RunRecording {
  /// Creates a recording that reads frames through [_recorder].
  new(this._recorder);

  final FrameRecorder _recorder;
  final List<MarkedPart> _parts = [];
  final Set<String> _spanNames = {};
  (String, FrameMark)? _test;
  String? _span;

  /// Starts recording the run.
  void start() => _recorder.start();

  /// Marks the start of the test named [name].
  void testStarted(String name) => _test = (name, _recorder.mark());

  /// Marks the end of the test that started last.
  ///
  /// Frames between one test's end and the next one's start, such as
  /// teardown, belong to no test.
  void testEnded() {
    if (_test case (final name, final start)) {
      _parts.add(MarkedPart(PartKind.test, name, start, _recorder.mark()));
    }
    _test = null;
  }

  /// Records the frames [body] produces as the span named [name].
  ///
  /// The span ends when [body] completes, whether it returns or throws.
  /// Fails with a [StateError] outside a test or inside another span, since
  /// spans are flat (`docs/DESIGN.md` section 6.4), and with an
  /// [ArgumentError] when [name] is already a span in this run, so a
  /// baseline matches one span per name.
  Future<T> span<T>(String name, Future<T> Function() body) async {
    if (_test == null) {
      throw StateError('span("$name") was called outside a test.');
    }
    if (_span case final outer?) {
      throw StateError('span("$name") was called inside span("$outer").');
    }
    if (!_spanNames.add(name)) {
      throw ArgumentError.value(name, 'name', 'is already a span in this run');
    }
    final start = _recorder.mark();
    _span = name;
    try {
      return await body();
    } finally {
      // Cleared even when the closing mark throws, so one failed read
      // does not make every later span look nested.
      try {
        _parts.add(MarkedPart(PartKind.span, name, start, _recorder.mark()));
      } finally {
        _span = null;
      }
    }
  }

  /// Stops recording and reports the run.
  Future<RunReport> finish() async {
    final window = await _recorder.stop();
    return RunReport(window, List.unmodifiable(_parts));
  }
}
