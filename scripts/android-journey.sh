#!/usr/bin/env bash
# A first-time user, step by step, by tapping and typing on the screen like a person:
# install the app, swipe past the welcome page, type the student ID and password,
# tap the circle, check the internet works, leave and come back, then sign out.
# The only test hook: the app checks for the login page at the mock portal
# (scripts/mock_portal.py on port 8080) instead of Google's address.
# Usage: android-journey.sh path/to/app-debug.apk
set -euo pipefail

APK="$1"
PACKAGE=com.wificonnect.app
PORTAL=http://127.0.0.1:8080
PORTAL_FROM_EMULATOR=http://10.0.2.2:8080
OUT=journey
mkdir -p "$OUT"
HERE=$(cd "$(dirname "$0")" && pwd)

step=0
results=""
shot() { step=$((step + 1)); adb exec-out screencap -p > "$OUT/android-$(printf %02d $step)-$1.png"; }
screen() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || true
  adb exec-out cat /sdcard/ui.xml 2>/dev/null || true
}
find_on_screen() { screen | python3 "$HERE/ui_find.py" android "$1"; }
pass() { echo "PASS: $1"; results+="PASS  $1"$'\n'; }
fail() {
  echo "::error::FAIL: $1"
  results+="FAIL  $1"$'\n'
  shot failed
  screen > "$OUT/android-failed-screen.xml"
  finish 1
}
finish() {
  echo "===== User journey on Android ====="
  printf "%s" "$results"
  # One annotation with every step, readable on the run's page.
  echo "::notice title=Android user journey::$(printf "%s" "$results" | sed ':a;N;$!ba;s/\n/%0A/g')"
  exit "$1"
}
# A system "Allow" (notifications) can pop up at any time; tap it like a user would.
allow_system_dialogs() {
  local point
  if point=$(find_on_screen "id=permission_allow_button"); then
    echo "Tapping the system's Allow button"
    adb shell input tap $point
    sleep 1
  fi
}
# Waits up to $2 seconds for something to show on screen.
wait_for() {
  local want=$1 seconds=${2:-30}
  for _ in $(seq 1 "$seconds"); do
    allow_system_dialogs
    find_on_screen "$want" > /dev/null && return 0
    sleep 1
  done
  return 1
}
tap() {
  local point
  point=$(find_on_screen "$1") || fail "Couldn't find \"$1\" to tap"
  adb shell input tap $point
}
attempts() { curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["attempts"]))'; }
authorized() { curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["authorized"]).lower())'; }
internet_works() { [[ "$(curl -s -o /dev/null -w '%{http_code}' "$PORTAL/generate_204")" == 204 ]]; }

read -r WIDTH HEIGHT < <(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | tr x ' ')
adb shell settings put global hide_error_dialogs 1
adb shell svc wifi enable
curl -s -X POST "$PORTAL/reset" > /dev/null
internet_works && fail "The mock campus should start signed out"

# 1. Install, as if from the APK download.
adb uninstall "$PACKAGE" > /dev/null 2>&1 || true
adb install "$APK" > /dev/null && pass "Install the app" || fail "Install the app"

# 2. Open it from the home screen.
adb shell input keyevent KEYCODE_HOME
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
  -n "$PACKAGE/.MainActivity" --es testProbeUrl "$PORTAL_FROM_EMULATOR/generate_204" > /dev/null
wait_for "Swipe up to start" 60 || fail "Welcome page shows when the app opens"
shot welcome
pass "Welcome page shows when the app opens"

# 3. Swipe up past the welcome page.
adb shell input swipe $((WIDTH / 2)) $((HEIGHT * 85 / 100)) $((WIDTH / 2)) $((HEIGHT * 15 / 100)) 250
wait_for "type=EditText#1" 20 || fail "Swiping up opens Settings to add the student ID"
shot settings
pass "Swiping up opens Settings to add the student ID"

# 4. Type the student ID and password, then Done.
tap "type=EditText#0"; sleep 1
adb shell input text 2201234
tap "type=EditText#1"; sleep 1
adb shell input text utar-test
sleep 1
find_on_screen "2201234" > /dev/null || fail "The student ID shows in its box after typing"
shot settings-filled
pass "Type the student ID and password"
tap "Done"
wait_for "Tap to Connect" 20 || fail "Done goes back to the main page with Tap to Connect"
shot ready
find_on_screen "2201234" > /dev/null || fail "The main page shows the saved student ID"
pass "Done saves and shows Tap to Connect with the student ID"

# 4b. Tap the ? and read the How to Use guide, step by step.
tap "Help"
wait_for "Step 1 of 6" 20 || fail "The ? button opens the How to Use guide"
find_on_screen "Done" > /dev/null || fail "The guide ticks off step 1 once the student ID is saved"
shot guide-step-1
for n in 2 3 4 5 6; do
  tap "Next"
  wait_for "Step $n of 6" 10 || fail "Next goes to step $n of the guide"
done
shot guide-step-6
tap "Got It"
wait_for "Tap to Connect" 20 || fail "Got It closes the guide and goes back to the main page"
pass "The ? guide opens, walks through all 6 steps and closes"

# 5. Tap the circle to connect.
tap "Tap to Connect"
for _ in $(seq 1 60); do
  allow_system_dialogs
  find_on_screen "Connected" > /dev/null && break
  find_on_screen "Couldn't Sign In" > /dev/null && fail "Tapping the circle signs in (it said Couldn't Sign In)"
  sleep 1
done
find_on_screen "Connected" > /dev/null || fail "Tapping the circle signs in"
shot connected
[[ $(authorized) == true ]] || fail "The login page accepted the student ID and password"
pass "Tapping the circle signs in: Connected"
internet_works && pass "The internet works after signing in" || fail "The internet works after signing in"

# 6. Leave the app and come back; pull down the notification shade and put it back.
before=$(attempts)
adb shell input keyevent KEYCODE_HOME; sleep 2
adb shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$PACKAGE/.MainActivity" > /dev/null
sleep 3
adb shell cmd statusbar expand-notifications; sleep 2
adb shell cmd statusbar collapse; sleep 3
shot back-in-app
find_on_screen "Connected" > /dev/null || fail "Still Connected after leaving the app and pulling down the shade"
[[ $(attempts) == "$before" ]] || fail "Coming back to the app doesn't sign in again"
pass "Coming back to the app stays Connected without signing in again"

# 7. Tap the green circle to disconnect.
tap "Tap to Disconnect"
wait_for "Signed Out" 30 || fail "Tapping the green circle signs out"
shot signed-out
[[ $(authorized) == false ]] || fail "The login page signed the student out"
pass "Tapping the green circle signs out"

# 8. And back in again.
tap "Tap to Connect"
wait_for "Connected" 60 || fail "Signing in again after signing out"
[[ $(authorized) == true ]] && internet_works || fail "The internet works after signing in again"
shot connected-again
pass "Signing in again works, and so does the internet"

finish 0
