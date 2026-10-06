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
# build three times; SEMANTICS=on turns semantics on, as testWidgets does
# by default (off unless set). M2's plants, which name no screen, run M2's probe on
# the calibration screen instead, where the animated window is the planted
# one; "calibration" runs that probe with no plant.
#
# Each run's transcript and summary go to build/m4_probe/<device-id>/. On
# Android the app's logcat lines are added to the transcript, so a line
# either source dropped is still read once.
#
# A run counts only when its test passed and every window is whole; the
# script marks any other NOT USABLE. A clean run that is not usable, or
# drew under 114 Hz on any screen, stops the batch: a capped or
# power-saving screen reads as a plant losing frames. The phone
# must stay unlocked: Stay awake on for Android, Auto-Lock off for iOS.
#
# Each batch starts with one clean warm-up run of each probe it uses,
# which is not counted: in the S24's first guarded batch, the first runs
# lost more frames than later ones. A failed warm-up stops the batch.
# WARMUP=off skips them.
#
# On Android each run first waits for the phone to cool, and the batch
# stops if power saving is on, Stay awake is off or memory is short (see
# android_ready), so heat, power settings and other apps add nothing to
# the frames lost. iOS reports none of these to the Mac:
# keep Low Power Mode off, close other apps and let the phone cool between
# batches.
set -uo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: tool/m4/run_probe.sh <device-id> <build> [build ...]" >&2
  exit 64
fi
device=$1
shift
runs=${RUNS:-1}
semantics=${SEMANTICS:-off}
warmup=${WARMUP:-on}
for setting in "SEMANTICS=$semantics" "WARMUP=$warmup"; do
  case "${setting#*=}" in
    on | off) ;;
    *) echo "${setting%%=*} must be on or off" >&2; exit 64 ;;
  esac
done

cd "$(dirname "$0")/../.." || exit 1

android=false
if command -v adb >/dev/null && adb devices | grep -q "^$device[[:space:]]"; then
  android=true
fi

out=build/m4_probe/$device
mkdir -p "$out"

# Prints one line per window from a summary: frames lost, observed rate,
# and a mark on the planted window (for M2's plants, the animated one).
# Prints the lowest observed rate last, on a line of its own, for the
# clean check: 0 when any window has no usable rate.
compact() {
  awk '
    function flush() {
      if (screen == "") return
      printf "  %-9s %-8s lost %8s   observed %s\n", screen, planted,
        (lost == "" ? "n/a" : lost), (hz == "" ? "none" : hz)
      windows++
      if (hz ~ / Hz$/) {
        rate = hz + 0
        if (min == "" || rate < min) min = rate
      } else {
        unrated++
      }
    }
    /== [a-z]+ \(/ {
      flush()
      match($0, /== [a-z]+/); screen = substr($0, RSTART + 3, RLENGTH - 3)
      if (match($0, /screen=[A-Za-z]+/)) screen = substr($0, RSTART + 7, RLENGTH - 7)
      m2 = ($0 ~ /== animated / && $0 !~ /plant=none/)
      planted = ($0 ~ /planted=true/ || m2) ? "planted" : ""
      lost = ""; hz = ""
    }
    /Frames lost/ { match($0, /\([-0-9.]+%\)/); lost = substr($0, RSTART + 1, RLENGTH - 2) }
    /Observed rate/ { match($0, /[0-9.]+ Hz|n\/a/); hz = substr($0, RSTART, RLENGTH) }
    END {
      flush()
      print "MIN " ((windows == 0 || unrated > 0) ? 0 : min)
    }
  ' "$1"
}

# Android only. Fails when power saving is on, Stay awake is off or less
# than 2 GB of memory is free, since other apps' work would land in the
# window. Free memory is not waited on: the S24 has sat at 2.7 to 2.9 GB
# for 10 minutes without rising, while its clean runs stayed steady at 3.1
# to 3.4 GB. Waits up to 10 minutes for the phone to cool: thermal status
# 0 (no throttling) and the battery at 38 °C or less. Prints the phone's
# state, which goes in the batch's transcript.
android_ready() {
  local power awake thermal battery tenths level mem load waited=0
  power=$(adb -s "$device" shell settings get global low_power | tr -d '\r')
  awake=$(adb -s "$device" shell dumpsys power |
    sed -n 's/^ *mStayOn=//p' | head -n 1 | tr -d '\r')
  if [ "$power" = 1 ]; then
    echo "STOP: turn power saving off (low_power is $power)."
    return 1
  fi
  # Stay awake keeps the screen on only for the charger types it names.
  # mStayOn is the power service's answer for the charger plugged in now.
  if [ "$awake" != true ]; then
    echo "STOP: turn Developer options > Stay awake on, with the phone" \
      "plugged in (mStayOn is ${awake:-missing})."
    return 1
  fi
  while :; do
    thermal=$(adb -s "$device" shell dumpsys thermalservice |
      sed -n 's/^Thermal Status: //p' | tr -d '\r')
    battery=$(adb -s "$device" shell dumpsys battery | tr -d '\r')
    tenths=$(echo "$battery" | awk '/^ *temperature:/ { print $2 }')
    level=$(echo "$battery" | awk '/^ *level:/ { print $2 }')
    mem=$(adb -s "$device" shell cat /proc/meminfo |
      awk '/^MemAvailable:/ { print int($2 / 1024) }')
    # A reading the phone did not give is not a cool, idle phone.
    if ! [[ "$thermal" =~ ^[0-9]+$ && "$tenths" =~ ^[0-9]+$ &&
      "$mem" =~ ^[0-9]+$ ]]; then
      echo "STOP: could not read the phone's thermal status, battery" \
        "temperature or free memory."
      return 1
    fi
    if [ "$mem" -lt 2048 ]; then
      echo "STOP: only ${mem} MB free. Close other apps on the phone."
      return 1
    fi
    [ "$thermal" -eq 0 ] && [ "$tenths" -le 380 ] && break
    if [ "$waited" -ge 600 ]; then
      echo "STOP: the phone is still hot (thermal status $thermal," \
        "battery $((tenths / 10)) °C)."
      return 1
    fi
    echo "  cooling down: thermal status $thermal," \
      "battery $((tenths / 10)) °C; waiting 30 s"
    sleep 30
    waited=$((waited + 30))
  done
  # The load average is recorded, not checked, until runs show what a
  # quiet phone reads.
  load=$(adb -s "$device" shell cat /proc/loadavg | cut -d ' ' -f 1)
  echo "  phone: thermal status $thermal, battery $((tenths / 10)) °C" \
    "at ${level}%, ${mem} MB free, load ${load:-unknown}"
}

# Runs the probe once in profile mode: drive <target> <plant define>
# <cost> <log>.
drive() {
  fvm flutter drive --profile --no-dds --keep-app-running \
    --driver=test_driver/integration_test.dart \
    --target="$1" \
    --dart-define=BUTTERSCOPE_PLANT="$2" \
    --dart-define=BUTTERSCOPE_COST="$3" \
    --dart-define=BUTTERSCOPE_SEMANTICS="$semantics" \
    -d "$device" >"$4" 2>&1
}

# M2's plants: the define names in lib/src/plants/plant.dart with no screen,
# from lines such as `slowRaster('slow_raster'),`.
m2_plants=" calibration $(sed -nE "s/^  [a-zA-Z]+\('([a-z_]+)'\)[,;]$/\1/p" \
  lib/src/plants/plant.dart | tr '\n' ' ')"

# The probe a plant runs in: M2's on the calibration screen for M2's
# plants, else M4's.
probe() {
  case "$m2_plants" in
    *" $1 "*) echo integration_test/m2_calibration_test.dart ;;
    *) echo integration_test/m4_probe_test.dart ;;
  esac
}

