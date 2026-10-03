#!/usr/bin/env bash
# `melos run check:changed`: the host checks for what this branch changed.
#
# Formats the whole repository, then analyzes and tests only the packages
# changed since the branch left origin/main, with Melos's --diff and
# --include-dependents filters: a changed package and every package that
# depends on it. Uncommitted edits count, staged or not; a new file counts
# once it is staged with `git add`.
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

# Melos turns a single commit into `<commit>...HEAD`, which leaves out
# uncommitted edits, so the range ends at a snapshot of them instead.
# `git stash create` records the tracked files as they are now, staged or
# not, as a commit object without changing the working tree, the index or
# any branch. It prints nothing when there is nothing uncommitted.
snapshot=$(git stash create)
range="$base...${snapshot:-HEAD}"

dart format --set-exit-if-changed .

shared=(pubspec.yaml pubspec.lock analysis_options.yaml .fvmrc)
if git diff --quiet "$base" -- "${shared[@]}"; then
  echo "Checking the packages changed since $(git rev-parse --short "$base")" \
    "and the packages that depend on them."
  filters=(--diff="$range" --include-dependents)
else
  echo "A file every package shares changed: checking every package."
  filters=()
fi

# The ${x+...} form keeps an empty array safe under `set -u` in bash 3.2,
# which macOS ships.
melos analyze ${filters[@]+"${filters[@]}"}
melos test ${filters[@]+"${filters[@]}"}
