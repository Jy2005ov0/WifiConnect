#!/usr/bin/env bash
# A first-time user, step by step, by tapping and typing on the screen like a person:
# install the app, swipe past the welcome page, type the student ID and password,
# tap the circle, check the internet works, leave and come back, then sign out.
# The only test hook: the app checks for the login page at the mock portal
# (scripts/mock_portal.py on port 8080) instead of Apple's address.
# Needs idb (https://fbidb.io) to tap and type, and applesimutils to answer the
# notifications question the way a user tapping Allow would.
# Usage: ios-journey.sh path/to/WifiConnect.app
set -euo pipefail

APP="$1"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
PORTAL=http://127.0.0.1:8080
OUT=journey
mkdir -p "$OUT"
HERE=$(cd "$(dirname "$0")" && pwd)

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
phones = [d for d in devices if d["name"].startswith("iPhone")]
print(next((d for d in phones if d["name"] == "iPhone 16 Pro"), phones[-1])["udid"])
')
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b > /dev/null
if ! idb connect "$UDID" > /tmp/idb-connect.log 2>&1; then
  echo "::error::idb couldn't connect to the simulator: $(tail -5 /tmp/idb-connect.log | tr '\n' ' ')"
  exit 1
fi

step=0
results=""
shot() { step=$((step + 1)); xcrun simctl io "$UDID" screenshot "$OUT/ios-$(printf %02d $step)-$1.png" > /dev/null 2>&1; }
screen() { idb ui describe-all --udid "$UDID" --json 2>/dev/null || true; }
find_on_screen() { screen | python3 "$HERE/ui_find.py" ios "$1"; }
pass() { echo "PASS: $1"; results+="PASS  $1"$'\n'; }
fail() {
  echo "::error::FAIL: $1"
  results+="FAIL  $1"$'\n'
  shot failed
  screen > "$OUT/ios-failed-screen.json"
  # What was on screen, readable on the run's page.
  echo "::error title=On screen when it failed::$(python3 -c '
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except ValueError:
    data = []
print(" | ".join(str(e.get("AXLabel")) + " (" + str(e.get("type")) + ")" for e in data if e.get("AXLabel") or e.get("type") in ("TextField", "SecureTextField", "Button"))[:900])
' "$OUT/ios-failed-screen.json")"
  finish 1
}
finish() {
  echo "===== User journey on iPhone ====="
  printf "%s" "$results"
  echo "::notice title=iPhone user journey::$(printf "%s" "$results" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/%0A/g')"
  exit "$1"
}
wait_for() {
  local want=$1 seconds=${2:-30}
  for _ in $(seq 1 "$seconds"); do
    find_on_screen "$want" > /dev/null && return 0
    sleep 1
  done
  return 1
}
tap() {
  local point
  point=$(find_on_screen "$1") || fail "Couldn't find \"$1\" to tap"
  idb ui tap --udid "$UDID" $point
}
type_text() { idb ui text --udid "$UDID" "$1"; }
attempts() { curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["attempts"]))'; }
authorized() { curl -s "$PORTAL/status" | python3 -c 'import json,sys; print(str(json.load(sys.stdin)["authorized"]).lower())'; }
internet_works() { [[ "$(curl -s -o /dev/null -w '%{http_code}' "$PORTAL/hotspot-detect.html")" == 200 ]] &&
  curl -s "$PORTAL/hotspot-detect.html" | grep -q Success; }

curl -s -X POST "$PORTAL/reset" > /dev/null
internet_works && fail "The mock campus should start signed out"

# 1. Install, as if from the download.
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP" && pass "Install the app" || fail "Install the app"
# The user taps Allow when asked about notifications.
applesimutils --byId "$UDID" --bundle "$BUNDLE_ID" --setPermissions notifications=YES > /dev/null 2>&1 || true

# 2. Open it from the Home Screen.
xcrun simctl launch "$UDID" "$BUNDLE_ID" -testProbeURL "$PORTAL/hotspot-detect.html" > /dev/null
wait_for "Swipe up to start" 60 || fail "Welcome page shows when the app opens"
shot welcome
pass "Welcome page shows when the app opens"

# 3. Swipe up past the welcome page.
read -r X Y < <(find_on_screen "Swipe up to start")
idb ui swipe --udid "$UDID" --duration 0.3 "$X" "$Y" "$X" 120
wait_for "type=TextField" 20 || fail "Swiping up opens Settings to add the student ID"
shot settings
pass "Swiping up opens Settings to add the student ID"

# 4. Type the student ID and password, then Done.
tap "type=TextField#0"; sleep 1
type_text 2201234
point=$(find_on_screen "type=SecureTextField") || point=$(find_on_screen "Password") ||
  fail "Couldn't find the password box"
idb ui tap --udid "$UDID" $point; sleep 1
type_text utar-test
sleep 1
shot settings-filled
pass "Type the student ID and password"
tap "Done"
wait_for "Tap to Connect" 20 || fail "Done goes back to the main page with Tap to Connect"
shot ready
find_on_screen "2201234" > /dev/null || fail "The main page shows the saved student ID"
pass "Done saves and shows Tap to Connect with the student ID"

# 5. Tap the circle to connect.
tap "Tap to Connect"
for _ in $(seq 1 60); do
  find_on_screen "Connected" > /dev/null && break
  find_on_screen "Couldn" > /dev/null && fail "Tapping the circle signs in (it said Couldn't Sign In)"
  sleep 1
done
find_on_screen "Connected" > /dev/null || fail "Tapping the circle signs in"
shot connected
[[ $(authorized) == true ]] || fail "The login page accepted the student ID and password"
pass "Tapping the circle signs in: Connected"
internet_works && pass "The internet works after signing in" || fail "The internet works after signing in"

# 6. Leave the app and come back; pull down Notification Center and put it back.
before=$(attempts)
idb ui button --udid "$UDID" HOME; sleep 2
xcrun simctl launch "$UDID" "$BUNDLE_ID" > /dev/null; sleep 3
idb ui swipe --udid "$UDID" --duration 0.3 60 2 60 600; sleep 2
idb ui swipe --udid "$UDID" --duration 0.3 200 820 200 100; sleep 3
xcrun simctl launch "$UDID" "$BUNDLE_ID" > /dev/null; sleep 3
shot back-in-app
find_on_screen "Connected" > /dev/null || fail "Still Connected after leaving the app and pulling down Notification Center"
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
