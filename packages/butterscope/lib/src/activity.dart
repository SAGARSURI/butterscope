import 'package:butterscope/src/marks.dart';

/// The kinds of activity that start an episode.
enum ActivityKind {
  /// Pointer events: taps, drags and flings, the test's own included.
  input,

  /// A ticker waiting for the next frame: scrolls, flings, ink splashes
  /// and page transitions all run on tickers.
  animation,
}

/// A stretch of one kind of activity, from its first mark to its last.
///
/// Input in consecutive frames is one stretch. An animation's stretch
/// starts at the frame after which a ticker first waits for a frame, and
/// ends at the frame after which none waits.
final class Activity {
  /// Creates a stretch of [kind] from [start] to [end].
  const new(this.kind, this.start, this.end);

  /// What sort of activity this is.
  final ActivityKind kind;

  /// The mark where it began.
  final FrameMark start;

  /// The mark where it was last seen.
  final FrameMark end;
}

/// A change of the page on top of the app's navigator.
final class PageChange {
  /// Creates a change to [page] at [at], which splits an episode when
  /// [cuts] is set.
  const new(this.at, this.page, {required this.cuts});

  /// The mark where the page changed.
  final FrameMark at;

  /// The page's route name, or null when its route has none.
  final String? page;

  /// Whether the change splits an episode: every change but the app's
  /// first page.
  final bool cuts;
}
