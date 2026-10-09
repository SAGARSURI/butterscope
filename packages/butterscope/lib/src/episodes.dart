import 'dart:math' as math;

import 'package:butterscope/src/activity.dart';
import 'package:butterscope/src/marks.dart';

/// How a test is split into episodes: which activity counts, and how long
/// a quiet stretch must be before activity starts a new one.
///
/// Under `benchmarkLive` frames never pause, so episodes split on activity
/// rather than on gaps between frames (`docs/DESIGN.md` section 6.3). In
/// M5's first five runs per phone, both rules below repeated every test's
/// episode count at 150, 300, 500 and 1000 ms. [inputOnly] is the default:
/// its episodes follow the user's actions, where a stream's animations
/// join everything around them into one under [inputOrAnimation], and at
/// 150 ms rule A split Inbox's tests differently on the two phones.
final class EpisodeRule {
  /// Creates a rule that counts animation when [countsAnimation] is set,
  /// and needs [quiet] without activity before a new episode.
  const new({required this.countsAnimation, required this.quiet});

  /// Rule A: input or animation, after 300 ms without either.
  static const inputOrAnimation = EpisodeRule(
    countsAnimation: true,
    quiet: Duration(milliseconds: 300),
  );

  /// Rule B: input only, after 300 ms without it.
  static const inputOnly = EpisodeRule(
    countsAnimation: false,
    quiet: Duration(milliseconds: 300),
  );

  /// Whether animation counts as activity, as well as input.
  final bool countsAnimation;

  /// The shortest stretch without activity after which activity starts a
  /// new episode.
  final Duration quiet;
}

/// Splits [test] into episodes by [rule], from the run's [activities] and
/// [pages].
///
/// Every frame of the test belongs to exactly one episode. The first
/// starts with the test. A later one starts at activity that follows a
/// quiet stretch of at least [EpisodeRule.quiet], counted from the test's
/// start for its first activity. A page change starts one too, at the
/// input that led to it: input that ended less than the quiet stretch
/// before the change. So a tap and the page it opens are one episode, even
/// when the tap followed a scroll too closely to start its own. With no
/// such input, it starts at the change. Either way, it starts none when an
/// episode started less than the quiet stretch before, so a scroll that
/// leads straight to a tap stays with the page it opens. The quiet stretch
/// after activity stays with the episode before it. Each episode is tagged
/// with the page on top at its end.
List<MarkedPart> splitEpisodes(
  MarkedPart test, {
  required List<Activity> activities,
  required List<PageChange> pages,
  EpisodeRule rule = EpisodeRule.inputOnly,
}) {
  final counted = _counted(test, activities, rule);
  final quiet = rule.quiet.inMicroseconds;
  final starts = [test.start];
  // Activity after a quiet stretch, counted from the test's start.
  var lastEnd = test.start.micros;
  for (final activity in counted) {
    if (activity.start.micros - lastEnd >= quiet) starts.add(activity.start);
    lastEnd = math.max(lastEnd, activity.end.micros);
  }
  // Each page change inside the test, at the input that led to it or else
  // at the change, when that comes a quiet stretch after the latest start.
  for (final change in pages) {
    final at = change.at.micros;
    final inside = at > test.start.micros && at < test.end.micros;
    if (!change.cuts || !inside) continue;
    final cut = _leadingInput(at, counted, quiet)?.start ?? change.at;
    if (cut.micros - _latestStart(cut.micros, starts) >= quiet) {
      starts.add(cut);
    }
  }
  final bounds = _bounds(test, starts);
  return [
    for (var i = 0; i + 1 < bounds.length; i++)
      MarkedPart(
        PartKind.episode,
        'episode ${i + 1}',
        bounds[i],
        bounds[i + 1],
        test: test.name,
        page: _pageAt(pages, bounds[i + 1]),
      ),
  ];
}

/// The input that led to a page change at [at]: the latest stretch of
/// [counted] input that started by then, if it ended less than [quiet] µs
/// before it.
Activity? _leadingInput(int at, List<Activity> counted, int quiet) {
  Activity? lead;
  for (final activity in counted) {
    if (activity.start.micros > at) break;
    if (activity.kind == ActivityKind.input) lead = activity;
  }
  return lead != null && at - lead.end.micros < quiet ? lead : null;
}

/// The latest of [starts] at or before [at], in µs. [starts] holds one,
/// the test's start.
int _latestStart(int at, List<FrameMark> starts) {
  return [
    for (final start in starts)
      if (start.micros <= at) start.micros,
  ].reduce(math.max);
}

/// The marks between [test]'s episodes, in order: its start, each of
/// [starts] that begins a new frame inside it, and its end.
List<FrameMark> _bounds(MarkedPart test, List<FrameMark> starts) {
  final sorted = [...starts]..sort((a, b) => a.micros.compareTo(b.micros));
  final bounds = [test.start];
  for (final start in sorted) {
    final after = start.frameNumber > bounds.last.frameNumber;
    if (after && start.frameNumber < test.end.frameNumber) bounds.add(start);
  }
  return bounds..add(test.end);
}

/// The activity [rule] counts that overlaps [test], by start.
List<Activity> _counted(
  MarkedPart test,
  List<Activity> activities,
  EpisodeRule rule,
) {
  return [
    for (final activity in activities)
      if ((rule.countsAnimation || activity.kind == ActivityKind.input) &&
          activity.end.micros >= test.start.micros &&
          activity.start.micros <= test.end.micros)
        activity,
  ]..sort((a, b) => a.start.micros.compareTo(b.start.micros));
}

/// The page on top just before [mark]: the last change before it. A change
/// at a mark starts the episode after it.
String? _pageAt(List<PageChange> pages, FrameMark mark) {
  String? page;
  for (final change in pages) {
    if (change.at.micros >= mark.micros) break;
    page = change.page;
  }
  return page;
}
