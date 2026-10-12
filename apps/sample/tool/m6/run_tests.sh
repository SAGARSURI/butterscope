#!/usr/bin/env bash
# Runs the sample app's integration tests with Butterscope attached, on one
# phone, and checks each run's report shows what the batch was set up to
# show: clean, void by one forced guard, or flagged for a slow screen.
#
#   tool/m6/run_tests.sh <device-id> <label>
#
# <label> names the batch's logs, such as `clean` or `low-power`.
#
#   RUNS=3          runs the batch three times (default 1).
#   TARGET=...      runs another test file in place of
#                   integration_test/app_test.dart.
#   EXPECT=...      what each run must show (default `clean`): `clean`,
#                   `flagged`, or the guard a forced run must fail alone,
#                   such as `lowPower`. See tool/m6/read_report.dart.
#   VOID_SPANS=...  spans a clean run should void, as `name=guard`,
#                   separated by `;`.
#   ALLOW=...       guards that may also void a run, warm-up included,
#                   separated by `;`, such as `thermal` for M6's iPhone
#                   runs at "fair", which voided a run until decision
#                   record 0007.
#   FORCE=...       passed to the app as BUTTERSCOPE_FORCE.
#   SEMANTICS=on    passed to the app as BUTTERSCOPE_SEMANTICS (default
#                   off), which M2's and M4's probes and M5's harness read;
#                   ordinary tests leave semantics on, as testWidgets does.
#   MODE=debug      builds in debug mode, to force the build-mode guard.
#   READY=off       skips the Android readiness checks, for a run that
#                   forces power saving or a thermal state on purpose.
#   WARMUP=off      skips the warm-up run.
#
# A batch starts with one clean warm-up run of app_test.dart that is not
# counted, as in M4 and M5 (decision record 0004, decision 3). It must be
# valid and flag no rate mismatch, or the batch stops. This replaces M5's
# 114 Hz rule, which stood in for the mismatch until M6 built it.
#
# Each run passes the app's commit as BUTTERSCOPE_APP_COMMIT, so the
# report's identity names it; `-dirty` marks uncommitted changes. Before
# each run the previous run's app is stopped: on Android with
# `am force-stop`, on iOS with `devicectl`, since `--keep-app-running`
# leaves it animating. On Android, tool/android_ready.sh then checks the
# phone. iOS has no such check before a run: the report itself reads Low
# Power Mode and the thermal state, and Limit Frame Rate shows only as a
# rate mismatch, so a warm-up that meets any of them stops the batch.
# Close other apps first.
# The batch stops if Xcode is open, since flutter drive then launches the
# app through Xcode, and those launches hung waiting on it (2026-10-04).
#
# Transcripts and tables go to build/m6_tests/<device-id>/. Exits 1 when
# any run fails.
set -uo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: tool/m6/run_tests.sh <device-id> <label>" >&2
  exit 64
fi
device=$1
label=$2
runs=${RUNS:-1}
target=${TARGET:-integration_test/app_test.dart}
expect=${EXPECT:-clean}
mode=${MODE:-profile}
ready=${READY:-on}
warmup=${WARMUP:-on}

cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=../android_ready.sh
source "tool/android_ready.sh"

android=false
if command -v adb >/dev/null && adb devices | grep -q "^$device[[:space:]]"; then
  android=true
fi

commit=$(git rev-parse HEAD)
[ -n "$(git status --porcelain)" ] && commit=$commit-dirty

out=build/m6_tests/$device
mkdir -p "$out"

