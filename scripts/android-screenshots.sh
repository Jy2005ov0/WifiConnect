#!/usr/bin/env bash
# Usage: android-screenshots.sh path/to/app-debug.apk (with an emulator running)
set -euo pipefail

APK="$1"
PACKAGE=com.wificonnect.app
OUT=screenshots
mkdir -p "$OUT"

adb install -r "$APK"

# Clean status bar: 9:41, full battery, no notifications.
adb shell settings put global sysui_demo_allowed 1
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" > /dev/null; }
demo enter
demo clock -e hhmm 0941
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4
demo network -e mobile show -e datatype none -e level 4
demo notifications -e visible false

shoot() {
  local name=$1; shift
  adb shell am force-stop "$PACKAGE"
  adb shell am start -W -n "$PACKAGE/.MainActivity" --es demoStudentId A0123456X "$@"
  sleep 5
  adb exec-out screencap -p > "$OUT/android-$name.png"
}

shoot 1-ready     --es demoState idle
shoot 2-connected --es demoState connected
shoot 3-settings  --es demoState idle --es demoScreen settings
adb shell cmd uimode night yes
sleep 2
shoot 5-dark      --es demoState connected
