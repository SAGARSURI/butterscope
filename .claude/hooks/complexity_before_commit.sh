#!/usr/bin/env bash
# Claude Code runs this before each `git commit` it makes (see
# .claude/settings.json). It runs `melos run complexity` and, when a tool
# fails, blocks the commit with the report as the reason, so the agent fixes
# the code first. The tools read the working tree: what the commit is about
# to record, plus any edits left unstaged.
set -uo pipefail

# The settings' `if` rule already picks commit commands. This check repeats
# it for a Claude Code too old to know `if`, which runs the hook before
# every Bash command.
input=$(cat)
case "$input" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 1

# Without Melos or the SDK it runs the tools on, as in a cloud sandbox with
# no Flutter, the tools cannot run. Tell the agent why and let the commit
# through; AGENTS.md has it say so in the pull request, and CI runs them.
skip() {
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse",' \
    '"additionalContext": "The complexity tools did not run before this' \
    "commit: $1. Say so in the pull request; CI runs them.\"}}"
  exit 0
}

command -v melos > /dev/null || skip "melos is not on PATH"

# Melos takes its SDK from MELOS_SDK_PATH, else from sdkPath in the root
# pubspec.yaml (.fvm/flutter_sdk); "auto" means the dart on PATH.
sdk=${MELOS_SDK_PATH:-.fvm/flutter_sdk}
if [ "$sdk" = auto ]; then
  command -v dart > /dev/null || skip "dart is not on PATH"
elif [ ! -x "$sdk/bin/dart" ]; then
  skip "there is no Dart SDK at $sdk (run fvm use)"
fi

if report=$(melos run complexity 2>&1); then
  exit 0
fi

{
  echo "Commit blocked: melos run complexity failed."
  echo "Fix the code, then commit again. Suppressions are off limits"
  echo "(AGENTS.md); the dart-cognitive-complexity skill has the steps."
  echo
  echo "$report"
} >&2
exit 2
