#!/usr/bin/env bash
# Generates the sample app's Android and iOS folders with the Flutter version
# pinned in .fvmrc. Run once from any directory, then commit the new files.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
fvm install

cd "$root/apps/sample"
fvm flutter create \
  --platforms=android,ios \
  --org dev.butterscope \
  --project-name butterscope_sample \
  .

# `flutter create` adds a counter-app widget test that does not match this app.
rm -f test/widget_test.dart
rmdir test 2>/dev/null || true

echo "Generated platform folders in apps/sample. Review and commit them."
