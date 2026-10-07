#!/usr/bin/env bash
# Usage: ios-screenshots.sh path/to/WifiConnect.app
set -euo pipefail

APP="$1"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")
OUT=new-screenshots
mkdir -p "$OUT"

# Prefer an iPhone 16 Pro, otherwise the first available iPhone.
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = [d for runtime, ds in json.load(sys.stdin)["devices"].items() if "iOS" in runtime for d in ds]
phones = [d for d in devices if d["name"].startswith("iPhone")]
best = next((d for d in phones if d["name"] == "iPhone 16 Pro"), phones[-1])
print(best["udid"])
')

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 --dataNetwork wifi
xcrun simctl install "$UDID" "$APP"

shoot() {
  local name=$1; shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoStudentID A0123456X "$@"
  sleep 5
  xcrun simctl io "$UDID" screenshot "$OUT/ios-$name.png"
}

shoot 0-welcome   -demoState idle -demoScreen welcome
shoot 1-ready     -demoState idle
shoot 2-connected -demoState connected -demoSpeed "18 ms · 92 Mbps"
shoot 3-settings  -demoState idle -demoScreen settings
shoot 4-guide     -demoState idle -demoScreen guide
shoot 6-history   -demoState idle -demoScreen history
shoot 7-share     -demoState idle -demoScreen share
shoot 8-speedtest -demoState connected -demoScreen speed
shoot 9-japanese  -demoState connected -demoSpeed "18 ms · 92 Mbps" -AppleLanguages "(ja)"
shoot 10-tamil    -demoState connected -demoSpeed "18 ms · 92 Mbps" -AppleLanguages "(ta)"
shoot 11-malay    -demoState connected -demoSpeed "18 ms · 92 Mbps" -AppleLanguages "(ms)"
shoot 12-chinese  -demoState connected -demoSpeed "18 ms · 92 Mbps" -AppleLanguages "(zh-Hans)"

# The "Connected to utarwifi" notification, on the Home Screen. applesimutils allows
# notifications without the permission prompt; the app schedules one, then goes away.
if command -v applesimutils > /dev/null; then
  applesimutils --byId "$UDID" --bundle "$BUNDLE_ID" --setPermissions notifications=YES || true
  sleep 3
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoStudentID A0123456X -demoState connected -demoNotify YES
  sleep 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID"
  sleep 1
  # The banner slides in and stays a few seconds. Take pictures quickly and keep the one
  # where the banner reaches furthest down (the most changed rows at the top of the screen).
  shots=$(mktemp -d)
  xcrun simctl io "$UDID" screenshot "$shots/home.png"
  for i in $(seq 1 24); do
    xcrun simctl io "$UDID" screenshot "$shots/shot-$i.png" > /dev/null 2>&1
  done
  python3 -m pip install --quiet pillow > /dev/null 2>&1 || true
  python3 - "$shots" "$OUT/ios-13-notification.png" <<'PY'
import os, shutil, sys
from PIL import Image, ImageChops
folder, out = sys.argv[1], sys.argv[2]
home = Image.open(os.path.join(folder, "home.png")).convert("RGB")
top = (0, 0, home.width, home.height // 4)
def banner_depth(name):
    diff = ImageChops.difference(Image.open(os.path.join(folder, name)).convert("RGB"), home).crop(top)
    box = diff.point(lambda v: 255 if v > 40 else 0).getbbox()
    return box[3] if box else 0
best = max((f for f in os.listdir(folder) if f.startswith("shot-")), key=banner_depth)
shutil.copy(os.path.join(folder, best), out)
print("Notification picture:", best, banner_depth(best))
PY
  sleep 6
fi
xcrun simctl ui "$UDID" appearance dark
shoot 5-dark      -demoState connected -demoSpeed "18 ms · 92 Mbps"
