#!/usr/bin/env bash
# `melos run complexity`: the cognitive_complexity tools, over the lib/
# folder of every package. CI and `melos run check`, which Claude Code runs
# before each commit, both run this, so they agree.
#
#   1. cognitive_complexity: fails when a function scores above 15, or a file
#      is longer than 400 lines.
#   2. shallow: fails when a helper has one caller and inlining it keeps that
#      caller at 15 or below (SAFE_INLINE). Helpers a test calls are left
#      out.
#   3. file_split: prints a plan for splitting each file over 400 lines. It
#      never fails; step 1 already does.
#
# Every step runs, so one run reports every finding. Exits 1 when a step
# fails. With --github (CI), findings are annotations and each tool's report
# goes to the run's summary page.
#
# The first run downloads and compiles the tools, which takes about a
# minute. After that a run takes seconds: the tools parse files without
# resolving them, and file_split resolves only a file over the limit.
# Rules and reasons: docs/review-rules.md.
set -uo pipefail

# Change the version and the limits here only, and their rows in
# docs/review-rules.md. Update .claude/skills/dart-cognitive-complexity from
# the same release when the version changes.
version=0.2.5
max_score=15       # cognitive complexity per function; the tool's default
max_file_lines=400 # lines per file; the dart-cognitive-complexity skill's

cd "$(dirname "$0")/.." || exit 1

github=false
case "${1:-}" in
  "") ;;
  --github) github=true ;;
  *)
    echo "Usage: tool/complexity.sh [--github]" >&2
    exit 64
    ;;
esac

# A folder that does not exist reaches the tools as a literal pattern, and
# they fail on it, so a renamed package cannot drop out unnoticed.
targets=(packages/*/lib tools/*/lib apps/*/lib)

# When Melos runs this, `dart` is the pinned SDK: Melos puts the SDK it was
# given (.fvm/flutter_sdk locally) first on PATH.
tool() {
  local executable=$1
  shift
  dart run "cognitive_complexity$executable@$version" "$@"
}

# Appends a titled report to the run's summary page.
summarize() {
  $github || return 0
  local fence='```'
  printf '### %s\n\n%stext\n%s\n%s\n\n' "$1" "$fence" "$2" "$fence" \
    >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
}

status=0

echo "== Cognitive complexity and file length (cognitive_complexity)"
format=text
$github && format=github
tool "" --fail-threshold="$max_score" --max-file-lines="$max_file_lines" \
  --format="$format" "${targets[@]}" || status=1

echo
echo "== Single-caller helpers (shallow)"
# The text report decides the result. In CI a second, JSON run annotates
# each SAFE_INLINE helper on its first line.
report=$(tool :shallow --fail-on-safe-inline --max-caller-cc="$max_score" \
  "${targets[@]}" 2>&1) || status=1
echo "$report"
summarize "Single-caller helpers (shallow)" "$report"
if $github; then
  tool :shallow --max-caller-cc="$max_score" --format=json "${targets[@]}" |
    jq -r --argjson max "$max_score" '
    .findings[]
    | select(.classification == "SAFE_INLINE")
    | "::error file=\(.file),line=\(.start_line),title=Shallow helper::"
      + "\(.name) has one caller, \(.caller_name) (\(.caller_file):"
      + "\(.call_line)), which scores \(.inlined_caller_score) with it inlined"
      + " (limit \($max)). Inline it. Why it is shallow: "
      + (.reasons | join(", ")) + "."'
fi

echo
echo "== Split plan for files over $max_file_lines lines (file_split)"
plan=$(tool :file_split --target-lines="$max_file_lines" \
  "${targets[@]}" 2>&1) || status=1
echo "$plan"
summarize "Split plan for files over $max_file_lines lines (file_split)" "$plan"

exit "$status"
