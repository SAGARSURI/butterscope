#!/usr/bin/env bash
# Runs a test file with Butterscope attached on one phone, reads the run's
# lines off the device log while it runs, and ends with `butterscope
# collect`, which writes one checked JSON file per run
# (docs/report-schema.md).
#
#   tool/m7/run_tests.sh <device-id> <label>
#
# <label> names the batch's files, such as `app-profile`.
#
#   RUNS=3         runs the batch three times (default 1).
#   TARGET=...     runs another test file in place of
#                  integration_test/app_test.dart.
#   MODE=release   builds in release mode (default profile).
#   LOSS=on        Android profile runs only: shrinks the phone's log
#                  buffer to 64 KB and reads it after the run instead of
#                  during it, so lines are lost on purpose. Such a run
#                  passes when collect fails and names what was lost.
#   RUN_TIMEOUT=s  how long a run may take from its start line to its last
#                  line (default 1200). A profile run still going then is
#                  stopped.
#   WARMUP=off     skips the warm-up run.
#
# A batch starts with one warm-up run of app_test.dart in profile, not
# counted, as in M4 to M6. Its file must be written whole and the run
# must be clean (tool/m7/summary.dart --warmup), or the batch stops.
#
# Where the lines come from:
#
#   Android    `adb logcat`, streamed from before the launch to the run's
#              last line. M6 read logcat after the run, which a long run
#              can outgrow.
#   iOS        `idevicesyslog -p Runner`, streamed the same way, as in M2's
#              release runs. A profile run also keeps the `flutter drive`
#              transcript, and collect reads both.
#
# Profile runs go through `flutter drive --profile --keep-app-running`.
# `flutter drive` refuses release builds, so release runs are launched as
# in M2 (docs/measurements/m2.md): `flutter run --release --no-resident`
# on Android, and `flutter build ios` then `devicectl` on iOS. A release
# app has no VM service to wait for, so the runner waits for the run's
# `start` line instead, and stops when the start line does not come.
#
# Each run passes the app's commit as BUTTERSCOPE_APP_COMMIT, so the
# report names it; `-dirty` marks uncommitted changes. Before each run the
# previous run's app is stopped, and on Android tool/android_ready.sh
# checks the phone. The batch stops if Xcode is open, since flutter drive
# then launches the app through Xcode and stalls.
#
# Logs, collect's output and the run files go to build/m7_tests/<device-id>/.
# Exits 1 when any run fails.
set -uo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: tool/m7/run_tests.sh <device-id> <label>" >&2
  exit 64
fi
device=$1
label=$2
runs=${RUNS:-1}
target=${TARGET:-integration_test/app_test.dart}
mode=${MODE:-profile}
loss=${LOSS:-off}
run_timeout=${RUN_TIMEOUT:-1200}
warmup=${WARMUP:-on}

cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=../android_ready.sh
source "tool/android_ready.sh"
# shellcheck source=../ios_control.sh
source "tool/ios_control.sh"

android=false
if command -v adb >/dev/null && adb devices | grep -q "^${device}[[:space:]]"; then
  android=true
fi

if [ "$loss" = on ] && [ "$mode" != profile ]; then
  echo "STOP: LOSS=on is for profile runs only."
  exit 1
fi
if $android; then
  if [ "$loss" = on ]; then
    original_size=$(adb -s "$device" logcat -g -b main |
      sed -n 's/.*ring buffer is \([0-9]*\) \([KM]\)iB.*/\1\2/p')
    if [ -z "$original_size" ]; then
      echo "STOP: could not read the phone's log buffer size."
      exit 1
    fi
  fi
else
  if [ "$loss" = on ]; then
    echo "STOP: LOSS=on is for Android only."
    exit 1
  fi
  if pgrep -x Xcode >/dev/null; then
    echo "STOP: quit Xcode, then run again."
    exit 1
  fi
  if ! command -v idevicesyslog >/dev/null; then
    echo "STOP: install libimobiledevice for idevicesyslog."
    exit 1
  fi
fi

commit=$(git rev-parse HEAD)
[ -n "$(git status --porcelain)" ] && commit=$commit-dirty

out=build/m7_tests/$device
mkdir -p "$out"

defines=(
  --dart-define=BUTTERSCOPE_APP_COMMIT="$commit"
)

# Stops the sample app on the phone.
stop_app() {
  if $android; then
    adb -s "$device" shell am force-stop dev.butterscope.butterscope_sample
  else
    ios_stop
  fi
}

# Puts the phone's log buffer back to its size before the batch.
restore_buffer() {
  [ -n "${original_size:-}" ] && adb -s "$device" logcat -G "$original_size"
}

