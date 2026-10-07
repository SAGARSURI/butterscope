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

  /// The report's parts, such as tests and spans, as maps.
  List<Map<String, Object?>> get parts {
    final list = json?['parts'] as List<Object?>? ?? const [];
    return [for (final part in list) part! as Map<String, Object?>];
  }
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
