"""Finds something on screen for the user-journey tests and prints the point to tap ("x y").

Usage: ui_find.py android|ios WHAT < screen-dump
  WHAT is the words shown (or read out by the screen reader), e.g. "Tap to Connect",
  "type=EditText#1" for the second text box, or "id=permission_allow_button".
  Android reads `uiautomator dump`; iOS reads `idb ui describe-all --json`.
Prints nothing (and exits 1) when it isn't on screen.
"""
import json
import re
import sys


def android(dump, want):
    import xml.etree.ElementTree as ET
    start = dump.find("<?xml")
    if start < 0:
        return None
    nodes = list(ET.fromstring(dump[start:dump.rfind(">") + 1]).iter("node"))

    def center(node):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds", "")))
        return (x1 + x2) // 2, (y1 + y2) // 2

    if want.startswith("type="):
        kind, _, index = want[5:].partition("#")
        matches = [n for n in nodes if n.get("class", "").endswith(kind)]
        index = int(index or 0)
        return center(matches[index]) if len(matches) > index else None
    if want.startswith("id="):
        matches = [n for n in nodes if n.get("resource-id", "").endswith(want[3:])]
        return center(matches[0]) if matches else None
    # What the screen reader says first (the circle button), then the words shown.
    for key in ("content-desc", "text"):
        for node in nodes:
            if node.get(key) == want:
                return center(node)
    return None


def ios(dump, want):
    try:
        elements = json.loads(dump)
    except ValueError:
        # Older idb prints one JSON object per line.
        elements = [json.loads(line) for line in dump.splitlines() if line.strip().startswith("{")]

    def center(element):
        frame = element["frame"]
        return round(frame["x"] + frame["width"] / 2), round(frame["y"] + frame["height"] / 2)

    if want.startswith("type="):
        kind, _, index = want[5:].partition("#")
        matches = [e for e in elements if e.get("type") == kind]
        index = int(index or 0)
        return center(matches[index]) if len(matches) > index else None
    for exact in (True, False):
        for element in elements:
            label = element.get("AXLabel") or ""
            value = element.get("AXValue") or ""
            if (want in (label, value)) if exact else (want in label):
                return center(element)
    return None


if __name__ == "__main__":
    platform, want = sys.argv[1], sys.argv[2]
    point = (android if platform == "android" else ios)(sys.stdin.read(), want)
    if not point:
        sys.exit(1)
    print(*point)
