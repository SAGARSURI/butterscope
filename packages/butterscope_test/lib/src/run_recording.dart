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
  (String, FrameMark)? _test;

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

  /// Stops recording and reports the run.
  Future<RunReport> finish() async {
    final window = await _recorder.stop();
    return RunReport(window, List.unmodifiable(_parts));
  }
}
