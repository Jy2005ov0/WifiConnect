#!/usr/bin/env bash
# End-to-end test: runs the iPhone app in the simulator against scripts/mock_portal.py.
# Usage: ios-e2e.sh path/to/WifiConnect.app   (with the mock portal running on port 8080)
set -euo pipefail

APP="$1"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
PORTAL=http://127.0.0.1:8080
OUT=e2e
mkdir -p "$OUT"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
phones = [d for d in devices if d["name"].startswith("iPhone")]
print(next((d for d in phones if d["name"] == "iPhone 16 Pro"), phones[-1])["udid"])
')
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
# The simulator occasionally isn't ready right after booting; retry the install.
for attempt in 1 2 3; do
  xcrun simctl install "$UDID" "$APP" && break
  echo "Install attempt $attempt failed; retrying."
  [[ $attempt == 3 ]] && { echo "Couldn't install the app."; exit 1; }
  sleep 15
done
PREFS="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)/Library/Preferences/$BUNDLE_ID.plist"

failures=0
summary=""
run_case() {
  local name=$1 password=$2 expect_result=$3 expect_authorized=$4
  shift 4 # Any further arguments are passed to the app, e.g. settings.
  echo "::group::$name"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -testRun "$name" \
    -testProbeURL "$PORTAL/hotspot-detect.html" -testStudentID 2201234 -testPassword "$password" "$@"

  local result=""
  # Up to 2 minutes: the simulator or emulator can be very slow on a busy test machine.
  for _ in $(seq 1 120); do
    result=$(plutil -extract testResult raw "$PREFS" 2>/dev/null || true)
    [[ "$result" == "$name: "* ]] && break
    sleep 1
  done
  sleep 2
  xcrun simctl io "$UDID" screenshot "$OUT/ios-$name.png"

  local authorized
  authorized=$(curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["authorized"]).lower())')
  echo "App result: $result"
  echo "Portal authorized: $authorized"
  curl -s "$PORTAL/status"; echo
  if [[ "$result" == "$name: "*"$expect_result"* && "$authorized" == "$expect_authorized" ]]; then
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
run_case wrong-password wrong-pass 'failed(' false
curl -s -X POST "$PORTAL/reset" > /dev/null
run_case sign-in utar-test "signed in" true
run_case already-online utar-test "already online" true
# Sign out with the link the app found after signing in.
run_case sign-out utar-test "signedOut" false -testAction signOut
# Another block: the campus sends the app to a login page at a different address.
curl -s -X POST "$PORTAL/reset" > /dev/null
curl -s -X POST "$PORTAL/move?to=B" > /dev/null
run_case other-building utar-test "signed in" true
# Manual settings with just a path, which should work in any building.
curl -s -X POST "$PORTAL/reset" > /dev/null
curl -s -X POST "$PORTAL/move?to=B" > /dev/null
run_case manual-path utar-test "signed in" true \
  -useCustomPortal YES -loginURL /cgi-bin/login -method POST \
  -usernameField username -passwordField password -extraFields agree=yes

# ---- A campus of buildings, each with its own login page address and style (scripts/mock_campus.py) ----
# Give the Mac extra loopback addresses, so every building really is at a different IP.
for i in 2 3 4 5 6 7; do sudo ifconfig lo0 alias "127.0.0.$i" up; done
CAMPUS_HOSTS="A=127.0.0.2,B=127.0.0.3,C=127.0.0.4,D=127.0.0.5,E=127.0.0.6,AUTH=127.0.0.7" \
  nohup python3 -u scripts/mock_campus.py 18000 > campus.log 2>&1 &
for _ in $(seq 1 60); do curl -s http://127.0.0.1:18000/status > /dev/null && break; sleep 1; done
curl -sf http://127.0.0.1:18000/status > /dev/null || { echo "::error::The mock campus didn't start:"; cat campus.log; exit 1; }
PORTAL=http://127.0.0.1:18000
curl -s -X POST "$PORTAL/reset" > /dev/null
# Walk from building to building: each one logs you out, so sign in again, then sign out.
for building in A B C D E; do
  curl -s -X POST "$PORTAL/move?to=$building" > /dev/null
  run_case "campus-$building" utar-test "signed in" true
  run_case "campus-$building-sign-out" utar-test "signedOut" false -testAction signOut
done

echo "===== Summary ($failures failed) ====="
printf "%s" "$summary"
exit $failures
