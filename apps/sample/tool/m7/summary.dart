// Prints one line for each run file `butterscope collect` wrote
// (docs/report-schema.md, "Collected file"): what the run was measured
// on, how many frames it holds and lost, and whether it is valid.
//
//   fvm dart run tool/m7/summary.dart [--warmup] <runId>.json ...
//
// With --warmup, also checks each run is clean as M6's warm-up was: the
// run and every span valid, and no rate mismatch (tool/m6/validity.dart).
// Exits 1 when a file cannot be read, or a warm-up is not clean.

import 'dart:convert';
import 'dart:io';

import '../m6/validity.dart' show notClean, partsOf, runReasons;

void main(List<String> args) {
  final warmup = args.contains('--warmup');
  final files = [
    for (final arg in args)
      if (arg != '--warmup') arg,
  ];
  if (files.isEmpty) {
    stderr.writeln(
      'Usage: fvm dart run tool/m7/summary.dart [--warmup] <runId>.json ...',
    );
    exit(64);
  }
  var failed = false;
  for (final path in files) {
    final Map<String, Object?> run;
    try {
      run = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    } on Exception catch (error) {
      stdout.writeln('$path: cannot read it: $error');
      failed = true;
      continue;
    }
    stdout.writeln(summarise(run));
    if (!warmup) continue;
    for (final problem in notClean(run)) {
      stdout.writeln('  not clean: $problem');
      failed = true;
    }
  }
  if (failed) exit(1);
}

/// One line for [run]: its id, platform and build mode, its frames and
/// those lost, its parts and issues, and whether it is valid.
String summarise(Map<String, Object?> run) {
  final identity = run['identity']! as Map<String, Object?>;
  final missing = run['framesMissing']! as List<Object?>;
  final lost = missing.fold<int>(
    0,
    (sum, gap) => sum + ((gap! as List<Object?>)[1]! as int),
  );
  final reasons = runReasons(run);
  final verdict = run['valid'] == true ? 'valid' : 'void ($reasons)';
  return '${run['runId']}  ${identity['platform']} ${identity['buildMode']}  '
      '${run['frameCount']} frames, $lost lost, '
      '${partsOf(run).length} parts, '
      '${(run['issues']! as List<Object?>).length} issues, $verdict';
}
