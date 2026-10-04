#!/usr/bin/env bash
# The code-health checks, built on the tools from
# https://github.com/kevmoo/analytica.dart. Each check is a Melos script, and
# CI and `melos run check` (which Claude Code runs before each commit) run
# all three:
#
#   tool/analytica.sh complexity [--github]    melos run complexity
#   tool/analytica.sh duplication [--github]   melos run duplication
#   tool/analytica.sh dead-code [--github]     melos run dead-code
#
# complexity   cognitive_complexity fails on a function that scores above 15
#              or a file over 400 lines. shallow fails on a helper with one
#              caller that can be inlined without taking that caller over 15
#              (SAFE_INLINE); helpers a test calls are left out. file_split
#              prints a plan for splitting each file over 400 lines.
# duplication  dedupe fails on any block of 40 tokens and 4 lines or more
#              that appears more than once under lib/.
# dead-code    undead fails on any declaration that nothing reaches, package
#              by package. A package with an entry point (bin/ or
#              lib/main.dart) is traced from it as an app; any other is a
#              library, traced from its exports and from the packages that
#              use it.
#
# Every tool in a check runs, so one run reports every finding. Exits 1 when
# the check fails. With --github (CI), findings are annotations and each
# tool's report goes to the run's summary page.
#
# The tools are dev dependencies of the workspace root: the root
# pubspec.yaml pins their versions and pubspec.lock everything they depend
# on. Each runs as a native executable, compiled from those packages the
# first time it is needed after pubspec.lock or .fvmrc changes, about half a
# minute each. After that a check takes seconds, apart from undead, which
# resolves each package. Rules and reasons: docs/review-rules.md.
set -uo pipefail

# Change the limits here only, and their rows in docs/review-rules.md. The
# versions are in the root pubspec.yaml; when one changes, copy the tool's
# skill into .claude/skills from the same release or commit.
max_score=15       # cognitive complexity per function; the tool's default
max_file_lines=400 # lines per file; the dart-cognitive-complexity skill's

cd "$(dirname "$0")/.." || exit 1

usage="Usage: tool/analytica.sh complexity|duplication|dead-code [--github]"
check=${1:-}
github=false
case "${2:-}" in
  "") ;;
  --github) github=true ;;
  *)
    echo "$usage" >&2
    exit 64
    ;;
esac

