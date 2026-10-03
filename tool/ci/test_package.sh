#!/usr/bin/env bash
# Runs one package's tests for `melos run test:ci`. Melos starts it in the
# package's folder and sets MELOS_PACKAGE_NAME, MELOS_PACKAGE_PATH and
# MELOS_ROOT_PATH.
#
# On GitHub Actions, a failing test is annotated on the line that declares
# it, from the runner's JSON report; the log tail is the fallback when there
# is no report (for example, the package did not compile). Annotations go to
# stdout: GitHub reads them only at the start of a line.
set -uo pipefail

root="$MELOS_ROOT_PATH"
escape="$root/tool/ci/escape.sh"
dir="${MELOS_PACKAGE_PATH#"$root"/}"
tmp="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
log="$tmp/test-$MELOS_PACKAGE_NAME.log"
report="$tmp/test-$MELOS_PACKAGE_NAME.json"
rm -f "$report"

if grep -q "sdk: flutter" pubspec.yaml; then
  runner=(flutter test)
else
  runner=(dart test)
fi

result=0
"${runner[@]}" --reporter expanded --file-reporter "json:$report" \
  > "$log" 2>&1 || result=$?
cat "$log"

if [ -z "${GITHUB_ACTIONS:-}" ]; then
  exit "$result"
fi

if [ "$result" -eq 0 ]; then
  echo "::notice title=Tests in $dir::$(tail -n 1 "$log" | "$escape")"
  exit 0
fi

# test_annotations.py resolves paths against the repository root.
annotations=$(cd "$root" &&
  python3 tool/ci/test_annotations.py "$report" "$dir")
if [ -n "$annotations" ]; then
  echo "$annotations"
else
  echo "::error title=Tests failed in $dir::$(tail -n 300 "$log" | "$escape")"
fi
exit "$result"
