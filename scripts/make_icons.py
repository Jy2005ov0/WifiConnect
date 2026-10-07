#!/usr/bin/env python3
"""Draws the app icon options into design/icons/ plus a side-by-side preview.

Usage: make_icons.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent.parent / "design" / "icons"
SIZE = 1024
SS = 2  # Supersampling for smooth edges.
S = SIZE * SS


def wifi_mask(scale=1.0):
    """The Wi-Fi glyph (a dot and three rounded arcs with even gaps), like the iPhone status bar symbol."""
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    k = SS * scale
    stroke, dot, gap = 68 * k, 50 * k, 44 * k
    outer = [dot + gap + stroke + i * (gap + stroke) for i in range(3)]
    # Centre the glyph vertically: it spans from the top of the outer arc to the bottom of the dot.
    cx, cy = S / 2, S / 2 + (outer[-1] - dot) / 2
    start, end = 225, 315
    for r in outer:
        d.arc([cx - r, cy - r, cx + r, cy + r], start, end, fill=255, width=round(stroke))
        # Round caps, centred on the stroke (PIL draws the band inward from r).
        mid = r - stroke / 2
        for angle in (start, end):
            a = math.radians(angle)
            x, y = cx + mid * math.cos(a), cy + mid * math.sin(a)
            d.ellipse([x - stroke / 2, y - stroke / 2, x + stroke / 2, y + stroke / 2], fill=255)
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=255)
    return mask


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        img.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img.resize((S, S))


def diagonal_gradient(colors):
    """Top-left to bottom-right through the given colours."""
    small = 256
    img = Image.new("RGB", (small, small))
    px = img.load()
    stops = len(colors) - 1
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1)) * stops
            i = min(int(t), stops - 1)
            f = t - i
            a, b = colors[i], colors[i + 1]
            px[x, y] = tuple(int(a[c] + (b[c] - a[c]) * f) for c in range(3))
    return img.resize((S, S))


def solid(color):
    return Image.new("RGB", (S, S), color)


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def duo():
    """Black on one side, white on the other; the glyph flips colour where it crosses."""
    left = Image.new("L", (S, S), 0)
    ImageDraw.Draw(left).rectangle([0, 0, S // 2, S], fill=255)
    base = Image.composite(solid((0, 0, 0)), solid((255, 255, 255)), left)
    inverted = ImageChops.invert(base)
    return finish(Image.composite(inverted, base, wifi_mask()))


def duo_diagonal():
    split = Image.new("L", (S, S), 0)
    ImageDraw.Draw(split).polygon([(0, 0), (S, 0), (0, S)], fill=255)
    base = Image.composite(solid((0, 0, 0)), solid((255, 255, 255)), split)
    inverted = ImageChops.invert(base)
    return finish(Image.composite(inverted, base, wifi_mask()))


def glyph_on(background, color=(255, 255, 255), glow=None):
    img = background.copy()
    mask = wifi_mask()
    if glow:
        halo = mask.filter(ImageFilter.GaussianBlur(40 * SS))
        img = Image.composite(solid(glow), img, halo.point(lambda v: int(v * 0.55)))
    return finish(Image.composite(solid(color), img, mask))


ICONS = {
    "duo": ("Duo", duo),
    "duo-diagonal": ("Duo Diagonal", duo_diagonal),
    "midnight": ("Midnight", lambda: glyph_on(vertical_gradient((58, 58, 62), (0, 0, 0)))),
    "pearl": ("Pearl", lambda: glyph_on(vertical_gradient((255, 255, 255), (222, 222, 228)), color=(0, 0, 0))),
    "classic-blue": ("Classic Blue", lambda: glyph_on(vertical_gradient((64, 156, 255), (0, 102, 230)))),
    "aurora": ("Aurora", lambda: glyph_on(
        diagonal_gradient([(48, 35, 174), (10, 132, 255), (48, 209, 200)]), glow=(190, 230, 255))),
}


def rounded(icon, size):
    """Previews with the iOS app icon corner shape."""
    icon = icon.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * 0.2237), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask.resize((size, size), Image.LANCZOS))
    return out


def preview(icons):
    tile, gap, label_h = 300, 60, 70
    cols = 3
    rows = math.ceil(len(icons) / cols)
    sheet_w = cols * tile + (cols + 1) * gap
    sheet_h = rows * (tile + label_h) + (rows + 1) * gap
    sheets = []
    for name, bg, fg in (("light", (242, 242, 247), (0, 0, 0)), ("dark", (28, 28, 30), (255, 255, 255))):
        sheet = Image.new("RGB", (sheet_w, sheet_h), bg)
        d = ImageDraw.Draw(sheet)
        try:
            font = ImageFont.truetype("DejaVuSans-Bold.ttf", 30)
        except OSError:
            font = ImageFont.load_default()
        for i, (number, (title, img)) in enumerate(icons):
            r, c = divmod(i, cols)
            x = gap + c * (tile + gap)
            y = gap + r * (tile + label_h + gap)
            sheet.paste(rounded(img, tile), (x, y), rounded(img, tile))
            text = f"{number}. {title}"
            w = d.textlength(text, font=font)
            d.text((x + (tile - w) / 2, y + tile + 18), text, fill=fg, font=font)
        sheets.append(sheet)
    combined = Image.new("RGB", (sheet_w * 2, sheet_h))
    combined.paste(sheets[0], (0, 0))
    combined.paste(sheets[1], (sheet_w, 0))
    return combined


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    rendered = []
    for number, (key, (title, draw)) in enumerate(ICONS.items(), start=1):
        img = draw()
        img.save(OUT / f"{number}-{key}.png")
        rendered.append((number, (title, img)))
    preview(rendered).save(OUT / "preview.png")
    print("Wrote", OUT)
