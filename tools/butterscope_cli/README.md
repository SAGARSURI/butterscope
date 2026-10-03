# butterscope_cli

Host CLI for Butterscope. Pure Dart; runs on a laptop or a CI machine.

- `butterscope collect` (M7): reads `adb logcat` or a saved device log,
  reassembles report chunks and writes one JSON file per run.
- `butterscope judge` (M9): compares candidate reports with a baseline and
  prints a verdict table for pull requests.
