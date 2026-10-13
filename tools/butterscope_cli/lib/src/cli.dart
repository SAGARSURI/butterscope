import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:butterscope_cli/src/collect.dart';
import 'package:butterscope_report/butterscope_report.dart' show lineTag;

/// The exit code for a command line that cannot be read, as in BSD's
/// `sysexits.h`.
const int usageExitCode = 64;

final ArgParser _collect = ArgParser()
  ..addOption(
    'out',
    abbr: 'o',
    help: 'The folder to write each run to, as <runId>.json.',
    defaultsTo: '.',
  )
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage.');

final ArgParser _parser = ArgParser()
  ..addCommand('collect', _collect)
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage.');

final String _usage =
    '''
Usage: butterscope collect [--out <folder>] [<log> ...]

Reads Butterscope's lines from device logs, or from standard input when
no log is named, and writes each run whose report arrived whole as
<runId>.json. Exits 0 when every run arrived whole, 1 when anything was
lost or does not match schema v1, and $usageExitCode when the command
line cannot be read.

${_collect.usage}''';

/// Runs the command line [args], reading [input] when it names no log and
/// writing to [out] and [err]. Returns the exit code.
Future<int> runCli(
  List<String> args, {
  required Stream<List<int>> input,
  required StringSink out,
  required StringSink err,
}) async {
  final ArgResults parsed;
  try {
    parsed = _parser.parse(args);
  } on FormatException catch (error) {
    err.writeln('${error.message}\n\n$_usage');
    return usageExitCode;
  }
  final command = parsed.command;
  if (parsed.flag('help') || (command?.flag('help') ?? false)) {
    out.writeln(_usage);
    return 0;
  }
  if (command == null) {
    err.writeln(_usage);
    return usageExitCode;
  }
  final logs = command.rest;
  final List<String> lines;
  try {
    lines = await _readLines([
      if (logs.isEmpty) input,
      for (final path in logs) File(path).openRead(),
    ]);
  } on FileSystemException catch (error) {
    err.writeln('Cannot read ${error.path}: ${error.message}');
    return 1;
  }
  return _write(collectLog(lines), Directory(command.option('out')!), out, err);
}

/// The lines of [sources] that carry Butterscope's tag, in order. Bytes
/// that are not UTF-8 are kept as replacement characters, so a mangled line
/// fails its CRC rather than stopping the read.
Future<List<String>> _readLines(List<Stream<List<int>>> sources) async {
  final lines = <String>[];
  for (final source in sources) {
    await for (final line
        in source
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())) {
      if (line.contains('$lineTag ')) lines.add(line);
    }
  }
  return lines;
}

/// Writes each run's file into [folder], says on [out] what happened to
/// each run and on [err] each file it could not write, and returns the
/// exit code.
int _write(LogOutcome log, Directory folder, StringSink out, StringSink err) {
  if (log.runs.isEmpty) out.writeln('No Butterscope run in the log.');
  var written = true;
  for (final run in log.runs) {
    final file = run.file;
    if (file == null) {
      out.writeln('${run.runId}: no file');
    } else {
      final path = '${folder.path}${Platform.pathSeparator}${run.runId}.json';
      try {
        folder.createSync(recursive: true);
        File(path).writeAsStringSync(jsonEncode(file));
        out.writeln('${run.runId}: wrote $path');
      } on FileSystemException catch (error) {
        err.writeln('Cannot write $path: ${error.message}');
        written = false;
      }
    }
    for (final problem in run.problems) {
      out.writeln('  $problem');
    }
  }
  for (final stray in log.strays) {
    out.writeln('A line with no run id: $stray');
  }
  return log.isWhole && written ? 0 : 1;
}
