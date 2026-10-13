# butterscope_cli

Host CLI for Butterscope. Pure Dart; runs on a laptop or a CI machine.

- `butterscope collect` (M7): reads saved device logs, or standard input,
  and writes each run as `<runId>.json`. The file and what it checks are in
  [`docs/report-schema.md`](../../docs/report-schema.md).
- `butterscope judge` (M9): compares candidate reports with a baseline and
  prints a verdict table for pull requests.

From the repository root, after `melos bs`:

```sh
dart run tools/butterscope_cli/bin/butterscope.dart collect --out runs < logcat.log
dart run tools/butterscope_cli/bin/butterscope.dart collect --out runs drive.log logcat.log
```

`collect` exits 0 when every run arrived whole, 1 when anything was lost or
does not match the schema, and 64 when the command line cannot be read. A
line held by two logs, such as the `flutter drive` transcript and logcat,
counts once.
