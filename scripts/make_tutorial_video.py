"""Builds docs/WiFi-Connect-Tutorial.mp4 from the screenshots in screenshots/.

Usage: python make_video.py <repo dir> <output.mp4>
Draws every frame with Pillow and pipes them to ffmpeg (H.264, 1920x1080, 30 fps).
"""
import math
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO, OUT = sys.argv[1], sys.argv[2]
W, H, FPS = 1920, 1080, 30
SHOTS = f"{REPO}/screenshots"
BOLD = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
SEMI = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
REG = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"
font = lambda path, size: ImageFont.truetype(path, size)

NAVY = (11, 27, 51)
BLUE = (0, 122, 255)
GREEN = (52, 199, 89)
GREY_BG = (242, 242, 247)
INK = (28, 28, 30)
MUTED = (99, 99, 102)


def ease(t):  # smooth 0→1
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


_phone_cache = {}


def phone(name, height):
    """A screenshot in a dark rounded frame with a soft shadow."""
    key = (name, height)
    if key in _phone_cache:
        return _phone_cache[key]
    shot = Image.open(f"{SHOTS}/{name}.png").convert("RGB")
    w = round(shot.width * height / shot.height)
    shot = shot.resize((w, height), Image.LANCZOS)
    pad = max(8, height // 70)
    radius = height // 16
    frame = Image.new("RGBA", (w + 2 * pad, height + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius=radius + pad, fill=(22, 22, 24, 255))
    mask = Image.new("L", (w, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, height - 1], radius=radius, fill=255)
    frame.paste(shot, (pad, pad), mask)
    shadow = Image.new("RGBA", (frame.width + 80, frame.height + 80), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([40, 50, 40 + frame.width, 50 + frame.height], radius=radius + pad, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    shadow.alpha_composite(frame, (40, 40))
    _phone_cache[key] = (shadow, 40 + pad, 40 + pad, w, height)
    return _phone_cache[key]


def paste_phone(img, name, cx, top, height, alpha=1.0, dy=0):
    sprite, ox, oy, w, h = phone(name, height)
    if alpha < 1:
        sprite = sprite.copy()
        sprite.putalpha(sprite.getchannel("A").point(lambda a: int(a * alpha)))
    x = int(cx - sprite.width / 2)
    img.alpha_composite(sprite, (x, int(top + dy - 40)))
    # Where the screen sits, for drawing on top of it.
    return x + ox, int(top + dy - 40) + oy, w, h


def wrap(draw, text, fnt, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        test = (line + " " + word).strip()
        if draw.textlength(test, font=fnt) <= width:
            line = test
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def text_block(img, x, y, step, title, body, t, dark=False, width=760):
    """Step label, title and body, fading and sliding in."""
    d = ImageDraw.Draw(img)
    a = ease(t / 0.5)
    off = int((1 - a) * 30)
    fg = (255, 255, 255) if dark else INK
    sub = (201, 211, 227) if dark else MUTED
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    yy = y + off
    if step:
        ld.text((x, yy), step, font=font(SEMI, 30), fill=BLUE + (int(255 * a),))
        yy += 52
    for line in wrap(ld, title, font(BOLD, 64), width):
        ld.text((x, yy), line, font=font(BOLD, 64), fill=fg + (int(255 * a),))
        yy += 78
    yy += 14
    for line in wrap(ld, body, font(REG, 34), width):
        ld.text((x, yy), line, font=font(REG, 34), fill=sub + (int(255 * a),))
        yy += 48
    img.alpha_composite(layer)


def tap_ring(img, cx, cy, t, color=BLUE):
    """An expanding ring where a finger taps."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k in range(2):
        p = (t * 1.2 + k * 0.5) % 1.0
        r = 18 + p * 70
        a = int(200 * (1 - p))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color + (a,), width=6)
    d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(255, 255, 255, 170), outline=color + (230,), width=4)
    img.alpha_composite(layer)


def card(img, box, fill=(255, 255, 255), radius=36):
    ImageDraw.Draw(img).rounded_rectangle(box, radius=radius, fill=fill)


def background(dark=False):
    return Image.new("RGBA", (W, H), NAVY + (255,) if dark else GREY_BG + (255,))


# ---- Scenes: (seconds, draw(t_seconds) -> Image) ----

def s_title(t):
    img = background(dark=True)
    text_block(img, 140, 330, "UTAR CAMPUS WI-FI", "WiFi Connect", "Sign in to utarwifi with one tap, on iPhone, iPad, Android and your Windows laptop.", t, dark=True, width=820)
    a = ease((t - 0.3) / 0.8)
    paste_phone(img, "ios-0-welcome", 1270, 170, 760, a, (1 - a) * 80)
    paste_phone(img, "ios-2-connected", 1560, 130, 820, ease((t - 0.6) / 0.8), (1 - ease((t - 0.6) / 0.8)) * 80)
    return img


def s_download(t):
    img = background()
    text_block(img, 140, 280, "STEP 1", "Download the app", "Open the Latest build release on GitHub. No account needed. Pick the file for your device.", t)
    a = ease((t - 0.4) / 0.6)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    card(layer, [1060, 300, 1780, 780])
    d = ImageDraw.Draw(layer)
    d.text((1110, 345), "Latest build", font=font(BOLD, 44), fill=INK)
    d.text((1110, 405), "github.com/Jy2005ov0/WifiConnect/releases", font=font(REG, 24), fill=MUTED)
    rows = [("WifiConnect.apk", "Android", GREEN), ("WifiConnect.ipa", "iPhone and iPad", BLUE)]
    for i, (name, who, color) in enumerate(rows):
        y = 490 + i * 130
        d.rounded_rectangle([1110, y, 1730, y + 100], radius=22, fill=GREY_BG)
        d.ellipse([1135, y + 25, 1185, y + 75], fill=color)
        d.text((1150, y + 30), "↓", font=font(BOLD, 34), fill=(255, 255, 255))
        d.text((1210, y + 16), name, font=font(SEMI, 34), fill=INK)
        d.text((1210, y + 58), who, font=font(REG, 26), fill=MUTED)
    layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
    img.alpha_composite(layer)
    return img


def s_install(t):
    img = background()
    text_block(img, 140, 120, "STEP 2", "Install it", "", t, width=1600)
    cols = [
        ("Android", GREEN, ["Open WifiConnect.apk", "Allow Install unknown apps", "Battery: set to Unrestricted"]),
        ("iPhone / iPad", BLUE, ["No Mac needed: use a Windows PC", "Sideloadly or AltStore", "Sign in with your Apple ID", "Renew every 7 days (free ID)"]),
        ("Windows laptop", NAVY, ["Double-click Install.cmd", "Type your ID and password", "Signs in by itself after that"]),
    ]
    for i, (name, color, lines) in enumerate(cols):
        a = ease((t - 0.3 - i * 0.25) / 0.6)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        x = 140 + i * 560
        card(layer, [x, 330, x + 520, 820])
        d = ImageDraw.Draw(layer)
        d.ellipse([x + 40, 370, x + 120, 450], fill=color)
        d.text((x + 40, 480), name, font=font(BOLD, 44), fill=INK)
        for j, line in enumerate(lines):
            d.ellipse([x + 44, 575 + j * 70, x + 56, 587 + j * 70], fill=color)
            for k, part in enumerate(wrap(d, line, font(REG, 30), 400)):
                d.text((x + 76, 560 + j * 70 + k * 36), part, font=font(REG, 30), fill=MUTED)
        layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
        img.alpha_composite(layer, (0, int((1 - a) * 40)))
    return img


def s_welcome(t):
    img = background()
    text_block(img, 140, 330, "STEP 3", "Open it and swipe up", "The welcome page shows the time. Swipe up to start. You can turn it off later in Settings.", t)
    # The page slides up from 2.2 s, showing Settings underneath.
    up = ease((t - 2.2) / 0.9)
    x, y, w, h = paste_phone(img, "ios-3-settings", 1360, 110, 860)
    sprite, ox, oy, sw, sh = phone("ios-0-welcome", 860)
    screen = Image.open(f"{SHOTS}/ios-0-welcome.png").convert("RGBA").resize((w, h))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, int(-up * h), w - 1, int(h - 1 - up * h)], radius=h // 16, fill=255)
    shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shifted.paste(screen, (0, int(-up * h)))
    img.paste(shifted, (x, y), mask)
    if t < 2.4:
        fy = y + h * (0.86 - 0.5 * ease((t - 1.0) / 1.2))
        tap_ring(img, x + w // 2, int(fy), t)
    return img


def s_settings(t):
    img = background()
    text_block(img, 140, 330, "STEP 4", "Add your student ID", "Type your student ID and password, then tap Done. They're saved encrypted, only on your phone.", t)
    x, y, w, h = paste_phone(img, "ios-3-settings", 1360, 110, 860, ease(t / 0.5))
    if 1.0 < t:
        tap_ring(img, x + int(w * 0.28), y + int(h * 0.22), t)
    return img


def s_join(t):
    img = background()
    text_block(img, 140, 330, "STEP 5", "Join utarwifi", "In your phone's Wi-Fi settings, join the campus Wi-Fi. If a login page pops up, you can close it.", t)
    a = ease((t - 0.3) / 0.6)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    card(layer, [1080, 340, 1760, 740])
    d = ImageDraw.Draw(layer)
    d.text((1130, 385), "Wi-Fi", font=font(BOLD, 48), fill=INK)
    d.rounded_rectangle([1130, 470, 1710, 560], radius=20, fill=GREY_BG)
    d.text((1170, 492), "utarwifi", font=font(SEMI, 38), fill=INK)
    d.text((1610, 488), "✓", font=font(BOLD, 42), fill=BLUE)
    d.rounded_rectangle([1130, 580, 1710, 670], radius=20, fill=GREY_BG)
    d.text((1170, 602), "Other networks…", font=font(REG, 34), fill=MUTED)
    layer.putalpha(layer.getchannel("A").point(lambda v: int(v * a)))
    img.alpha_composite(layer)
    return img


def s_tap(t):
    img = background()
    text_block(img, 140, 330, "STEP 6", "Tap the blue circle", "The app finds this building's login page, fills in your details and signs you in.", t)
    name = "ios-1-ready" if t < 2.6 else "ios-2-connected"
    x, y, w, h = paste_phone(img, name, 1360, 110, 860)
    if 0.8 < t < 2.6:
        tap_ring(img, x + w // 2, y + int(h * 0.37), t)
    return img


def s_connected(t):
    img = background()
    text_block(img, 140, 330, "STEP 7", "Green means you're online", "Tap the green circle when you want to sign out. Every building works: the app finds each one's login page.", t)
    paste_phone(img, "ios-2-connected", 1360, 110, 860)
    return img


def s_auto(t):
    img = background()
    text_block(img, 140, 280, "STEP 8", "Make it automatic", "Android signs in by itself when you join utarwifi. On iPhone and iPad, tap Auto Sign-In and set up the Shortcuts automation once.", t)
    paste_phone(img, "ios-4-guide", 1180, 110, 860, ease(t / 0.5))
    paste_phone(img, "android-13-notification", 1600, 150, 780, ease((t - 0.4) / 0.5))
    return img


def s_help(t):
    img = background()
    text_block(img, 140, 330, "NEED HELP?", "Tap the ?", "The step-by-step guide walks you through everything, with buttons that take you to the right place.", t)
    x, y, w, h = paste_phone(img, "ios-1-ready", 1180, 110, 860, ease(t / 0.4))
    if 0.6 < t < 2.0:
        tap_ring(img, x + int(w * 0.055), y + int(h * 0.075), t)
    paste_phone(img, "ios-15-howto", 1600, 150, 780, ease((t - 1.6) / 0.5))
    return img


def s_extras(t):
    img = background()
    text_block(img, 140, 100, "MORE", "Speed test, history and five languages", "", t, width=1640)
    names = ["ios-8-speedtest", "ios-6-history", "ios-11-malay", "ios-12-chinese", "ios-10-tamil"]
    for i, name in enumerate(names):
        a = ease((t - 0.3 - i * 0.15) / 0.5)
        paste_phone(img, name, 300 + i * 330, 330, 620, a, (1 - a) * 60)
    return img


def s_outro(t):
    img = background(dark=True)
    text_block(img, 140, 300, "GET STARTED", "Ready in one tap", "", t, dark=True, width=900)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, line in enumerate(["1.  Download from the Latest build release", "2.  Add your student ID and password", "3.  Join utarwifi and tap the circle"]):
        a = ease((t - 0.4 - i * 0.3) / 0.5)
        d.text((140, 480 + i * 64), line, font=font(REG, 38), fill=(201, 211, 227, int(255 * a)))
    a = ease((t - 1.6) / 0.5)
    d.text((140, 720), "github.com/Jy2005ov0/WifiConnect", font=font(SEMI, 32), fill=BLUE + (int(255 * a),))
    img.alpha_composite(layer)
    paste_phone(img, "android-2-connected", 1250, 150, 780, ease((t - 0.3) / 0.6))
    paste_phone(img, "ios-2-connected", 1590, 120, 840, ease((t - 0.5) / 0.6))
    return img


SCENES = [(5, s_title), (6, s_download), (8, s_install), (5, s_welcome), (5, s_settings), (5, s_join),
          (5, s_tap), (5, s_connected), (7, s_auto), (6, s_help), (6, s_extras), (6, s_outro)]
FADE = 0.4  # seconds of cross-fade between scenes

ffmpeg = subprocess.Popen(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
     "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT],
    stdin=subprocess.PIPE)
total = 0
for index, (seconds, draw) in enumerate(SCENES):
    frames = int(seconds * FPS)
    for f in range(frames):
        t = f / FPS
        frame = draw(t)
        # Cross-fade into the next scene over its last FADE seconds.
        if index + 1 < len(SCENES) and t > seconds - FADE:
            nxt = SCENES[index + 1][1](0)
            frame = Image.blend(frame, nxt, ease((t - (seconds - FADE)) / FADE))
        ffmpeg.stdin.write(frame.convert("RGB").tobytes())
        total += 1
ffmpeg.stdin.close()
ffmpeg.wait()
print(f"{total} frames, {total / FPS:.0f} s ->", OUT)