# Stops the sample app on an iPhone, if it is running. devicectl lists
# processes by executable path, and every Flutter app's executable is
# .../Runner.app/Runner, so the sample's process is the one inside the
# bundle installed under its bundle identifier. Returns 1, saying why,
# when the phone cannot be read or the app does not stop.
ios_stop() {
  local apps processes pid p status=0
  apps=$(mktemp)
  processes=$(mktemp)
  if ! xcrun devicectl device info apps --device "$device" \
    --json-output "$apps" >/dev/null 2>&1 ||
    ! xcrun devicectl device info processes --device "$device" \
      --json-output "$processes" >/dev/null 2>&1 ||
    ! pid=$(python3 -c '
import json, sys
bundles = [
    app["url"] for app in json.load(open(sys.argv[1]))["result"]["apps"]
    if app.get("bundleIdentifier") == "dev.butterscope.butterscopeSample"
]
for p in json.load(open(sys.argv[2]))["result"]["runningProcesses"]:
    if any(p.get("executable", "").startswith(url) for url in bundles):
        print(p["processIdentifier"])
' "$apps" "$processes"); then
    echo "STOP: could not list the iPhone's apps and processes."
    status=1
  else
    for p in $pid; do
      xcrun devicectl device process terminate --device "$device" \
        --pid "$p" >/dev/null && continue
      echo "STOP: could not stop the sample app (pid $p) on the iPhone."
      status=1
    done
  fi
  rm -f "$apps" "$processes"
  return "$status"
}

# Waits while flutter drive (<pid>) runs. After flutter's warning that
# the VM service was not discovered (lib/src/ios/devices.dart in the
# pinned tool), stops flutter drive and returns 1 when the log then stays
# quiet for two minutes. The app's own `flutter:` lines reach the log
# only once flutter drive connects to it (drive/drive_service.dart), so
# one after the warning ends the watch. On 2026-10-11 a phone that had
# dropped trust in the developer certificate hung there with no end.
watch_launch() {
  local pid=$1 log=$2 quiet=0 size last=
  while kill -0 "$pid" 2>/dev/null; do
    if grep -q 'Dart VM Service was not discovered' "$log"; then
      awk '/^flutter: / && warned { found = 1 }
        /Dart VM Service was not discovered/ { warned = 1 }
        END { exit !found }' "$log" && return 0
      size=$(wc -c <"$log")
      if [ "$size" = "$last" ]; then
        quiet=$((quiet + 5))
      else
        quiet=0
        last=$size
      fi
    fi
    if [ "$quiet" -ge 120 ]; then
      stop_tree "$pid"
      echo "STOP: the app did not start. Unlock the phone, quit Xcode and"
      echo "check the developer is trusted in Settings > General > VPN &"
      echo "Device Management, then run again."
      return 1
    fi
    sleep 5
  done
}

# Stops <pid> and every process under it: fvm runs flutter, which runs
# the tool in dart.
stop_tree() {
  local child
  for child in $(pgrep -P "$1"); do
    stop_tree "$child"
  done
  kill "$1" 2>/dev/null
}

# Runs <target> once as <name>, with the reader's options after them.
# Prints the table and returns 1 when the run or its report failed, 2 when
# the phone was not ready.
run() {
  local run_target=$1 name=$2 log=$out/$2.log
  shift 2
  : >"$log"
  if $android; then
    if [ "$ready" = on ]; then
      # The phone's readings go into the log beside the frames they explain.
      android_ready 2>&1 | tee -a "$log"
      [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
    else
      adb -s "$device" shell am force-stop dev.butterscope.butterscope_sample
    fi
    adb -s "$device" logcat -c
  else
    ios_stop | tee -a "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
  fi
  # Empty arrays are written ${a[@]+"${a[@]}"}, which macOS's bash 3.2
  # accepts under set -u.
  local build=(--profile)
  [ "$mode" = debug ] && build=()
  fvm flutter drive ${build[@]+"${build[@]}"} --no-dds --keep-app-running \
    --driver=test_driver/integration_test.dart \
    --target="$run_target" \
    --dart-define=BUTTERSCOPE_APP_COMMIT="$commit" \
    --dart-define=BUTTERSCOPE_FORCE="${FORCE:-}" \
    --dart-define=BUTTERSCOPE_SEMANTICS="${SEMANTICS:-off}" \
    -d "$device" >>"$log" 2>&1 &
  local drive=$!
  watch_launch "$drive" "$log" || return 2
  wait "$drive"
  local drove=$?
  $android && adb -s "$device" logcat -d -s flutter >>"$log"
  fvm dart run tool/m6/read_report.dart "$log" "$@" | tee "$out/$name.txt"
  local read=${PIPESTATUS[0]}
  if [ "$drove" -ne 0 ] || [ "$read" -ne 0 ]; then
    echo "  FAIL: see $log and $out/$name.txt"
    return 1
  fi
}

if ! $android && pgrep -x Xcode >/dev/null; then
  echo "STOP: quit Xcode, then run again."
  exit 1
fi

allowed=()
IFS=';' read -ra guards <<<"${ALLOW:-}"
for guard in ${guards[@]+"${guards[@]}"}; do
  allowed+=(--allow "$guard")
done

if [ "$warmup" = on ]; then
  echo "== warm-up: clean app_test.dart, not counted"
  (mode=profile FORCE= run integration_test/app_test.dart warmup \
    ${allowed[@]+"${allowed[@]}"})
  case $? in
    0) ;;
    # The phone was not ready; the check above says why.
    2) exit 1 ;;
    *)
      echo "STOP: the warm-up failed, was void or flagged a rate mismatch."
      echo "Check Limit Frame Rate, power saving, the refresh rate setting"
      echo "and the phone's temperature, then run again."
      exit 1
      ;;
  esac
fi

options=(--expect "$expect" ${allowed[@]+"${allowed[@]}"})
IFS=';' read -ra spans <<<"${VOID_SPANS:-}"
for span in ${spans[@]+"${spans[@]}"}; do
  options+=(--void-span "$span")
done

results=()
status=0
for n in $(seq 1 "$runs"); do
  echo "== $label, run $n of $runs"
  run "$target" "$label-$n" "${options[@]}"
  case $? in
    0) results+=("pass  $label-$n") ;;
    2) exit 1 ;;
    *) results+=("FAIL  $label-$n") && status=1 ;;
  esac
done
if $android; then
  adb -s "$device" shell am force-stop dev.butterscope.butterscope_sample
else
  ios_stop
fi

echo
echo "== Results on $device"
printf '%s\n' "${results[@]}"
exit "$status"
