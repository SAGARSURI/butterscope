#!/usr/bin/env bash
# Takes screenshots of Flutter's performance overlay on one phone, in
# profile mode, once per build named, while each screen's scripted action
# runs (integration_test/m4_overlay_test.dart).
#
#   tool/m4/run_overlay.sh <device-id> [build ...]
#
# A build is "clean" or a plant. A plant's build shoots its own screen, and
# the clean build shoots every screen, the calibration screen included. With
# no build named, it runs the clean build and the plants that load the
# raster thread or the GPU, whose cost the overlay's raster chart shows:
# raster_clip, gpu_blur, slow_raster, backdrop_blur and gpu_heavy.
#
# Screenshots go to build/m4_overlay/<device-id>/<build>-<screen>.png and
# each run's transcript to <build>.log beside them. On Android the script
# takes each screenshot over adb when the test prints its shot line; on iOS
# the test takes it and the driver saves it. A run fails when its test
# fails or a screenshot it announced is missing. Exits 1 when any run
# fails.
#
# The phone must stay unlocked: Stay awake on for Android, Auto-Lock off for
# iOS. `--keep-app-running` keeps the app installed between runs, so iOS
# does not drop the developer-profile trust.
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: tool/m4/run_overlay.sh <device-id> [build ...]" >&2
  exit 64
fi
device=$1
shift
[ $# -eq 0 ] && set -- clean raster_clip gpu_blur slow_raster backdrop_blur \
  gpu_heavy

cd "$(dirname "$0")/../.." || exit 1

android=false
if command -v adb >/dev/null && adb devices | grep -q "^$device[[:space:]]"; then
  android=true
fi

out=build/m4_overlay/$device
incoming=build/m4_overlay/incoming
mkdir -p "$out"

# Passes the run's output through, and on Android takes a screenshot for
# each shot line, such as `BSCOPE 3 shot raster_clip-feed`, while the
# screen's action is still running.
shoot() {
  local line shot
  while IFS= read -r line; do
    printf '%s\n' "$line"
    $android || continue
    shot=$(printf '%s\n' "$line" |
      sed -nE 's/.*BSCOPE [0-9]+ shot ([a-z0-9_]+-[a-z]+).*/\1/p')
    [ -n "$shot" ] || continue
    adb -s "$device" exec-out screencap -p >"$out/$shot.png"
  done
}

results=()
status=0
for build in "$@"; do
  define=$build
  [ "$build" = clean ] && define=
  log=$out/$build.log
  rm -rf "$incoming"
  rm -f "$out/$build"-*.png
  echo "== $build"
  # The last run's app is left animating by --keep-app-running.
  $android && adb -s "$device" shell am force-stop \
    dev.butterscope.butterscope_sample
  fvm flutter drive --profile --no-dds --keep-app-running \
    --driver=test_driver/overlay_driver.dart \
    --target=integration_test/m4_overlay_test.dart \
    --dart-define=BUTTERSCOPE_OVERLAY=on \
    --dart-define=BUTTERSCOPE_PLANT="$define" \
    -d "$device" 2>&1 | tee "$log" | shoot
  drove=${PIPESTATUS[0]}
  [ -d "$incoming" ] && mv "$incoming"/*.png "$out"/ 2>/dev/null
  # The shots the test's run line says it takes, such as
  # `BSCOPE 1 run plant=clean screens=Feed,Search`, not those whose shot
  # lines arrived: a dropped shot line must not let a run pass.
  run=$(sed -nE 's/.*BSCOPE [0-9]+ run plant=([a-z_]+) screens=([A-Za-z,]+).*/\1 \2/p' \
    "$log" | head -n 1)
  shots=
  if [ -n "$run" ]; then
    for screen in $(echo "${run#* }" | tr ',' ' '); do
      shots="$shots ${run%% *}-$(echo "$screen" | tr '[:upper:]' '[:lower:]')"
    done
  fi
  missing=
  for shot in $shots; do
    [ -s "$out/$shot.png" ] || missing="$missing $shot"
  done
  if [ "$drove" -ne 0 ]; then
    results+=("FAIL  $build  (the test failed; see $log)")
    status=1
  elif [ -z "$shots" ] || [ -n "$missing" ]; then
    results+=("FAIL  $build  (missing:${missing:- every shot}; see $log)")
    status=1
  else
    results+=("pass  $build  (${shots# })")
  fi
done
$android && adb -s "$device" shell am force-stop \
  dev.butterscope.butterscope_sample

echo
echo "== Screenshots on $device, in $out"
printf '%s\n' "${results[@]}"
exit "$status"
