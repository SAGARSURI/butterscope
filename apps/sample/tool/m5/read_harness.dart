// Prints what integration_test/m5_harness_test.dart measured on one phone,
// from its saved device logs:
//
//   fvm dart run tool/m5/read_harness.dart <log> ...
//
// One row per span: each step's own time per call over all the runs, and
// the janky frames and missed vsyncs of its span in each run, beside the
// empty spans of each screen. Exits 1 when a log does not hold exactly one
// readable report, or holds no call times.

import 'dart:io';

import 'harness_costs.dart';
import 'report_log.dart';

void main(List<String> logs) {
  if (logs.isEmpty) {
    stderr.writeln('Usage: read_harness.dart <log> ...');
    exit(64);
  }
  final reports = <Map<String, Object?>>[];
  final calls = <String, List<int>>{};
  for (final log in logs) {
    final text = File(log).readAsStringSync();
    final found = readReports(text);
    final json = found.length == 1 ? found.single.json : null;
    final times = readCallTimes(text);
    if (json == null || times.isEmpty) {
      stdout.writeln('PROBLEM: $log does not hold one report and call times');
      exit(1);
    }
    reports.add(json);
    for (final MapEntry(key: name, value: micros) in times.entries) {
      calls.putIfAbsent(name, () => []).addAll(micros);
    }
  }
  stdout
    ..writeln('#### Harness cost over ${logs.length} runs')
    ..writeln()
    ..writeln(costTable(spanCosts(reports, calls)));
}