# On any exit, stops what a run left going: flutter drive, the log reader
# and the app. A cancelled batch would otherwise leave them running.
cleanup() {
  [ -n "${flutter:-}" ] && stop_tree "$flutter"
  [ -n "${stream:-}" ] && kill "$stream" 2>/dev/null
  [ -n "${flutter:-}${stream:-}" ] && stop_app >/dev/null
  restore_buffer
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# Starts streaming the phone's log to <file>, and sets $stream to the
# reader's pid. The reader is started directly and stopped by its pid:
# M2 left 14 logcat readers running on the S24.
start_stream() {
  if $android; then
    adb -s "$device" logcat -c
    adb -s "$device" logcat -s flutter >"$1" 2>&1 &
  else
    idevicesyslog -u "$device" -p Runner >"$1" 2>&1 &
  fi
  stream=$!
}

# Waits until <file> holds the last line of a run, which is the last
# `frames` line, or the last `report` line when the run has no frames.
# Either way the log then stays quiet, so a run whose `report` lines have
# come is over once 15 s pass with no new line. Returns 1 when no `start`
# line comes within <start-wait> seconds, and 2 when the run is not over
# within $run_timeout seconds of it.
wait_for_end() {
  local file=$1 start_wait=$2 waited=0 quiet=0 count last=-1 id=
  while :; do
    if [ -z "$id" ]; then
      id=$(sed -n 's/.*BSCOPE \([0-9][0-9]*\) start.*/\1/p' "$file" |
        head -n 1)
      if [ -z "$id" ] && [ "$waited" -ge "$start_wait" ]; then
        return 1
      fi
      [ -n "$id" ] && waited=0
    else
      grep -q "BSCOPE $id frames \([0-9][0-9]*\)/\1 " "$file" && return 0
      count=$(grep -c "BSCOPE $id " "$file")
      if [ "$count" = "$last" ]; then
        quiet=$((quiet + 5))
      else
        quiet=0
        last=$count
      fi
      if [ "$quiet" -ge 15 ] && grep -q "BSCOPE $id report " "$file"; then
        return 0
      fi
      [ "$waited" -ge "$run_timeout" ] && return 2
    fi
    sleep 5
    waited=$((waited + 5))
  done
}

# Stops flutter drive (<pid>) when the run in <files> has gone on for
# $run_timeout seconds since its start line, and returns 1.
watch_deadline() {
  local pid=$1 waited=0
  shift
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -gt 0 ] || grep -q 'BSCOPE [0-9][0-9]* start' "$@"; then
      waited=$((waited + 5))
      if [ "$waited" -gt "$run_timeout" ]; then
        stop_tree "$pid"
        return 1
      fi
    fi
    sleep 5
  done
}

# Builds and launches a release build of <target>, with output to <log>.
launch_release() {
  local run_target=$1 log=$2
  if $android; then
    fvm flutter run --release --no-resident --target="$run_target" \
      "${defines[@]}" -d "$device" >>"$log" 2>&1
  else
    fvm flutter build ios --release --target="$run_target" \
      "${defines[@]}" >>"$log" 2>&1 &&
      xcrun devicectl device install app --device "$device" \
        build/ios/iphoneos/Runner.app >>"$log" 2>&1 &&
      xcrun devicectl device process launch --device "$device" \
        dev.butterscope.butterscopeSample >>"$log" 2>&1
  fi
}

# Runs <target> once in <mode> as <name>, leaving its log at
# $out/<name>.log and the phone's log at $out/<name>.device.log. Returns
# 1 when the run failed, 2 when the phone was not ready or the app did not
# start.
drive() {
  local run_target=$1 run_mode=$2 name=$3 log=$out/$3.log
  local device_log=$out/$3.device.log status=0
  : >"$log"
  if $android; then
    android_ready 2>&1 | tee -a "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
  else
    ios_stop | tee -a "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
  fi
  if [ "$loss" = on ]; then
    adb -s "$device" logcat -G 64K
    adb -s "$device" logcat -c
  else
    start_stream "$device_log"
  fi
  if [ "$run_mode" = release ]; then
    launch_release "$run_target" "$log" || status=1
    if [ "$status" -eq 0 ] && [ "$loss" = off ]; then
      wait_for_end "$device_log" 180
      case $? in
        0) ;;
        1)
          echo "STOP: the app did not print its start line. Unlock the"
          echo "phone and check the developer is trusted, then run again."
          status=2
          ;;
        *) status=1 ;;
      esac
    fi
  else
    fvm flutter drive --profile --no-dds --keep-app-running \
      --driver=test_driver/integration_test.dart \
      --target="$run_target" "${defines[@]}" \
      -d "$device" >>"$log" 2>&1 &
    flutter=$!
    watch_deadline "$flutter" "$log" "$device_log" 2>/dev/null &
    local deadline=$!
    if watch_launch "$flutter" "$log"; then
      wait "$flutter" || status=1
    else
      wait "$flutter"
      status=2
    fi
    flutter=
    if ! wait "$deadline"; then
      echo "  The run went on over $run_timeout s from its start line;" \
        "stopped it."
      status=1
    fi
    # The device log lags the transcript a little. Collect then judges
    # what arrived, so a run that never ends in it only costs the wait.
    if [ "$status" -ne 2 ] && [ "$loss" = off ]; then
      wait_for_end "$device_log" 30
    fi
  fi
  if [ "$loss" = on ]; then
    adb -s "$device" logcat -d -s flutter >"$device_log"
    restore_buffer
  else
    kill "$stream" 2>/dev/null
    wait "$stream" 2>/dev/null
    stream=
  fi
  stop_app >/dev/null
  return "$status"
}

