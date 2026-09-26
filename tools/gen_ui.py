#!/usr/bin/env python3
"""UI bitmaps: on-screen touch buttons (+ pressed variants),
HUD life icon.

    python3 tools/gen_ui.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "assets", "ui")
GFX = os.path.join(ROOT, "assets", "graphics")
FONT = os.path.join(UI, "pixel_font.ttf")
S = 40  # button texture size (design px)


def button(symbol, pressed):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fill = (255, 216, 60, 150) if pressed else (255, 255, 255, 70)
    d.ellipse((1, 1, S - 2, S - 2), fill=fill, outline=(26, 16, 24, 170), width=2)
    d.ellipse((3, 3, S - 4, S - 4), outline=(255, 255, 255, 110 if not pressed else 200), width=1)
    ink = (255, 255, 255, 235)
    edge = (26, 16, 24, 220)
    c = S // 2
    if symbol in ("left", "right"):
        s = -1 if symbol == "left" else 1
        pts = [(c + s * 9, c), (c - s * 6, c - 9), (c - s * 6, c + 9)]
        d.polygon(pts, fill=ink, outline=edge)
    elif symbol == "down":
        pts = [(c, c + 9), (c - 9, c - 6), (c + 9, c - 6)]
        d.polygon(pts, fill=ink, outline=edge)
    else:
        f = ImageFont.truetype(FONT, 16)
        w = d.textlength(symbol, font=f)
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            d.text((c - w / 2 + ox, c - 8 + oy), symbol, font=f, fill=edge)
        d.text((c - w / 2, c - 8), symbol, font=f, fill=ink)
    return img


def main():
    os.makedirs(UI, exist_ok=True)
    for sym, name in (("left", "left"), ("right", "right"), ("down", "down"), ("A", "a"), ("X", "b")):
        button(sym, False).save(os.path.join(UI, "touch_%s.png" % name))
        button(sym, True).save(os.path.join(UI, "touch_%s_pressed.png" % name))
    # splash-screen.png is the user's artwork (art_src/mario-clone-splashscreen.jpeg,
    # converted to PNG 1920x1080) — NOT generated here any more.
    print("  touch buttons")


if __name__ == "__main__":
    main()
