#!/usr/bin/env bash
# Runs the sample app's ordinary integration tests on one phone in profile
# mode: once with no plant, then once with each screen's plant built in. A
# plant makes a screen slow, never wrong, so every run should pass.
#
#   tool/m4/run_tests.sh <device-id> [plant ...]
#
# With no plant named, it runs the clean build and then each plant in
# lib/src/plants/plant.dart that names a screen. M2's plants run only on the
# calibration screen, which no ordinary test opens, so they are left out;
# name one to run it anyway. "clean" names the build with no plant. Each run's output goes to
# build/m4_tests/<device-id>/<plant>.log, and a pass or fail line per run is
# printed at the end. Exits 1 when any run fails.
#
# The phone must stay unlocked: Stay awake on for Android, Auto-Lock off for
# iOS (see the M2 rig notes). `--keep-app-running` keeps the app installed
# between runs, so iOS does not drop the developer-profile trust.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: tool/m4/run_tests.sh <device-id> [plant ...]" >&2
  exit 64
fi
device=$1
shift

cd "$(dirname "$0")/../.." || exit 1

if [ $# -eq 0 ]; then
  # Each screen plant's define name, from lines such as
  # `rasterClip('raster_clip', screen: 'Feed'),`.
  # A read loop rather than mapfile, which macOS's bash 3.2 lacks.
  set -- clean
  while IFS= read -r name; do
    set -- "$@" "$name"
  done < <(sed -nE "s/^  [a-zA-Z]+\('([a-z_]+)', screen: '[A-Za-z]+'\)[,;]$/\1/p" \
    lib/src/plants/plant.dart)
fi

logs=build/m4_tests/$device
mkdir -p "$logs"
results=()
status=0
for plant in "$@"; do
  define=$plant
  [ "$plant" = clean ] && define=
  echo "== $plant"
  if fvm flutter drive --profile --no-dds --keep-app-running \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/app_test.dart \
    --dart-define=BUTTERSCOPE_PLANT="$define" \
    -d "$device" 2>&1 | tee "$logs/$plant.log"; then
    results+=("pass  $plant")
  else
    results+=("FAIL  $plant  (see $logs/$plant.log)")
    status=1
  fi
done

echo
echo "== Results on $device"
printf '%s\n' "${results[@]}"
exit "$status"