# Collects run <name> into $out/<name>/, from the phone's log and, for an
# iOS profile run, the transcript too. Prints collect's first 30 lines,
# and returns collect's exit code.
collect() {
  local name=$1 run_mode=$2 sources=("$out/$1.device.log") code lines
  if ! $android && [ "$run_mode" = profile ]; then
    sources+=("$out/$1.log")
  fi
  fvm dart run ../../tools/butterscope_cli/bin/butterscope.dart collect \
    --out "$out/$name" "${sources[@]}" >"$out/$name.collect.txt" 2>&1
  code=$?
  head -n 30 "$out/$name.collect.txt"
  lines=$(wc -l <"$out/$name.collect.txt")
  [ "$lines" -gt 30 ] &&
    echo "  ... $((lines - 30)) more lines in $out/$name.collect.txt"
  return "$code"
}

# Runs <target> once in <mode> as <name> and collects it, passing
# [check] to tool/m7/summary.dart. Returns 1 when the run failed or did
# not come off the phone as it should, 2 when the phone was not ready.
run() {
  local run_target=$1 run_mode=$2 name=$3 check=${4:-} summarised=1
  rm -rf "${out:?}/$name"
  drive "$run_target" "$run_mode" "$name"
  local drove=$?
  [ "$drove" -eq 2 ] && return 2
  collect "$name" "$run_mode"
  local collected=$?
  if [ "$loss" = on ]; then
    # A forced loss passes when the test passed and collect fails naming
    # lines that never arrived, not some other problem.
    if [ "$drove" -eq 0 ] && [ "$collected" -eq 1 ] &&
      grep -qE '^  (missingLine|noReport|no start line|no frames line)' \
        "$out/$name.collect.txt"; then
      return 0
    fi
    echo "  FAIL: the test failed, or collect named no lost line; see" \
      "$out/$name.log and $out/$name.collect.txt"
    return 1
  fi
  local files=("$out/$name"/*.json)
  if [ -e "${files[0]}" ]; then
    fvm dart run tool/m7/summary.dart ${check:+"$check"} "${files[@]}" |
      tee "$out/$name.txt"
    summarised=${PIPESTATUS[0]}
  fi
  if [ "$drove" -ne 0 ] || [ "$collected" -ne 0 ] ||
    [ "$summarised" -ne 0 ]; then
    echo "  FAIL: see $out/$name.log and $out/$name.collect.txt"
    return 1
  fi
}

if [ "$warmup" = on ]; then
  echo "== warm-up: app_test.dart in profile, not counted"
  # Run here, not in a subshell, so a cancel stops what it started.
  batch_loss=$loss
  loss=off
  run integration_test/app_test.dart profile warmup --warmup
  warmed=$?
  loss=$batch_loss
  case $warmed in
    0) ;;
    2) exit 1 ;;
    *)
      echo "STOP: the warm-up did not come off the phone whole, or was not"
      echo "clean. Check Limit Frame Rate, power saving, the refresh rate"
      echo "setting and the phone's temperature, then run again."
      exit 1
      ;;
  esac
fi

results=()
status=0
for n in $(seq 1 "$runs"); do
  echo "== $label, run $n of $runs"
  run "$target" "$mode" "$label-$n"
  case $? in
    0) results+=("pass  $label-$n") ;;
    2) exit 1 ;;
    *) results+=("FAIL  $label-$n") && status=1 ;;
  esac
done

echo
echo "== Results on $device"
printf '%s\n' "${results[@]}"
exit "$status"
