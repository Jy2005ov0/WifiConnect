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
xcrun simctl install "$UDID" "$APP"
PREFS="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)/Library/Preferences/$BUNDLE_ID.plist"

failures=0
run_case() {
  local name=$1 password=$2 expect_result=$3 expect_authorized=$4
  echo "::group::$name"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -testRun "$name" \
    -testProbeURL "$PORTAL/hotspot-detect.html" -testStudentID 2201234 -testPassword "$password"

  local result=""
  for _ in $(seq 1 60); do
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
  else
    echo "::error::FAIL: $name (expected '$expect_result' and authorized=$expect_authorized)"
    failures=$((failures + 1))
  fi
  echo "::endgroup::"
}

curl -s -X POST "$PORTAL/reset" > /dev/null
run_case wrong-password wrong-pass 'failed(' false
curl -s -X POST "$PORTAL/reset" > /dev/null
run_case sign-in utar-test "signed in" true
run_case already-online utar-test "already online" true

exit $failures
