#!/usr/bin/env python3
"""UI bitmaps: on-screen touch buttons (+ pressed variants), splash screen,
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
    else:
        f = ImageFont.truetype(FONT, 16)
        w = d.textlength(symbol, font=f)
        for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            d.text((c - w / 2 + ox, c - 8 + oy), symbol, font=f, fill=edge)
        d.text((c - w / 2, c - 8), symbol, font=f, fill=ink)
    return img


def splash():
    """1280x720 splash: sky, hills, title, hero + dragon (reuses the art)."""
    W, H = 480, 270
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = img.load()
    top, hor = (59, 107, 214), (216, 238, 250)
    for y in range(H):
        t = min(1.0, y / (H * 0.8))
        t = round(t * 16) / 16
        col = tuple(int(top[i] + (hor[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(W):
            px[x, y] = col
    for name, y in (("bg_mountains", 60), ("bg_clouds", 10), ("bg_hills_far", 130), ("bg_hills_near", 158),
                    ("bg_trees", 176)):
        layer = Image.open(os.path.join(GFX, name + ".png")).convert("RGBA")
        img.alpha_composite(layer.crop((0, 0, W, layer.size[1])), (0, y))
    tiles = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    for x in range(0, W, 16):
        img.alpha_composite(tiles.crop((0, 0, 16, 16)) if False else tiles.crop((1 * 16, 0, 2 * 16, 16)), (x, 238))
        img.alpha_composite(tiles.crop((0, 16, 16, 32)), (x, 254))
    # full-width ground: use the "only up-open" variant (mask 1)
    for x in range(0, W, 16):
        img.alpha_composite(tiles.crop((16, 0, 32, 16)), (x, 238))
    hero = Image.open(os.path.join(GFX, "hero_big.png")).convert("RGBA").crop((0, 0, 20, 32))
    dino = Image.open(os.path.join(GFX, "dino.png")).convert("RGBA").crop((0, 0, 28, 32))
    shroom = Image.open(os.path.join(GFX, "enemy_shroom.png")).convert("RGBA").crop((0, 0, 18, 17))
    img.alpha_composite(dino, (300, 238 - 32))
    img.alpha_composite(hero, (180, 238 - 32))
    img.alpha_composite(shroom.transpose(Image.FLIP_LEFT_RIGHT), (380, 238 - 17))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 32)
    f2 = ImageFont.truetype(FONT, 8)
    title = "MARIO CLONE"
    w = d.textlength(title, font=f)
    x0, y0 = (W - w) / 2, 70
    for ox in range(-3, 4):
        for oy in range(-3, 4):
            d.text((x0 + ox, y0 + oy), title, font=f, fill=(194, 111, 16, 255))
    d.text((x0 + 3, y0 + 3), title, font=f, fill=(26, 16, 24, 255))
    d.text((x0, y0), title, font=f, fill=(255, 255, 255, 255))
    sub = "A PIXEL PLATFORM ADVENTURE"
    w2 = d.textlength(sub, font=f2)
    d.text(((W - w2) / 2 + 1, 116), sub, font=f2, fill=(26, 16, 24, 255))
    d.text(((W - w2) / 2, 115), sub, font=f2, fill=(255, 216, 60, 255))
    big = img.resize((W * 4, H * 4), Image.NEAREST).convert("RGB")
    big.save(os.path.join(ROOT, "splash-screen.png"))


def main():
    os.makedirs(UI, exist_ok=True)
    for sym, name in (("left", "left"), ("right", "right"), ("A", "a"), ("B", "b")):
        button(sym, False).save(os.path.join(UI, "touch_%s.png" % name))
        button(sym, True).save(os.path.join(UI, "touch_%s_pressed.png" % name))
    splash()
    print("  touch buttons, splash-screen.png")


if __name__ == "__main__":
    main()
