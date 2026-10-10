#!/usr/bin/env bash
# Runs the sample app's ordinary integration tests, with Butterscope
# attached, on one phone in profile mode, and prints each test's frames
# from the report Butterscope prints.
#
#   tool/m5/run_tests.sh <device-id> [build ...]
#
# A build is "clean" or a plant such as "raster_clip". With none named, it
# runs the clean build and then each plant in lib/src/plants/plant.dart
# that names a screen. RUNS=10 runs each build ten times. TARGET names
# another test file to run in place of integration_test/app_test.dart,
# such as integration_test/m5_harness_test.dart.
#
# The tests now record frames, so the runs keep outside work out as M4's
# probe runs did (decision record 0004, decision 3): one clean warm-up run
# that is not counted (WARMUP=off skips it), and on Android the checks in
# tool/android_ready.sh before each run. The warm-up must draw at 114 Hz
# or more in every test of 11 frames or more, or the batch stops: until
# M6's rate mismatch, a capped screen reads as an app losing half its
# frames. A shorter test has too few vsync gaps for a rate. iOS reports none
# of this to the Mac: keep Low Power Mode and Limit Frame Rate off, close
# other apps and let the phone cool between batches.
#
# Each run's transcript and table go to build/m5_tests/<device-id>/, or
# build/m5_tests/<device-id>/<target>/ for another TARGET. A run
# passes when every test passed and its report is whole. Exits 1 when any
# run fails.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: tool/m5/run_tests.sh <device-id> [build ...]" >&2
  exit 64
fi
device=$1
shift
runs=${RUNS:-1}
warmup=${WARMUP:-on}
target=${TARGET:-integration_test/app_test.dart}

cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=../android_ready.sh
source "tool/android_ready.sh"

if [ $# -eq 0 ]; then
  # Each screen plant's define name, from lines such as
  # `rasterClip('raster_clip', screen: 'Feed'),`.
  set -- clean
  while IFS= read -r name; do
    set -- "$@" "$name"
  done < <(sed -nE "s/^  [a-zA-Z]+\('([a-z_]+)', screen: '[A-Za-z]+'\)[,;]$/\1/p" \
    lib/src/plants/plant.dart)
fi

android=false
if command -v adb >/dev/null && adb devices | grep -q "^$device[[:space:]]"; then
  android=true
fi

out=build/m5_tests/$device
if [ "$target" != integration_test/app_test.dart ]; then
  out=$out/$(basename "$target" .dart)
fi
mkdir -p "$out"

# Runs the tests once: run <plant define> <name> [--min-hz <hertz>].
# Prints the table and returns 1 when the run or its report failed.
run() {
  local define=$1 name=$2 log=$out/$2.log
  shift 2
  : >"$log"
  if $android; then
    # The phone's readings go into the log beside the frames they explain.
    android_ready 2>&1 | tee -a "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 2
    adb -s "$device" logcat -c
  fi
  fvm flutter drive --profile --no-dds --keep-app-running \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    --dart-define=BUTTERSCOPE_PLANT="$define" \
    -d "$device" >>"$log" 2>&1
  local drove=$?
  $android && adb -s "$device" logcat -d -s flutter >>"$log"
  fvm dart run tool/m5/read_report.dart "$log" "$@" | tee "$out/$name.txt"
  local read=${PIPESTATUS[0]}
  if [ "$drove" -ne 0 ] || [ "$read" -ne 0 ]; then
    echo "  FAIL: see $log and $out/$name.txt"
    return 1
  fi
}

if [ "$warmup" = on ]; then
  echo "== warm-up: clean, not counted"
  if ! run "" warmup --min-hz 114; then
    echo "STOP: the warm-up failed or drew under 114 Hz. Check Limit Frame"
    echo "Rate, power saving and the refresh rate setting, then run again."
    exit 1
  fi
fi

results=()
status=0
for plant in "$@"; do
  define=$plant
  [ "$plant" = clean ] && define=
  for n in $(seq 1 "$runs"); do
    echo "== $plant, run $n of $runs"
    run "$define" "$plant-$n"
    case $? in
      0) results+=("pass  $plant-$n") ;;
      2) exit 1 ;;
      *) results+=("FAIL  $plant-$n") && status=1 ;;
    esac
  done
done
$android &&
  adb -s "$device" shell am force-stop dev.butterscope.butterscope_sample

echo
echo "== Results on $device"
printf '%s\n' "${results[@]}"
exit "$status"
