// Prints what integration_test/m5_harness_test.dart measured on one phone,
// from its saved device logs:
//
//   fvm dart run tool/m5/read_harness.dart <log> ...
//
// One row per span: each step's own time per call over all the runs, and
// the janky frames and missed vsyncs of its span in each run, beside the
// empty spans of each screen. Exits 1 when a run cannot be counted: its log
// does not hold exactly one usable report, or a step lacks call times.

import 'dart:io';

import 'harness_costs.dart';

void main(List<String> logs) {
  if (logs.isEmpty) {
    stderr.writeln('Usage: read_harness.dart <log> ...');
    exit(64);
  }
  final reports = <Map<String, Object?>>[];
  final calls = <String, List<int>>{};
  for (final log in logs) {
    final run = readRun(File(log).readAsStringSync());
    final report = run.report;
    if (report == null) {
      for (final problem in run.problems) {
        stdout.writeln('PROBLEM: $log: $problem');
      }
      exit(1);
    }
    reports.add(report);
    for (final MapEntry(key: name, value: micros) in run.calls.entries) {
      calls.putIfAbsent(name, () => []).addAll(micros);
    }
  }
  stdout
    ..writeln('#### Harness cost over ${logs.length} runs')
    ..writeln()
    ..writeln(costTable(spanCosts(reports, calls)));
}
