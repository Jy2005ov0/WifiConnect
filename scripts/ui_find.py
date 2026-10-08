"""Finds something on screen for the user-journey tests and prints the point to tap ("x y").

Usage: ui_find.py android|ios WHAT < screen-dump
  WHAT is the words shown (or read out by the screen reader), e.g. "Tap to Connect",
  "type=EditText#1" for the second text box, or "id=permission_allow_button".
  "right:WORDS" gives the right end of that row instead, where a switch sits.
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
    root = ET.fromstring(dump[start:dump.rfind(">") + 1])
    nodes = list(root.iter("node"))
    parents = {child: parent for parent in root.iter() for child in parent}
    right = want.startswith("right:")
    want = want.removeprefix("right:")

    def bounds(node):
        return list(map(int, re.findall(r"\d+", node.get("bounds", "")))) or [0, 0, 0, 0]

    def center(node):
        x1, y1, x2, y2 = bounds(node)
        if right:
            # Up to the whole row, then just inside its right end.
            screen = bounds(nodes[0])[2]
            row = node
            while row in parents and bounds(row)[2] - bounds(row)[0] < screen * 0.8:
                row = parents[row]
            return bounds(row)[2] - 110, (y1 + y2) // 2
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

    right = want.startswith("right:")
    want = want.removeprefix("right:")

    def center(element):
        frame = element["frame"]
        x = frame["x"] + frame["width"] - 40 if right else frame["x"] + frame["width"] / 2
        return round(x), round(frame["y"] + frame["height"] / 2)

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
