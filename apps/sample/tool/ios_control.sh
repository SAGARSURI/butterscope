# Sourced by the device runners in tool/m6 and tool/m7, from the sample
# app's root, with $device set to the phone's id.

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
