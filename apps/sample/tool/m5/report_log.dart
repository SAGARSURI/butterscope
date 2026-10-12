/// Reads the reports `attachButterscope` prints, from a saved device log.
///
/// Each report is JSON split over numbered `BSCOPE-REPORT` lines (see
/// `packages/butterscope_test/lib/src/report_writer.dart`). A log can hold
/// a line twice, from the `flutter drive` transcript and from logcat, and
/// lines logcat dropped. This joins each run's chunks and says what is
/// missing. It is M5's stand-in for M7's `butterscope collect`.
library;

import 'dart:convert';

/// The tag every report line starts with.
const String reportTag = 'BSCOPE-REPORT';

/// One run's report, read back from a log.
class LoggedReport {
  new(this.runId, this.json, this.problems);

  /// The run id the report was printed with.
  final String runId;

  /// The decoded report, or null when chunks are missing or it does not
  /// decode.
  final Map<String, Object?>? json;

  /// What is wrong with it, as messages for people.
  final List<String> problems;

  /// The build mode: in the identity block since M6, and at the top level
  /// in M5's reports.
  Object? get buildMode {
    final json = this.json;
    return switch (json?['identity']) {
      {'buildMode': final mode} => mode,
      _ => json?['buildMode'],
    };
  }

  /// The report's parts, such as tests and spans, as maps.
  List<Map<String, Object?>> get parts {
    final list = json?['parts'] as List<Object?>? ?? const [];
    return [for (final part in list) part! as Map<String, Object?>];
  }

  /// Why the decoded report is not whole: it holds no frames or no tests,
  /// a span has no metrics, or a flush timed out. Empty when it is whole,
  /// or when it did not decode (then [problems] says why).
  List<String> incomplete() {
    final json = this.json;
    if (json == null) return const [];
    return [
      if (json['frames'] == 0) 'The report holds no frames',
      if (!parts.any((part) => part['kind'] == 'test'))
        'The report holds no tests',
      for (final part in parts)
        if (part['kind'] == 'span' && part['metrics'] == null)
          'Span ${part['name']} has no metrics',
      if (json['flushTimedOut'] == true) flushTimedOut,
    ];
  }

  /// Why the decoded report cannot be used for M5's runs: it is
  /// [incomplete], it was not built in profile mode, or since M6 the run
  /// or a span is void for a reason of its own. With [minHz], also each
  /// test of at least [rateFrames] frames that drew below it or has no
  /// observed rate, or no test that long. Empty when it can be used, or
  /// when it did not decode (then [problems] says why).
  ///
  /// M5's reports carry no validity, so a missing `valid` passes. [allow]
  /// names guards that may void the run, such as `thermal` for M6's iPhone
  /// runs at "fair" (void until decision record 0007); a run void by those
  /// alone passes.
  List<String> unusable({double? minHz, Set<String> allow = const {}}) {
    final json = this.json;
    if (json == null) return const [];
    final rated = [
      for (final part in parts)
        if (part['kind'] == 'test' && _frames(part) >= rateFrames) part,
    ];
    return [
      ...incomplete(),
      if (buildMode != 'profile') 'Built in $buildMode mode, not profile',
      if (json['valid'] == false && !_voidOnlyBy(json['reasons'], allow))
        'The run is void: ${json['reasons']}',
      // A void run voids its spans too, without naming a reason of theirs.
      for (final part in parts)
        if (part['reasons'] case [_, ...] && final reasons)
          '${part['kind']} ${part['name']} is void: $reasons',
      if (minHz != null && rated.isEmpty)
        'No test drew $rateFrames frames, enough to check its rate',
      if (minHz != null)
        for (final part in rated) ?_lowRate(part, minHz),
    ];
  }
}

/// Whether [reasons], a void run's `[guard, where, value]` list, names at
/// least one guard and only guards in [allow]. A list of any other shape
/// is not, so the run is reported as void with what it holds.
bool _voidOnlyBy(Object? reasons, Set<String> allow) {
  return reasons is List<Object?> &&
      reasons.isNotEmpty &&
      reasons.every(
        (reason) =>
            reason is List<Object?> && allow.contains(reason.firstOrNull),
      );
}

/// The problem [LoggedReport.incomplete] gives a timed-out flush.
const String flushTimedOut = 'A flush timed out';

/// The fewest frames a test needs before the warm-up checks its rate.
///
/// Decision record 0001 (decision 6, kept by 0002) reads a rate only from
/// at least 10 vsync gaps, and 10 gaps take 11 frames. A shorter test,
/// such as one that only launches the app, can catch the frames a phone
/// draws at a lower rate while it starts up.
const int rateFrames = 11;

int _frames(Map<String, Object?> part) => part['frames'] as int? ?? 0;

String? _lowRate(Map<String, Object?> part, double minHz) {
  final metrics = part['metrics'] as Map<String, Object?>?;
  final observed = metrics?['observedHz'];
  if (observed is! num) return '${part['name']} has no observed rate';
  if (observed >= minHz) return null;
  return '${part['name']} drew at ${observed.toStringAsFixed(1)} Hz, '
      'under $minHz';
}

/// Reads every report in [text], whatever comes before the tag on a line.
List<LoggedReport> readReports(String text) {
  final chunks = <String, Map<int, String>>{};
  final counts = <String, int>{};
  final pattern = RegExp('$reportTag (\\d+) (\\d+) (\\d+) (.*)\$');
  for (final line in const LineSplitter().convert(text)) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final id = match.group(1)!;
    chunks.putIfAbsent(id, () => {})[int.parse(match.group(2)!)] = match.group(
      4,
    )!;
    counts[id] = int.parse(match.group(3)!);
  }
  return [
    for (final MapEntry(key: id, value: byIndex) in chunks.entries)
      _join(id, byIndex, counts[id]!),
  ];
}

LoggedReport _join(String id, Map<int, String> byIndex, int count) {
  final missing = [
    for (var i = 1; i <= count; i++)
      if (!byIndex.containsKey(i)) i,
  ];
  if (missing.isNotEmpty) {
    return LoggedReport(id, null, [
      'Run $id: missing chunk(s) ${missing.join(', ')} of $count',
    ]);
  }
  final text = [for (var i = 1; i <= count; i++) byIndex[i]].join();
  try {
    return LoggedReport(id, jsonDecode(text) as Map<String, Object?>, []);
  } on FormatException catch (error) {
    return LoggedReport(id, null, ['Run $id: unreadable JSON ($error)']);
  }
}
