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

if ! command -v melos > /dev/null; then
  # No Melos, as in a cloud sandbox without Flutter: the tools cannot run.
  # Tell the agent and let the commit through; AGENTS.md has it say so in
  # the pull request, and CI runs the tools.
  echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse",' \
    '"additionalContext": "The complexity tools did not run before this' \
    'commit: melos is not on PATH. Say so in the pull request; CI runs' \
    'them."}}'
  exit 0
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
