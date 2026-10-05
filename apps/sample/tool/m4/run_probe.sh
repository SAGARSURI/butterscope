#!/usr/bin/env bash
# Runs M4's probe (integration_test/m4_probe_test.dart) on one phone in
# profile mode, once per build named, and prints the frames each screen
# lost.
#
#   tool/m4/run_probe.sh <device-id> <build> [build ...]
#
# A build is "clean", a plant such as "raster_clip", or a plant and a cost
# such as "raster_clip=12", which sets the plant's knob for that build
# (BUTTERSCOPE_COST, see lib/src/plants/plant_costs.dart). RUNS=3 runs each
# build three times. M2's plants, which name no screen, run M2's probe on
# the calibration screen instead, where the animated window is the planted
# one; "calibration" runs that probe with no plant.
#
# Each run's transcript and summary go to build/m4_probe/<device-id>/. On
# Android the app's logcat lines are added to the transcript, so a line
# either source dropped is still read once.
#
# A clean run whose screen drew under 114 Hz on any screen stops the batch:
# a capped or power-saving screen reads as a plant losing frames. The phone
# must stay unlocked: Stay awake on for Android, Auto-Lock off for iOS.
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: tool/m4/run_probe.sh <device-id> <build> [build ...]" >&2
  exit 64
fi
device=$1
shift
runs=${RUNS:-1}

cd "$(dirname "$0")/../.." || exit 1

android=false
if command -v adb >/dev/null && adb devices | grep -q "^$device[[:space:]]"; then
  android=true
fi

out=build/m4_probe/$device
mkdir -p "$out"

# Prints one line per screen from a summary: lost share, observed rate,
# and a mark on the planted screen. Prints the lowest observed rate last,
# on a line of its own, for the clean check: "none" when no screen had one.
compact() {
  awk '
    /== [a-z]+ \(/ {
      match($0, /== [a-z]+/); screen = substr($0, RSTART + 3, RLENGTH - 3)
      if (match($0, /screen=[A-Za-z]+/)) screen = substr($0, RSTART + 7, RLENGTH - 7)
      planted = ($0 ~ /planted=true/) ? "planted" : ""
    }
    /Frames lost/ { match($0, /\([-0-9.]+%\)/); lost = substr($0, RSTART + 1, RLENGTH - 2) }
    /Observed rate/ {
      match($0, /[0-9.]+ Hz|n\/a/); hz = substr($0, RSTART, RLENGTH)
      printf "  %-9s %-8s lost %8s   observed %s\n", screen, planted, lost, hz
      if (hz != "n/a") {
        rate = hz + 0
        if (min == "" || rate < min) min = rate
      }
    }
    END { print "MIN " (min == "" ? "none" : min) }
  ' "$1"
}

# M2's plants: the define names in lib/src/plants/plant.dart with no screen,
# from lines such as `slowRaster('slow_raster'),`.
m2_plants=" calibration $(sed -nE "s/^  [a-zA-Z]+\('([a-z_]+)'\)[,;]$/\1/p" \
  lib/src/plants/plant.dart | tr '\n' ' ')"

status=0
for build in "$@"; do
  plant=${build%%=*}
  cost=
  [ "$build" != "$plant" ] && cost=${build#*=}
  define=$plant
  [ "$plant" = clean ] || [ "$plant" = calibration ] && define=
  target=integration_test/m4_probe_test.dart
  case "$m2_plants" in
    *" $plant "*) target=integration_test/m2_calibration_test.dart ;;
  esac
  for n in $(seq 1 "$runs"); do
    name=$plant${cost:+-$cost}-$n
    log=$out/$name.log
    echo "== $build, run $n of $runs"
    $android && adb -s "$device" logcat -c
    fvm flutter drive --profile --no-dds --keep-app-running \
      --driver=test_driver/integration_test.dart \
      --target="$target" \
      --dart-define=BUTTERSCOPE_PLANT="$define" \
      --dart-define=BUTTERSCOPE_COST="$cost" \
      -d "$device" >"$log" 2>&1
    $android && adb -s "$device" logcat -d -s flutter >>"$log"
    BSCOPE_LOG=$log fvm flutter test tool/m2/summarise.dart \
      >"$out/$name.txt" 2>&1
    grep -q "Every line is present" "$out/$name.txt" ||
      echo "  WARNING: lines missing or no done line; see $out/$name.txt"
    lines=$(compact "$out/$name.txt")
    echo "$lines" | grep -v '^MIN '
    lowest=$(echo "$lines" | sed -n 's/^MIN //p')
    if { [ "$plant" = clean ] || [ "$plant" = calibration ]; } &&
      [ "$lowest" != none ] &&
      awk "BEGIN { exit !($lowest < 114) }"; then
      echo "STOP: a clean screen drew at $lowest Hz. Check Limit Frame Rate,"
      echo "power saving and the refresh rate setting, then run again."
      exit 1
    fi
    grep -q "All tests passed" "$log" || status=1
  done
done
exit "$status"