# A folder that does not exist reaches the tools as a literal pattern, and
# they fail on it, so a renamed package cannot drop out unnoticed.
targets=(packages/*/lib tools/*/lib apps/*/lib)
packages=(packages/* tools/* apps/*)

# The compiled tools live in .dart_tool/analytica/<key>, one folder per
# pubspec.lock and .fvmrc; CI caches it. In CI, `dart run undead` took 36 s
# for the four packages; compiled ahead of time it takes about 10 s.
key=$(cat pubspec.lock .fvmrc | shasum -a 256 | cut -c1-16)
bin_dir=.dart_tool/analytica/$key

# Prints the folder of a package, from the package_config.json pub writes
# (one key per line).
package_root() {
  awk -v name="\"$1\"," '
    $1 == "\"name\":" && $2 == name { found = 1; next }
    found && $1 == "\"rootUri\":" { gsub(/[",]/, "", $2); print $2; exit }
  ' .dart_tool/package_config.json | sed 's|^file://||'
}

# Runs <package>[:<executable>] with the arguments that follow, compiling it
# first when this pubspec.lock has no build of it yet. When Melos runs this
# script, `dart` is the pinned SDK: Melos puts the SDK it was given
# (.fvm/flutter_sdk locally) first on PATH.
tool() {
  local package=${1%%:*} executable=${1#*:} root out
  shift
  out=$bin_dir/$package-$executable
  if [ ! -x "$out" ]; then
    root=$(package_root "$package")
    if [ ! -f "$root/bin/$executable.dart" ]; then
      echo "No $package:$executable; run melos bootstrap." >&2
      return 1
    fi
    echo "Compiling $package:$executable for this pubspec.lock..." >&2
    # Builds for older locks are no longer needed.
    find .dart_tool/analytica -mindepth 1 -maxdepth 1 ! -name "$key" \
      -exec rm -rf {} + 2> /dev/null
    mkdir -p "$bin_dir"
    dart compile exe --packages=.dart_tool/package_config.json \
      -o "$out" "$root/bin/$executable.dart" > /dev/null || return 1
  fi
  "$out" "$@"
}

# Appends a titled report to the run's summary page.
summarize() {
  $github || return 0
  local fence='```'
  printf '### %s\n\n%stext\n%s\n%s\n\n' "$1" "$fence" "$2" "$fence" \
    >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
}

complexity() {
  local status=0 format=text report plan
  $github && format=github

  echo "== Cognitive complexity and file length (cognitive_complexity)"
  tool cognitive_complexity --fail-threshold="$max_score" \
    --max-file-lines="$max_file_lines" --format="$format" "${targets[@]}" ||
    status=1

  echo
  echo "== Single-caller helpers (shallow)"
  # The text report decides the result. In CI a second, JSON run annotates
  # each SAFE_INLINE helper on its first line.
  report=$(tool cognitive_complexity:shallow --fail-on-safe-inline \
    --max-caller-cc="$max_score" "${targets[@]}" 2>&1) || status=1
  echo "$report"
  summarize "Single-caller helpers (shallow)" "$report"
  if $github; then
    tool cognitive_complexity:shallow --max-caller-cc="$max_score" \
      --format=json "${targets[@]}" | jq -r --argjson max "$max_score" '
      .findings[]
      | select(.classification == "SAFE_INLINE")
      | "::error file=\(.file),line=\(.start_line),title=Shallow helper::"
        + "\(.name) has one caller, \(.caller_name) (\(.caller_file):"
        + "\(.call_line)), which scores \(.inlined_caller_score) with it"
        + " inlined (limit \($max)). Inline it. Why it is shallow: "
        + (.reasons | join(", ")) + "."'
  fi

  echo
  echo "== Split plan for files over $max_file_lines lines (file_split)"
  plan=$(tool cognitive_complexity:file_split \
    --target-lines="$max_file_lines" "${targets[@]}" 2>&1) || status=1
  echo "$plan"
  summarize "Split plan for files over $max_file_lines lines (file_split)" \
    "$plan"
  return "$status"
}

duplication() {
  # A threshold of 0% fails on any duplicated block. In CI each copy is
  # annotated as a warning and the report goes to the summary page.
  local format=text
  $github && format=github
  echo "== Duplicated code (dedupe)"
  if tool dedupe --fail-threshold=0 --format="$format" "${targets[@]}"; then
    return 0
  fi
  $github && echo "::error title=Duplicated code::A block of code under" \
    "lib/ appears more than once; each copy is a warning. Extract it."
  return 1
}

dead_code() {
  local status=0 dir mode report json
  json=$(mktemp)
  for dir in "${packages[@]}"; do
    mode=library
    if [ -d "$dir/bin" ] || [ -f "$dir/lib/main.dart" ]; then
      mode=closed-app
    fi
    echo "== Dead code in $dir, as $mode (undead)"
    : > "$json"
    if report=$(tool undead --mode="$mode" \
      --fail-on-undead --json-output="$json" "$dir" 2>&1); then
      echo "$report"
      continue
    fi
    status=1
    echo "$report"
    summarize "Dead code in $dir (undead)" "$report"
    $github && [ -s "$json" ] && jq -r --arg dir "$dir" '
      .undead[]
      | "::error file=\($dir)/\(.file),line=\(.line),title=Dead code::"
        + "\(.name) (\(.kind), \(.classification)): \(.suggestedAction)"' \
      "$json"
  done
  rm -f "$json"
  return "$status"
}

case "$check" in
  complexity) complexity ;;
  duplication) duplication ;;
  dead-code) dead_code ;;
  *)
    echo "$usage" >&2
    exit 64
    ;;
esac
