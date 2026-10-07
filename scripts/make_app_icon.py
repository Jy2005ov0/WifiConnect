#!/usr/bin/env python3
"""Draws the WiFi Connect app icon ("Graphite"): a fan-style Wi-Fi symbol inside a
loading ring on a soft gradient, in a light and a dark version. The unfilled part of
the ring and the waiting dots are see-through, so the background shows through them.

Writes the iOS icon PNGs, the Android adaptive-icon vectors and a preview.
Usage: make_app_icon.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SIZE = 1024
SS = 2

# Geometry in a 1024 x 1024 design space (y points down, angles clockwise from 3 o'clock).
CENTER = (512, 512)
RING_RADIUS, RING_WIDTH = 330, 62
RING_MAIN = (136, 360)   # Over the top, from bottom-left round to 3 o'clock.
RING_REST = (0, 44)      # The unfilled part of the "loading" ring.
DOTS = [(118, "primary"), (99, "primary"), (80, "secondary"), (61, "tertiary")]
DOT_RADIUS = 33
FAN_APEX = (512, 660)
FAN_ANGLES = (225, 315)
FAN_BANDS = [(0, 96), (140, 232), (276, 366)]  # Tip, middle band, top band.
CORNER = 20

# Everything is drawn in the glyph colour; these opacities make the
# unfilled ring ("track") and the waiting dots see-through.
ROLES = {"primary": 1.0, "track": 0.28, "secondary": 0.5, "tertiary": 0.24}

THEMES = {
    "light": {"top": (255, 255, 255), "bottom": (229, 229, 234), "glyph": (0, 0, 0)},
    "dark": {"top": (44, 44, 46), "bottom": (0, 0, 0), "glyph": (255, 255, 255)},
}


def polar(center, radius, angle):
    a = math.radians(angle)
    return center[0] + radius * math.cos(a), center[1] + radius * math.sin(a)


def sector_points(inner, outer, steps=64):
    start, end = FAN_ANGLES
    outer_pts = [polar(FAN_APEX, outer, start + (end - start) * i / steps) for i in range(steps + 1)]
    if inner == 0:
        return outer_pts + [FAN_APEX]
    inner_pts = [polar(FAN_APEX, inner, end - (end - start) * i / steps) for i in range(steps + 1)]
    return outer_pts + inner_pts


def layer_masks():
    """One mask per colour role, at supersampled size."""
    s = SS
    masks = {role: Image.new("L", (SIZE * s, SIZE * s), 0) for role in ROLES}

    def scaled(points):
        return [(x * s, y * s) for x, y in points]

    # Wi-Fi fan, with softly rounded corners.
    fan = Image.new("L", (SIZE * s, SIZE * s), 0)
    d = ImageDraw.Draw(fan)
    for inner, outer in FAN_BANDS:
        d.polygon(scaled(sector_points(inner, outer)), fill=255)
    fan = fan.filter(ImageFilter.GaussianBlur(CORNER * s)).point(lambda v: 255 if v > 128 else 0)
    masks["primary"].paste(255, mask=fan)

    # Loading ring: butt ends where the two colours meet, round caps at the open ends.
    def ring(role, start, end, caps):
        d = ImageDraw.Draw(masks[role])
        r, w = RING_RADIUS * s, RING_WIDTH * s
        cx, cy = CENTER[0] * s, CENTER[1] * s
        box = [cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2]
        d.arc(box, start, end, fill=255, width=round(w))
        for angle in caps:
            x, y = polar((cx, cy), r, angle)
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)

    ring("primary", *RING_MAIN, caps=[RING_MAIN[0]])
    ring("track", *RING_REST, caps=[RING_REST[1]])

    for angle, role in DOTS:
        x, y = polar(CENTER, RING_RADIUS, angle)
        d = ImageDraw.Draw(masks[role])
        d.ellipse([(x - DOT_RADIUS) * s, (y - DOT_RADIUS) * s, (x + DOT_RADIUS) * s, (y + DOT_RADIUS) * s], fill=255)
    return masks


def gradient(top, bottom, size):
    column = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        column.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return column.resize((size, size))


def compose(base, color, masks):
    for role, mask in masks.items():
        base.paste(color, mask=mask.point(lambda v, a=ROLES[role]: int(v * a)))
    return base.resize((SIZE, SIZE), Image.LANCZOS)


def render(theme):
    t = THEMES[theme]
    return compose(gradient(t["top"], t["bottom"], SIZE * SS), t["glyph"], layer_masks())


def tinted():
    """iOS 18 tinted icons: a greyscale glyph on black that the system colours in."""
    return compose(Image.new("RGB", (SIZE * SS, SIZE * SS), (0, 0, 0)), (255, 255, 255), layer_masks())


# ---- Android vector drawables ----

def fmt(v):
    return f"{v:.2f}".rstrip("0").rstrip(".")


def sector_path(inner, outer):
    start, end = FAN_ANGLES
    ox1, oy1 = polar(FAN_APEX, outer, start)
    ox2, oy2 = polar(FAN_APEX, outer, end)
    path = f"M{fmt(ox1)},{fmt(oy1)} A{fmt(outer)},{fmt(outer)} 0 0,1 {fmt(ox2)},{fmt(oy2)} "
    if inner == 0:
        path += f"L{fmt(FAN_APEX[0])},{fmt(FAN_APEX[1])} Z"
    else:
        ix2, iy2 = polar(FAN_APEX, inner, end)
        ix1, iy1 = polar(FAN_APEX, inner, start)
        path += f"L{fmt(ix2)},{fmt(iy2)} A{fmt(inner)},{fmt(inner)} 0 0,0 {fmt(ix1)},{fmt(iy1)} Z"
    return path


def arc_path(start, end):
    x1, y1 = polar(CENTER, RING_RADIUS, start)
    x2, y2 = polar(CENTER, RING_RADIUS, end)
    large = 1 if (end - start) % 360 > 180 else 0
    r = fmt(RING_RADIUS)
    return f"M{fmt(x1)},{fmt(y1)} A{r},{r} 0 {large},1 {fmt(x2)},{fmt(y2)}"


def circle_path(x, y, r):
    return f"M{fmt(x - r)},{fmt(y)} a{fmt(r)},{fmt(r)} 0 1,0 {fmt(2 * r)},0 a{fmt(r)},{fmt(r)} 0 1,0 {fmt(-2 * r)},0 Z"


def vector(glyph, monochrome=False):
    """Adaptive-icon foreground: the design scaled into the 108dp icon's safe zone."""
    color = "#FFFFFFFF" if monochrome else "#FF%02X%02X%02X" % glyph

    def alpha(role):
        return fmt(ROLES[role])

    fan = " ".join(sector_path(i, o) for i, o in FAN_BANDS)
    caps = {
        "primary": [polar(CENTER, RING_RADIUS, RING_MAIN[0])],
        "track": [polar(CENTER, RING_RADIUS, RING_REST[1])],
    }
    dots = {role: [] for role in ROLES}
    for angle, role in DOTS:
        dots[role].append(polar(CENTER, RING_RADIUS, angle))

    paths = [
        f'        <path android:fillColor="{color}" android:strokeColor="{color}"\n'
        f'            android:strokeWidth="{CORNER}" android:strokeLineJoin="round"\n'
        f'            android:pathData="{fan}" />',
        f'        <path android:strokeColor="{color}" android:strokeWidth="{RING_WIDTH}"\n'
        f'            android:pathData="{arc_path(*RING_MAIN)}" />',
        f'        <path android:strokeColor="{color}" android:strokeAlpha="{alpha("track")}"\n'
        f'            android:strokeWidth="{RING_WIDTH}" android:pathData="{arc_path(*RING_REST)}" />',
    ]
    for role in ROLES:
        circles = [circle_path(x, y, RING_WIDTH / 2) for x, y in caps.get(role, [])]
        circles += [circle_path(x, y, DOT_RADIUS) for x, y in dots[role]]
        if circles:
            paths.append(
                f'        <path android:fillColor="{color}" android:fillAlpha="{alpha(role)}"\n'
                f'            android:pathData="{" ".join(circles)}" />'
            )

    scale = 0.62
    shift = SIZE * (1 - scale) / 2
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by scripts/make_app_icon.py -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="{SIZE}"
    android:viewportHeight="{SIZE}">
    <group
        android:scaleX="{scale}"
        android:scaleY="{scale}"
        android:translateX="{fmt(shift)}"
        android:translateY="{fmt(shift)}">
{chr(10).join(paths)}
    </group>