# One warm-up run per probe the batch uses, before any run counts. A
# failed warm-up stops the batch, so a cold run is never counted.
if [ "$warmup" = on ]; then
  warmed=" "
  for build in "$@"; do
    target=$(probe "${build%%=*}")
    case "$warmed" in *" $target "*) continue ;; esac
    warmed="$warmed$target "
    log=$out/warmup-$(basename "$target" .dart).log
    echo "== warm-up: $target, clean, not counted"
    $android && { android_ready || exit 1; }
    if ! drive "$target" "" "" "$log"; then
      echo "STOP: the warm-up run failed; see $log"
      exit 1
    fi
  done
fi

status=0
for build in "$@"; do
  plant=${build%%=*}
  cost=
  [ "$build" != "$plant" ] && cost=${build#*=}
  define=$plant
  [ "$plant" = clean ] || [ "$plant" = calibration ] && define=
  target=$(probe "$plant")
  for n in $(seq 1 "$runs"); do
    name=$plant${cost:+-$cost}-$n
    [ "$semantics" = on ] && name=$plant${cost:+-$cost}-semantics-$n
    log=$out/$name.log
    echo "== $build, semantics $semantics, run $n of $runs"
    $android && { android_ready || exit 1; }
    $android && adb -s "$device" logcat -c
    drive "$target" "$define" "$cost" "$log"
    drove=$?
    $android && adb -s "$device" logcat -d -s flutter >>"$log"
    BSCOPE_LOG=$log fvm flutter test tool/m2/summarise.dart \
      >"$out/$name.txt" 2>&1
    summary=$?
    # summarise.dart is a main, not a test, so flutter test ends a summary
    # that worked with "No tests ran" and exit code 79.
    [ "$summary" -eq 79 ] && summary=0
    lines=$(compact "$out/$name.txt")
    echo "$lines" | grep -v '^MIN '
    # A run counts only when the test passed and every window is whole:
    # every line read, no flush timed out, one declared rate throughout.
    # The summariser prints "Every line is present" per run, so the log
    # must hold one run ("#### Run" heads each of several) and no line it
    # could not read.
    if [ "$drove" -ne 0 ] || [ "$summary" -ne 0 ] ||
      ! grep -q "Every line is present" "$out/$name.txt" ||
      grep -qE "WARNING:|INCOMPLETE:|INVALID:|No usable|Unreadable line|#### Run" \
        "$out/$name.txt"; then
      echo "  NOT USABLE: the run failed or a window is incomplete;"
      echo "  see $log and $out/$name.txt"
      status=1
      usable=false
    else
      usable=true
    fi
    lowest=$(echo "$lines" | sed -n 's/^MIN //p')
    if { [ "$plant" = clean ] || [ "$plant" = calibration ]; } &&
      { ! $usable || awk "BEGIN { exit !($lowest < 114) }"; }; then
      echo "STOP: the clean run is not usable, or a screen drew under 114 Hz"
      echo "($lowest Hz). Check Limit Frame Rate, power saving and the refresh"
      echo "rate setting, then run again."
      exit 1
    fi
  done
done
exit "$status"
