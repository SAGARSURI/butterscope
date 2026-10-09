/// Splits the tests of a printed report into episodes again, by any rule,
/// so M5 can choose the rule from phone runs (the plan's Episodes section).
library;

import 'package:butterscope/episodes.dart';

/// The rules M5 compares: A (input or animation) and B (input only), each
/// after a quiet stretch of 150, 300, 500 or 1000 ms.
final List<(String, EpisodeRule)> candidateRules = [
  for (final animation in [true, false])
    for (final ms in [150, 300, 500, 1000])
      (
        '${animation ? 'A' : 'B'} ${ms}ms',
        EpisodeRule(
          countsAnimation: animation,
          quiet: Duration(milliseconds: ms),
        ),
      ),
];

/// Each test's episode count in the report [json], split by [rule].
Map<String, int> episodeCounts(Map<String, Object?> json, EpisodeRule rule) {
  final activities = [
    for (final entry in json['activity']! as List<Object?>)
      _activity(entry! as List<Object?>),
  ];
  final pages = [
    for (final entry in json['pages']! as List<Object?>)
      _page(entry! as List<Object?>),
  ];
  return {
    for (final part
        in (json['parts']! as List<Object?>).cast<Map<String, Object?>>())
      if (part['kind'] == 'test')
        part['name']! as String: splitEpisodes(
          _test(part),
          activities: activities,
          pages: pages,
          rule: rule,
        ).length,
  };
}

/// How many of [counts] equal the most common one.
int repeats(List<int> counts) {
  final tally = <int, int>{};
  for (final count in counts) {
    tally[count] = (tally[count] ?? 0) + 1;
  }
  return tally.values.fold(0, (most, n) => n > most ? n : most);
}

// The rate does not affect where episodes split.
FrameMark _mark(Object? frame, Object? micros) {
  return FrameMark(
    frameNumber: frame! as int,
    declaredRefreshRate: double.nan,
    micros: micros! as int,
  );
}

MarkedPart _test(Map<String, Object?> part) {
  return MarkedPart(
    PartKind.test,
    part['name']! as String,
    _mark(part['startFrame'], part['startMicros']),
    _mark(part['endFrame'], part['endMicros']),
  );
}

Activity _activity(List<Object?> entry) {
  return Activity(
    ActivityKind.values.byName(entry[0]! as String),
    _mark(entry[1], entry[2]),
    _mark(entry[3], entry[4]),
  );
}

PageChange _page(List<Object?> entry) {
  return PageChange(
    _mark(entry[0], entry[1]),
    entry[2] as String?,
    cuts: entry[3]! as bool,
  );
}
