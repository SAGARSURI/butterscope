/// Summarises the windows in a saved M2 probe log.
///
/// butterscope's metrics use `dart:ui`, which only the Flutter test runner
/// provides on a host, so this runs through it:
///
/// ```sh
/// cd apps/sample
/// BSCOPE_LOG=/path/to/logcat.txt fvm flutter test tool/m2/summarise.dart
/// ```
library;

import 'dart:io';

import 'bscope_log.dart';
import 'window_summary.dart';

void main() {
  final path = Platform.environment['BSCOPE_LOG'];
  if (path == null || path.isEmpty) {
    stderr.writeln('Set BSCOPE_LOG to the path of a saved log.');
    exitCode = 64;
    return;
  }
  final log = readBscopeLog(File(path).readAsStringSync());
  for (final window in log.windows) {
    stdout.writeln(summariseWindow(window));
  }
  if (log.problems.isEmpty) {
    stdout.writeln('Every line is present.');
  } else {
    log.problems.forEach(stdout.writeln);
  }
}
