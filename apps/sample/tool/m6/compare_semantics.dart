// Compares app_test.dart's spans run with semantics on, as testWidgets
// leaves it, against the same spans run with it off, from saved device
// logs on one phone:
//
//   fvm dart run tool/m6/compare_semantics.dart --on <log> ... --off <log> ...
//
// Add `--allow <guard>`, once per guard, to count runs void by those guards
// alone, such as `--allow thermal` for an iPhone that read "fair" on its
// cable.
//
// Prints, per metric, each span's median and spread (largest value less
// smallest) over the runs with semantics on and over those with it off.
// Exits 1 when a run cannot be counted: its log does not hold exactly one
// whole report, the run is void by a guard not allowed, a span is void by
// its own guard, or a span read semantics otherwise than its group says.

import 'dart:io';

import '../m5/report_log.dart';
import 'semantics_spread.dart';

void main(List<String> args) {
  final on = <String>[];
  final off = <String>[];
  final allow = <String>{};
  List<String>? group;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--on':
        group = on;
      case '--off':
        group = off;
      case '--allow' when i + 1 < args.length:
        allow.add(args[++i]);
      case final log when group != null && !log.startsWith('--'):
        group.add(log);
      default:
        _usage();
    }
  }
  if (on.isEmpty || off.isEmpty) _usage();

  final problems = <String>[];
  List<Map<String, Object?>> read(List<String> logs, {required bool on}) {
    final reports = <Map<String, Object?>>[];
    for (final log in logs) {
      final found = readReports(File(log).readAsStringSync());
      final json = found.length == 1 ? found.single.json : null;
      final runProblems = [
        if (found.length != 1) 'Expected one report, found ${found.length}',
        for (final report in found) ...[
          ...report.problems,
          ...report.incomplete(),
        ],
        if (json != null) ...semanticsProblems(json, on: on, allow: allow),
      ];
      problems.addAll([for (final problem in runProblems) '$log: $problem']);
      if (runProblems.isEmpty && json != null) reports.add(json);
    }
    return reports;
  }

  final onReports = read(on, on: true);
  final offReports = read(off, on: false);
  for (final problem in problems) {
    stdout.writeln('PROBLEM: $problem');
  }
  if (problems.isNotEmpty) exit(1);
  for (final metric in comparedMetrics) {
    stdout
      ..writeln(
        spreadTable(
          metric,
          spanValues(onReports, metric),
          spanValues(offReports, metric),
        ),
      )
      ..writeln();
  }
}

Never _usage() {
  stderr.writeln(
    'Usage: compare_semantics.dart --on <log> ... --off <log> ... '
    '[--allow <guard>] ...',
  );
  exit(64);
}
