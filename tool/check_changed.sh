#!/usr/bin/env bash
# `melos run check:changed`: the host checks for what this branch changed.
#
# Formats the whole repository, then analyzes and tests only the packages
# changed since the branch left origin/main, with Melos's --diff and
# --include-dependents filters: a changed package and every package that
# depends on it. Uncommitted edits count; untracked files do not until they
# are added, because --diff reads `git diff`.
#
# --diff only sees files inside a package. A change to a file every package
# shares (the root pubspec.yaml or pubspec.lock, analysis_options.yaml,
# .fvmrc) checks every package instead.
#
# CI always checks every package; this is a quicker local check.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! base=$(git merge-base origin/main HEAD 2> /dev/null); then
  echo "Cannot find where this branch left origin/main." >&2
  echo "Run git fetch origin, or use melos run check." >&2
  exit 1
fi

dart format --set-exit-if-changed .

shared=(pubspec.yaml pubspec.lock analysis_options.yaml .fvmrc)
if git diff --quiet "$base" -- "${shared[@]}"; then
  echo "Checking the packages changed since $(git rev-parse --short "$base")" \
    "and the packages that depend on them."
  filters=(--diff="$base" --include-dependents)
else
  echo "A file every package shares changed: checking every package."
  filters=()
fi

# The ${x+...} form keeps an empty array safe under `set -u` in bash 3.2,
# which macOS ships.
melos analyze ${filters[@]+"${filters[@]}"}
melos test ${filters[@]+"${filters[@]}"}
