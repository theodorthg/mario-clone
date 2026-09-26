#!/usr/bin/env python3
"""App icons built from the game's own sprites (hero jumping at a ?-block).

    python3 tools/gen_icon.py [--preview]

Writes
  icon.png                         256x256  project icon (desktop, web favicon)
  assets/icon/android_main.png     192x192  legacy Android launcher icon
  assets/icon/android_fg.png       432x432  adaptive icon foreground
  assets/icon/android_bg.png       432x432  adaptive icon background
  assets/icon/android_mono.png     432x432  themed (monochrome) icon
Everything is scaled by integer factors (nearest neighbour) so the pixel art
stays crisp. Adaptive icons: Android shows only the central ~61 % circle of
the 432 px layers, so the foreground keeps hero + block inside it.
Run tools/gen_sprites.py + gen_tiles.py first (uses their sheets).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw  # noqa: E402
from pixelart import hex_rgba  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GFX = os.path.join(ROOT, "assets", "graphics")
OUT = os.path.join(ROOT, "assets", "icon")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")


def frame(sheet, cw, ch, i):
    im = Image.open(os.path.join(GFX, sheet)).convert("RGBA")
    f = im.crop((i * cw, 0, i * cw + cw, ch))
    return f.crop(f.getbbox())


HERO = frame("hero_big.png", 20, 32, 4)       # jump pose, fist up
QBLOCK = frame("blocks.png", 16, 16, 0)
COIN = frame("coin.png", 12, 16, 0)


def up(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def background(w, ground=0.8):
    """w x w logical pixels: banded sky, a cloud, far hill, grass ground"""
    img = Image.new("RGBA", (w, w))
    px = img.load()
    top, mid, hor = hex_rgba("#3b6bd6"), hex_rgba("#73acf0"), hex_rgba("#d8eefa")
    bands = 10
    for y in range(w):
        t = int(y / w * bands) / bands
        a, b, u = (top, mid, t / 0.55) if t < 0.55 else (mid, hor, (t - 0.55) / 0.45)
        c = tuple(int(a[i] + (b[i] - a[i]) * min(u, 1.0)) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    d = ImageDraw.Draw(img)
    # cloud
    cx, cy, s = int(w * 0.22), int(w * 0.24), max(2, w // 16)
    for ox, oy, r in [(0, 0, s * 1.3), (s * 1.4, -s * 0.4, s * 1.6), (s * 3, 0, s * 1.2)]:
        d.ellipse((cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r), fill=hex_rgba("#ffffff"))
    d.rectangle((cx - s, cy, cx + s * 3, cy + s), fill=hex_rgba("#ffffff"))
    # far hill
    import math
    for x in range(w):
        hy = int(w * 0.66 - math.sin(x / w * math.pi * 1.3 + 0.4) * w * 0.12)
        for y in range(hy, w):
            px[x, y] = hex_rgba("#86cf86") if y > hy else hex_rgba("#5a9e66")
    # ground: grass cap + dirt
    g0 = int(w * ground)
    for x in range(w):
        for y in range(g0, w):
            dy = y - g0
            col = "#6fd33c" if dy < 2 else ("#43a82e" if dy < 3 else ("#1b4d18" if dy < 4 else "#b8763f"))
            if dy >= 4 and (x * 3 + y * 7) % 11 == 0:
                col = "#834a22"
            px[x, y] = hex_rgba(col)
        if (x // 2) % 3 == 0:
            px[x, g0 - 1] = hex_rgba("#6fd33c")
    return img


def scene_fg(size, k_hero, k_block, gap, dy=0):
    """hero jumping at a ?-block, stacked and centred on a transparent canvas"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hero, blk, coin = up(HERO, k_hero), up(QBLOCK, k_block), up(COIN, k_block)
    total = blk.height + gap + hero.height
    y0 = (size - total) // 2 + dy
    img.alpha_composite(blk, ((size - blk.width) // 2, y0))
    img.alpha_composite(coin, ((size - blk.width) // 2 + blk.width - coin.width // 3, y0 - coin.height // 2))
    img.alpha_composite(hero, ((size - hero.width) // 2, y0 + blk.height + gap))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    bg432 = up(background(72, 0.76), 6)
    fg432 = scene_fg(432, 5, 4, 8, -12)
    bg432.save(os.path.join(OUT, "android_bg.png"))
    fg432.save(os.path.join(OUT, "android_fg.png"))
    mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    white = Image.new("RGBA", (432, 432), (255, 255, 255, 255))
    mono.paste(white, (0, 0), fg432.split()[3])
    mono.save(os.path.join(OUT, "android_mono.png"))
    main192 = up(background(32), 6)
    main192.alpha_composite(scene_fg(192, 3, 3, 6))
    main192.save(os.path.join(OUT, "android_main.png"))
    icon256 = up(background(32), 8)
    icon256.alpha_composite(scene_fg(256, 4, 4, 8))
    icon256.save(os.path.join(ROOT, "icon.png"))
    if PREVIEW:
        comp = bg432.copy()
        comp.alpha_composite(fg432)
        mask = Image.new("L", (432, 432), 0)
        r = 432 * 0.305
        ImageDraw.Draw(mask).ellipse((216 - r, 216 - r, 216 + r, 216 + r), fill=255)
        circ = Image.new("RGBA", (432, 432), (40, 40, 40, 255))
        circ.paste(comp, (0, 0), mask)
        sheet = Image.new("RGBA", (432 * 2 + 256 + 192 + 40, 432), (40, 40, 40, 255))
        sheet.paste(comp, (0, 0))
        sheet.paste(circ, (442, 0))
        sheet.paste(icon256, (884, 0))
        sheet.paste(main192, (884 + 266, 0))
        sheet.save(os.path.join(PREVIEW_DIR, "prev_icon.png"))
    print("  icon.png + assets/icon/android_{main,fg,bg,mono}.png")


if __name__ == "__main__":
    main()
