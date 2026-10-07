#!/usr/bin/env bash
# Usage: android-screenshots.sh path/to/app-debug.apk (with an emulator running)
set -euo pipefail

APK="$1"
PACKAGE=com.wificonnect.app
OUT=new-screenshots
mkdir -p "$OUT"

adb install -r "$APK"

# Let the freshly booted emulator settle and keep "isn't responding" popups out of the shots.
adb shell settings put global hide_error_dialogs 1
sleep 30
adb shell input keyevent KEYCODE_HOME

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
  adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS > /dev/null || true
  sleep 1
  adb exec-out screencap -p > "$OUT/android-$name.png"
}

shoot 0-welcome   --es demoState idle --es demoScreen welcome
shoot 1-ready     --es demoState idle
shoot 2-connected --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
shoot 3-settings  --es demoState idle --es demoScreen settings
shoot 6-history   --es demoState idle --es demoScreen history
shoot 7-share     --es demoState idle --es demoScreen share
shoot 8-speedtest --es demoState connected --es demoScreen speed
adb shell cmd locale set-app-locales "$PACKAGE" --locales ja
shoot 9-japanese  --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
adb shell cmd locale set-app-locales "$PACKAGE" --locales ta
shoot 10-tamil    --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
adb shell cmd locale set-app-locales "$PACKAGE" --locales ms
shoot 11-malay    --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
adb shell cmd locale set-app-locales "$PACKAGE" --locales zh
shoot 12-chinese  --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
adb shell cmd locale set-app-locales "$PACKAGE" --locales ""

# The "Connected to utarwifi" notification, and the Quick Settings tile (put first, so it shows).
demo notifications -e visible true
# (Quoted twice: the phone's shell would otherwise choke on the parentheses.)
adb shell "settings put secure sysui_qs_tiles 'custom($PACKAGE/.WifiTileService),internet,bt,flashlight,dnd,airplane,rotation,dark,location'"
adb shell pm grant "$PACKAGE" android.permission.POST_NOTIFICATIONS || true
adb shell am force-stop "$PACKAGE"
adb shell am start -W -n "$PACKAGE/.MainActivity" --es demoStudentId A0123456X --es demoState connected --ez demoNotify true
sleep 3
adb shell cmd statusbar expand-notifications
sleep 3
adb exec-out screencap -p > "$OUT/android-13-notification.png"
adb shell cmd statusbar collapse
sleep 1
adb shell cmd statusbar expand-settings
sleep 3
adb exec-out screencap -p > "$OUT/android-14-quick-settings.png"
adb shell cmd statusbar collapse
sleep 1
adb shell cmd uimode night yes
sleep 2
shoot 5-dark      --es demoState connected --es demoSpeed "'18 ms · 92 Mbps'"
