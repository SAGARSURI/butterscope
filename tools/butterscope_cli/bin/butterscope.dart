import 'dart:io';

import 'package:butterscope_cli/src/cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args, input: stdin, out: stdout, err: stderr);
}
