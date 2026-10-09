// Prints the reports in a saved device log as tables, one row per test:
//
//   fvm dart run tool/m5/read_report.dart <log> [--min-hz <hertz>]
//
// Exits 1 when a report is missing or unreadable, a log holds no report
// or more than one, a report holds no frames or no tests, a flush timed
// out, or the run was not in profile mode. With --min-hz, also exits 1
// when a test drew below it or has no observed rate, which is how
// tool/m5/run_tests.sh catches a capped screen before M6's rate mismatch
// exists.

import 'dart:io';

import 'report_log.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: read_report.dart <log> [--min-hz <hertz>]');
    exit(64);
  }
  final minHz = args.length == 3 && args[1] == '--min-hz'
      ? double.parse(args[2])
      : null;
  final reports = readReports(File(args.first).readAsStringSync());
  final problems = [for (final report in reports) ...report.problems];
  if (reports.length != 1) {
    problems.add('Expected one report, found ${reports.length}');
  }
  for (final report in reports) {
    final json = report.json;
    if (json == null) continue;
    stdout
      ..writeln(
        '#### Run ${report.runId}: ${json['buildMode']}, '
        '${json['frames']} frames, flush ${json['flushMicros']} µs',
      )
      ..writeln()
      ..writeln(
        '| Part | Name | Frames | Janky % | Missed vsyncs | Hitch ratio '
        '| Observed Hz |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
    for (final part in report.parts) {
      stdout.writeln(_row(part));
    }
    problems.addAll(report.unusable(minHz: minHz));
  }
  for (final problem in problems) {
    stdout.writeln('PROBLEM: $problem');
  }
  exit(problems.isEmpty ? 0 : 1);
}

String _row(Map<String, Object?> part) {
  final metrics = part['metrics'] as Map<String, Object?>?;
  String fixed(Object? value, int digits, {double scale = 1}) {
    return value is num ? (value * scale).toStringAsFixed(digits) : 'n/a';
  }

  return '| ${part['kind']} | ${part['name']} | ${part['frames']} '
      '| ${fixed(metrics?['jankyRate'], 2, scale: 100)} '
      '| ${metrics?['missedVsyncs'] ?? 'n/a'} '
      '| ${fixed(metrics?['hitchRatio'], 1)} '
      '| ${fixed(metrics?['observedHz'], 1)} |';
}
