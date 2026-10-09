// Pure Dart, with no Flutter import, so host tools can use it too.

/// A point inside a recording: the frame begun most recently when it was
/// taken, the refresh rate the screen declared then, and the time.
final class FrameMark {
  /// Creates a mark, for example in a test.
  const new({
    required this.frameNumber,
    required this.declaredRefreshRate,
    required this.micros,
  });

  /// The frame begun most recently when the mark was taken. It belongs to
  /// the part of the recording before the mark.
  final int frameNumber;

  /// The declared refresh rate read when the mark was taken, as read: it can
  /// be 0 or not finite, for the guards to judge.
  final double declaredRefreshRate;

  /// When the mark was taken, in microseconds on the frame source's clock.
  final int micros;
}

/// The kinds of part a run is split into.
enum PartKind {
  /// One `testWidgets` test, from its `setUp` to its `tearDown`.
  test,

  /// A named span a test marked around a flow. Spans are gated.
  span,

  /// A part of a test split out by activity, without the test marking it.
  episode,
}

/// One part of a run, between two marks of its recording.
final class MarkedPart {
  /// Creates a part named [name] of [kind], from [start] to [end]. An
  /// episode names its [test] and the [page] on top when it ended.
  const new(this.kind, this.name, this.start, this.end, {this.test, this.page});

  /// What sort of part this is.
  final PartKind kind;

  /// The test's full name, the span's name, or the episode's number in its
  /// test, such as `episode 2`.
  final String name;

  /// The full name of the test an episode belongs to.
  final String? test;

  /// The route name of the page on top when an episode ended, when the app
  /// has a `ButterscopeRouteObserver` and the route has a name.
  final String? page;

  /// The mark at its start. Its frames begin after this mark's frame.
  final FrameMark start;

  /// The mark at its end. Its last frame is this mark's frame.
  final FrameMark end;
}
