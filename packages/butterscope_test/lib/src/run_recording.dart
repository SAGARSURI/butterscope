import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/activity_source.dart';

/// One run's recording, split into parts as the tests go.
///
/// The whole run is one window of [FrameRecorder]; each test is the frames
/// between a mark at its start and a mark at its end. Activity is stored as
/// marks too, and each test is split into episodes at [finish]. Nothing is
/// measured until then, so recording costs a measured frame nothing beyond
/// the recorder's own callback, a mark per frame with input, and a mark per
/// change of other activity (`docs/DESIGN.md` section 6.9).
final class RunRecording implements ActivityListener {
  /// Creates a recording that reads frames through [_recorder] and asks
  /// [_semanticsOn] at each span's marks whether semantics is on.
  new(this._recorder, this._semanticsOn);

  final FrameRecorder _recorder;
  final bool Function() _semanticsOn;
  final List<MarkedPart> _parts = [];
  final Set<String> _spanNames = {};
  final List<Activity> _activities = [];
  final List<PageChange> _pages = [];
  (String, FrameMark)? _test;
  _OpenSpan? _span;
  Activity? _input;
  FrameMark? _animationStart;

  /// Starts recording the run.
  void start() => _recorder.start();

  /// Marks the start of the test named [name].
  void testStarted(String name) => _test = (name, _recorder.mark());

  /// Marks the end of the test that started last.
  ///
  /// Frames between one test's end and the next one's start, such as
  /// teardown, belong to no test. A span still open, such as one whose
  /// test timed out, ends here and is void, so it cannot block the spans
  /// of later tests.
  void testEnded() {
    final end = _recorder.mark();
    if (_test case (final name, final start)) {
      if (_span case final open?) {
        _closeSpan(
          open,
          end,
          failures: [GuardFailure(Guard.openAtTestEnd, 'end of $name')],
        );
      }
      _parts.add(MarkedPart(PartKind.test, name, start, end));
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
      throw StateError(
        'span("$name") was called inside span("${outer.name}").',
      );
    }
    if (!_spanNames.add(name)) {
      throw ArgumentError.value(name, 'name', 'is already a span in this run');
    }
    final open = _OpenSpan(name, _recorder.mark(), semanticsOn: _semanticsOn());
    _span = open;
    try {
      return await body();
    } finally {
      // Its test's end closed it already when the test ended first.
      if (identical(_span, open)) {
        // Cleared even when the closing mark throws, so one failed read
        // does not make every later span look nested.
        try {
          _closeSpan(open, _recorder.mark());
        } finally {
          _span = null;
        }
      }
    }
  }

  void _closeSpan(
    _OpenSpan open,
    FrameMark end, {
    List<GuardFailure> failures = const [],
  }) {
    _span = null;
    _parts.add(
      MarkedPart(
        PartKind.span,
        open.name,
        open.start,
        end,
        semantics: (atStart: open.semanticsOn, atEnd: _semanticsOn()),
        failures: failures,
      ),
    );
  }

  @override
  void input() {
    final last = _input;
    // A drag sends a few events a frame; the stretch already ends there.
    if (last != null && _recorder.currentFrameNumber == last.end.frameNumber) {
      return;
    }
    final mark = _recorder.mark();
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

  /// Stops recording and reports the run as measured on [identity], with
  /// the run guards that [failures] lists, each test split into episodes
  /// by [rule] and listed before it.
  Future<RunReport> finish({
    required RunIdentity identity,
    List<GuardFailure> failures = const [],
    EpisodeRule rule = EpisodeRule.inputOnly,
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
      identity: identity,
      failures: failures,
      activities: List.unmodifiable(_activities),
      pages: List.unmodifiable(_pages),
    );
  }
}

/// A span that has started and not ended yet.
final class _OpenSpan {
  new(this.name, this.start, {required this.semanticsOn});

  final String name;
  final FrameMark start;

  /// Whether semantics was on at its start.
  final bool semanticsOn;
}
