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
summary=""
run_case() {
  local name=$1 password=$2 expect_result=$3 expect_authorized=$4
  shift 4 # Any further arguments are passed to the app as extras.
  echo "::group::$name"
  adb shell am force-stop "$PACKAGE"
  adb logcat -c
  adb shell am start -W -n "$PACKAGE/.MainActivity" \
    --es testProbeUrl "$PORTAL_FROM_EMULATOR/generate_204" \
    --es testStudentId 2201234 --es testPassword "$password" "$@"

  local result=""
  # Up to 2 minutes: the simulator or emulator can be very slow on a busy test machine.
  for _ in $(seq 1 120); do
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
    summary+="PASS  $name"$'\n'
  else
    echo "::error::FAIL: $name (expected '$expect_result' and authorized=$expect_authorized)"
    failures=$((failures + 1))
    summary+="FAIL  $name: $result"$'\n'
  fi
  echo "::endgroup::"
}

curl -s -X POST "$PORTAL/reset" > /dev/null
run_case wrong-password wrong-pass "Failed(" false
curl -s -X POST "$PORTAL/reset" > /dev/null
run_case sign-in utar-test "signed in" true
run_case already-online utar-test "already online" true
# Sign out with the link the app found after signing in.
run_case sign-out utar-test "SignedOut" false --es testAction signOut
# Another block: the campus sends the app to a login page at a different address.
curl -s -X POST "$PORTAL/reset" > /dev/null
curl -s -X POST "$PORTAL/move?to=B" > /dev/null
run_case other-building utar-test "signed in" true

# ---- A campus of buildings, each with its own login page address and style (scripts/mock_campus.py) ----
# The emulator reaches this computer at 10.0.2.2 and at the computer's own network addresses,
# so the buildings are spread over all of them.
IPS=($(hostname -I))
IP1=${IPS[0]:-10.0.2.2}
IP2=${IPS[1]:-$IP1}
CAMPUS_HOSTS="A=10.0.2.2,B=$IP1,C=$IP2,D=10.0.2.2,E=$IP1,AUTH=$IP2" \
  nohup python3 scripts/mock_campus.py 9000 > campus.log 2>&1 &
for _ in $(seq 1 30); do curl -s http://127.0.0.1:9000/status > /dev/null && break; sleep 1; done
head -1 campus.log
PORTAL=http://127.0.0.1:9000
PORTAL_FROM_EMULATOR=http://10.0.2.2:9000
curl -s -X POST "$PORTAL/reset" > /dev/null
# Walk from building to building: each one logs you out, so sign in again, then sign out.
for building in A B C D E; do
  curl -s -X POST "$PORTAL/move?to=$building" > /dev/null
  run_case "campus-$building" utar-test "signed in" true
  run_case "campus-$building-sign-out" utar-test "SignedOut" false --es testAction signOut
done

echo "===== Summary ($failures failed) ====="
printf "%s" "$summary"
exit $failures
