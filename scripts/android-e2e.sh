#!/usr/bin/env bash
# End-to-end test: runs the Android app in the emulator against scripts/mock_portal.py.
# Usage: android-e2e.sh path/to/app-debug.apk   (with an emulator and the mock portal on port 8080)
set -euo pipefail

APK="$1"
PACKAGE=com.wificonnect.app
PORTAL=http://127.0.0.1:8080
# The emulator reaches the host computer at 10.0.2.2.
PORTAL_FROM_EMULATOR=http://10.0.2.2:8080
OUT=e2e
mkdir -p "$OUT"

adb install -r "$APK"
adb shell settings put global hide_error_dialogs 1
adb shell svc wifi enable
sleep 30
adb shell input keyevent KEYCODE_HOME

failures=0
run_case() {
  local name=$1 password=$2 expect_result=$3 expect_authorized=$4
  echo "::group::$name"
  adb shell am force-stop "$PACKAGE"
  adb logcat -c
  adb shell am start -W -n "$PACKAGE/.MainActivity" \
    --es testProbeUrl "$PORTAL_FROM_EMULATOR/generate_204" \
    --es testStudentId 2201234 --es testPassword "$password"

  local result=""
  for _ in $(seq 1 60); do
    result=$(adb logcat -d -s WifiConnect:I | grep "Result:" | tail -1 || true)
    [[ -n "$result" ]] && break
    sleep 1
  done
  sleep 2
  adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS > /dev/null || true
  adb exec-out screencap -p > "$OUT/android-$name.png"

  local authorized
  authorized=$(curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["authorized"]).lower())')
  echo "App result: $result"
  echo "Portal authorized: $authorized"
  curl -s "$PORTAL/status"; echo
  if [[ "$result" == *"$expect_result"* && "$authorized" == "$expect_authorized" ]]; then
    echo "PASS: $name"
  else
    echo "::error::FAIL: $name (expected '$expect_result' and authorized=$expect_authorized)"
    failures=$((failures + 1))
  fi
  echo "::endgroup::"
}

curl -s -X POST "$PORTAL/reset" > /dev/null
run_case wrong-password wrong-pass "Failed(" false
curl -s -X POST "$PORTAL/reset" > /dev/null
run_case sign-in utar-test "signed in" true
run_case already-online utar-test "already online" true
# Another block: the campus sends the app to a login page at a different address.
curl -s -X POST "$PORTAL/reset" > /dev/null
curl -s -X POST "$PORTAL/move?to=B" > /dev/null
run_case other-building utar-test "signed in" true

exit $failures
