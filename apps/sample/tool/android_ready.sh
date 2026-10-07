# Sourced by the device runners in tool/m4 and tool/m5, from the sample
# app's root, with $device set to the phone's id.

# Android only. Fails when power saving is on, Stay awake is off or less
# than 2 GB of memory is free, since other apps' work would land in the
# window. Free memory is not waited on: the S24 has sat at 2.7 to 2.9 GB
# for 10 minutes without rising, while its clean runs stayed steady at 3.1
# to 3.4 GB. Waits up to 10 minutes for the phone to cool: thermal status
# 0 (no throttling) and the battery at 38 °C or less. Prints the phone's
# state, which goes in the batch's transcript.
android_ready() {
  local power awake thermal battery tenths level mem load waited=0
  # `--keep-app-running` leaves the last run's app animating in the
  # foreground, where it held about 300 MB and half a CPU on the S24 and
  # warmed the phone while this waited. flutter drive starts it afresh.
  adb -s "$device" shell am force-stop dev.butterscope.butterscope_sample
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
