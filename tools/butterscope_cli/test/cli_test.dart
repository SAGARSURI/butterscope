import 'dart:convert';
import 'dart:io';

import 'package:butterscope_cli/src/cli.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/runs.dart';

void main() {
  late Directory folder;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('butterscope_cli_test');
    out = StringBuffer();
    err = StringBuffer();
  });

  tearDown(() => folder.deleteSync(recursive: true));

  final run = linesOf(7, 45);
  final whole = [run.start, ...run.report, ...run.frames];

  /// Writes [lines] to a log file in the test's folder, as logcat would,
  /// with its prefix on each line.
  String logOf(String name, List<String> lines) {
    final file = File('${folder.path}/$name')
      ..writeAsStringSync(
        [for (final line in lines) 'I flutter : $line'].join('\n'),
      );
    return file.path;
  }

  Future<int> collect(List<String> args, {List<String> input = const []}) {
    return runCli(
      ['collect', '--out', '${folder.path}/runs', ...args],
      input: Stream.value(utf8.encode(input.join('\n'))),
      out: out,
      err: err,
    );
  }

  Map<String, Object?> written(int runId) {
    final file = File('${folder.path}/runs/$runId.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  }

  test('writes each whole run from a log and exits 0', () async {
    expect(await collect([logOf('logcat.txt', whole)]), 0);

    expect(written(7)['frames'], hasLength(45));
    expect(out.toString(), '7: wrote ${folder.path}/runs/7.json\n');
  });

  test('reads standard input when no log is named', () async {
    expect(await collect([], input: whole), 0);

    expect(written(7)['runId'], 7);
  });

  test('counts a line that two logs both hold once', () async {
    // The flutter drive transcript and logcat both hold every line.
    final logs = [logOf('drive.txt', whole), logOf('logcat.txt', whole)];

    expect(await collect(logs), 0);
  });

  test('exits 1 and names the loss when a frames line is lost', () async {
    final lost = [run.start, ...run.report, run.frames[0], run.frames[2]];

    expect(await collect([logOf('logcat.txt', lost)]), 1);

    expect(written(7)['framesMissing'], [
      [20, 20],
    ]);
    expect(out.toString(), contains('  missingLine, frames, line 2\n'));
  });

  test('exits 1 and writes nothing when no run is in the log', () async {
    expect(
      await collect([
        logOf('logcat.txt', ['hello']),
      ]),
      1,
    );

    expect(out.toString(), 'No Butterscope run in the log.\n');
    expect(Directory('${folder.path}/runs').existsSync(), isFalse);
  });

  test('exits 1 when a log cannot be read', () async {
    expect(await collect(['${folder.path}/missing.txt']), 1);

    expect(err.toString(), startsWith('Cannot read '));
  });

  test('exits 1 and names the file when it cannot write a run', () async {
    // A file where the output folder should be.
    File('${folder.path}/runs').writeAsStringSync('');

    expect(await collect([logOf('logcat.txt', whole)]), 1);

    expect(
      err.toString(),
      startsWith('Cannot write ${folder.path}/runs/7.json'),
    );
  });

  test('exits 64 with the usage for a command line it cannot read', () async {
    final codes = [
      await runCli([], input: const Stream.empty(), out: out, err: err),
      await runCli(
        ['collect', '--bogus'],
        input: const Stream.empty(),
        out: out,
        err: err,
      ),
    ];

    expect(codes, [usageExitCode, usageExitCode]);
    expect(err.toString(), contains('Usage: butterscope collect'));
  });
}
