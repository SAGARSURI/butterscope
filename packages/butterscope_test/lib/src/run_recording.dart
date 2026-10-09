import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/activity_source.dart';

/// One run's recording, split into parts as the tests go.
///
/// The whole run is one window of [FrameRecorder]; each test is the frames
/// between a mark at its start and a mark at its end. Activity is stored as
/// marks too, and each test is split into episodes at [finish]. Nothing is
/// measured until then, so recording costs a measured frame nothing beyond
/// the recorder's own callback and a mark per change of activity
/// (`docs/DESIGN.md` section 6.9).
final class RunRecording implements ActivityListener {
  /// Creates a recording that reads frames through [_recorder].
  new(this._recorder);

  final FrameRecorder _recorder;
  final List<MarkedPart> _parts = [];
  final Set<String> _spanNames = {};
  final List<Activity> _activities = [];
  final List<PageChange> _pages = [];
  (String, FrameMark)? _test;
  String? _span;
  Activity? _input;
  FrameMark? _animationStart;

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

  @override
  void input() {
    final mark = _recorder.mark();
    final last = _input;
    // Input in consecutive frames is one stretch.
    if (last != null && mark.frameNumber - last.end.frameNumber <= 1) {
      _input = Activity(ActivityKind.input, last.start, mark);
      return;
    }
    if (last != null) _activities.add(last);
    _input = Activity(ActivityKind.input, mark, mark);
  }

  @override
  void animating({required bool animating}) {
    final start = _animationStart;
    if (animating) {
      _animationStart ??= _recorder.mark();
    } else if (start != null) {
      _activities.add(
        Activity(ActivityKind.animation, start, _recorder.mark()),
      );
      _animationStart = null;
    }
  }

  @override
  void pageShown(String? page, {required bool first}) {
    _pages.add(PageChange(_recorder.mark(), page, cuts: !first));
  }

  /// Stops recording and reports the run, each test split into episodes
  /// by [rule] and listed before it.
  Future<RunReport> finish({
    EpisodeRule rule = EpisodeRule.inputOrAnimation,
  }) async {
    // Activity still open at the end closes there.
    if (_input case final input?) _activities.add(input);
    animating(animating: false);
    final window = await _recorder.stop();
    final parts = [
      for (final part in _parts) ...[
        if (part.kind == PartKind.test)
          ...splitEpisodes(
            part,
            activities: _activities,
            pages: _pages,
            rule: rule,
          ),
        part,
      ],
    ];
    return RunReport(
      window,
      List.unmodifiable(parts),
      activities: List.unmodifiable(_activities),
      pages: List.unmodifiable(_pages),
    );
  }
}
