// Splits the tests in saved device logs into episodes by each candidate
// rule, and prints how often each test's episode count repeats:
//
//   fvm dart run tool/m5/read_episodes.dart <log> ...
//
// One table per rule, one row per test: its count in each run, and how
// many runs give its most common count. A rule passes when that holds in
// at least 9 of every 10 runs for every test (M5's Done-when 2), so in all
// 5 of 5. Exits 1 when a log does not hold exactly one readable report.

import 'dart:io';

import 'episode_counts.dart';
import 'report_log.dart';

void main(List<String> logs) {
  if (logs.isEmpty) {
    stderr.writeln('Usage: read_episodes.dart <log> ...');
    exit(64);
  }
  final runs = <Map<String, Object?>>[];
  for (final log in logs) {
    final reports = readReports(File(log).readAsStringSync());
    final json = reports.length == 1 ? reports.single.json : null;
    if (json == null) {
      stdout.writeln('PROBLEM: $log does not hold one readable report');
      exit(1);
    }
    runs.add(json);
  }
  final needed = (runs.length * 9 / 10).ceil();
  for (final (label, rule) in candidateRules) {
    final counts = [for (final run in runs) episodeCounts(run, rule)];
    final tests = counts.first.keys;
    final passes = tests.every(
      (test) => repeats([for (final run in counts) run[test] ?? 0]) >= needed,
    );
    stdout
      ..writeln('#### Rule $label: ${passes ? 'passes' : 'fails'}')
      ..writeln()
      ..writeln('| Test | Episodes per run | Repeats |')
      ..writeln('| --- | --- | --- |');
    for (final test in tests) {
      final perRun = [for (final run in counts) run[test] ?? 0];
      final repeated = '${repeats(perRun)} of ${runs.length}';
      stdout.writeln('| $test | ${perRun.join(' ')} | $repeated |');
    }
    stdout.writeln();
  }
}
