import 'dart:math' as math;

import 'package:butterscope/src/activity.dart';
import 'package:butterscope/src/marks.dart';

/// How a test is split into episodes: which activity counts, and how long
/// a quiet stretch must be before activity starts a new one.
///
/// Under `benchmarkLive` frames never pause, so episodes split on activity
/// rather than on gaps between frames (`docs/DESIGN.md` section 6.3). M5
/// chooses between the two rules below on phone runs.
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
/// quiet stretch of at least [EpisodeRule.quiet], and at a page change,
/// unless an episode started less than that long before it: a tap that
/// opens a page is one episode with the page's transition. The quiet
/// stretch after activity stays with the episode before it. Each episode
/// is tagged with the page on top at its end.
List<MarkedPart> splitEpisodes(
  MarkedPart test, {
  required List<Activity> activities,
  required List<PageChange> pages,
  EpisodeRule rule = EpisodeRule.inputOrAnimation,
}) {
  final starts = [test.start, ..._activityStarts(test, activities, rule)];
  _addPageStarts(starts, test, pages, rule.quiet.inMicroseconds);
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

/// Adds to [starts] each page change inside [test] that comes at least
/// [quiet] µs after the latest start before it.
void _addPageStarts(
  List<FrameMark> starts,
  MarkedPart test,
  List<PageChange> pages,
  int quiet,
) {
  for (final change in pages) {
    final at = change.at.micros;
    if (!change.cuts || at <= test.start.micros || at >= test.end.micros) {
      continue;
    }
    final latest = starts
        .map((start) => start.micros)
        .where((micros) => micros <= at)
        .reduce(math.max);
    if (at - latest >= quiet) starts.add(change.at);
  }
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

/// The marks where activity in [test] starts after a quiet stretch.
Iterable<FrameMark> _activityStarts(
  MarkedPart test,
  List<Activity> activities,
  EpisodeRule rule,
) sync* {
  final counted = [
    for (final activity in activities)
      if ((rule.countsAnimation || activity.kind == ActivityKind.input) &&
          activity.end.micros >= test.start.micros &&
          activity.start.micros <= test.end.micros)
        activity,
  ]..sort((a, b) => a.start.micros.compareTo(b.start.micros));
  int? lastEnd;
  for (final activity in counted) {
    if (lastEnd != null &&
        activity.start.micros - lastEnd >= rule.quiet.inMicroseconds) {
      yield activity.start;
    }
    lastEnd = math.max(lastEnd ?? 0, activity.end.micros);
  }
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