</vector>
"""


def background_shape(theme):
    """Adaptive-icon background: the same top-to-bottom gradient."""
    t = THEMES[theme]
    return f"""<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by scripts/make_app_icon.py -->
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient
        android:angle="270"
        android:startColor="#FF%02X%02X%02X"
        android:endColor="#FF%02X%02X%02X" />
</shape>
""" % (t["top"] + t["bottom"])


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


if __name__ == "__main__":
    ios = ROOT / "ios/WifiConnect/Assets.xcassets/AppIcon.appiconset"
    render("light").convert("RGB").save(ios / "AppIcon.png")
    render("dark").convert("RGB").save(ios / "AppIcon-Dark.png")
    tinted().save(ios / "AppIcon-Tinted.png")

    res = ROOT / "android/app/src/main/res"
    write(res / "drawable/ic_launcher_foreground.xml", vector(THEMES["light"]["glyph"]))
    write(res / "drawable-night/ic_launcher_foreground.xml", vector(THEMES["dark"]["glyph"]))
    write(res / "drawable/ic_launcher_monochrome.xml", vector(THEMES["light"]["glyph"], monochrome=True))
    write(res / "drawable/ic_launcher_background.xml", background_shape("light"))
    write(res / "drawable-night/ic_launcher_background.xml", background_shape("dark"))

    # Preview: dark and light side by side, like the reference.
    preview_dir = ROOT / "design"
    tile = 420
    sheet = Image.new("RGB", (tile * 2, tile), (0, 0, 0))
    sheet.paste(Image.new("RGB", (tile, tile), (255, 255, 255)), (tile, 0))
    for i, theme in enumerate(("dark", "light")):
        icon = render(theme).resize((300, 300), Image.LANCZOS)
        mask = Image.new("L", (1200, 1200), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, 1199, 1199], radius=268, fill=255)
        mask = mask.resize((300, 300), Image.LANCZOS)
        # A hairline so the icon's edge shows against the same-coloured background.
        edge = Image.new("RGB", (302, 302), (60, 60, 64) if theme == "dark" else (210, 210, 215))
        edge_mask = Image.new("L", (1208, 1208), 0)
        ImageDraw.Draw(edge_mask).rounded_rectangle([0, 0, 1207, 1207], radius=270, fill=255)
        sheet.paste(edge, (i * tile + 59, 59), edge_mask.resize((302, 302), Image.LANCZOS))
        sheet.paste(icon, (i * tile + 60, 60), mask)
    sheet.save(preview_dir / "app-icon-preview.png")
    print("Done")
