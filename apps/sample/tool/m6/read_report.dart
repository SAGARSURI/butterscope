// Prints the report in a saved device log with M6's fields: the identity,
// whether the run is valid and why not, and each test's and span's
// validity, semantics and rate mismatches. Then checks it shows what the
// run was set up to show:
//
//   fvm dart run tool/m6/read_report.dart <log> [--expect <what>]
//       [--void-span <name>=<guard> ...] [--allow <guard> ...]
//
// <what> is `clean` (the default: the run and every span valid, no
// mismatch), `flagged` (every part with a judged slice flags a mismatch,
// for a screen forced below its rate), or a guard's name such as
// `lowPower` (the run void by that guard). --void-span names a span a
// clean run should void, and by which guard. --allow names a guard that
// may also void the run, such as `thermal` for M6's iPhone runs at "fair",
// which voided a run until decision record 0007.
//
// Exits 1 when the report is missing, unreadable or incomplete, or does
// not show what it should.

import 'dart:io';

import '../m5/report_log.dart';
import 'validity.dart';

void main(List<String> args) {
  // Options come in pairs after the log.
  if (args.isEmpty || args.length.isEven) _usage();
  var expect = 'clean';
  final voidSpans = <String, String>{};
  final allow = <String>{};
  for (var i = 1; i < args.length; i += 2) {
    switch ((args[i], args[i + 1].split('='))) {
      case ('--expect', _):
        expect = args[i + 1];
      case ('--void-span', [final name, final guard]):
        voidSpans[name] = guard;
      case ('--allow', _):
        allow.add(args[i + 1]);
      default:
        _usage();
    }
  }

  final reports = readReports(File(args.first).readAsStringSync());
  final problems = [for (final report in reports) ...report.problems];
  if (reports.length != 1) {
    problems.add('Expected one report, found ${reports.length}');
  }
  for (final report in reports) {
    final json = report.json;
    if (json == null) continue;
    _print(report.runId, json);
    problems
      ..addAll(unexpectedIncomplete(report.incomplete(), expect))
      ..addAll(switch (expect) {
        'clean' => notClean(json, voidSpans: voidSpans, allow: allow),
        'flagged' => notFlagged(json, allow: allow),
        final guard => notVoidedBy(json, guard, allow: allow),
      });
  }
  for (final problem in problems) {
    stdout.writeln('PROBLEM: $problem');
  }
  exit(problems.isEmpty ? 0 : 1);
}

Never _usage() {
  stderr.writeln(
    'Usage: read_report.dart <log> [--expect <what>] '
    '[--void-span <name>=<guard> ...] [--allow <guard> ...]',
  );
  exit(64);
}

void _print(String runId, Map<String, Object?> json) {
  final identity = json['identity'] as Map<String, Object?>? ?? const {};
  final reasons = json['reasons'] as List<Object?>? ?? const [];
  stdout
    ..writeln('#### Run $runId: ${json['valid'] == true ? 'VALID' : 'VOID'}')
    ..writeln()
    ..writeln(
      [for (final MapEntry(:key, :value) in identity.entries) '$key: $value']
          .join(', '),
    )
    ..writeln();
  for (final reason in reasons) {
    stdout.writeln('- void: $reason');
  }
  stdout
    ..writeln()
    ..writeln(
      '| Part | Name | Frames | Valid | Reasons | Semantics | Slices '
      '| Mismatches | Observed Hz |',
    )
    ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final part in partsOf(json)) {
    if (part['kind'] == 'episode') continue;
    final metrics = part['metrics'] as Map<String, Object?>?;
    final observed = metrics?['observedHz'];
    stdout.writeln(
      '| ${part['kind']} | ${part['name']} | ${part['frames']} '
      '| ${part['valid'] ?? ''} | ${part['reasons'] ?? ''} '
      '| ${part['semantics'] ?? ''} | ${metrics?['rateSlicesJudged'] ?? 'n/a'} '
      '| ${mismatchesOf(part)} '
      '| ${observed is num ? observed.toStringAsFixed(1) : 'n/a'} |',
    );
  }
}
