#!/usr/bin/env bash
# `melos run check`: every check CI runs, over the whole repository. Claude
# Code runs it before each commit (see .claude/settings.json).
#
# Every check runs even when an earlier one fails, so one run reports every
# finding. Formatting rewrites the files it would change and still fails, so
# the fix gets reviewed and staged. Exits 1 when any check fails.
#
# Run it through Melos, which puts the pinned SDK first on PATH.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

failed=""

# Runs one check under a heading, and notes it when it fails.
check() {
  local name=$1
  shift
  echo "== $name"
  "$@" || failed="$failed $name"
  echo
}

# From the root, so Dart files outside the packages count too. dart format
# skips hidden folders such as .fvm and .dart_tool.
check Formatting dart format --set-exit-if-changed .
# One pass over the whole workspace, as in CI.
check Analysis flutter analyze --fatal-infos
check Tests melos test
check Complexity tool/complexity.sh

if [ -z "$failed" ]; then
  echo "Every check passed."
  exit 0
fi
echo "Failed:$failed."
exit 1
