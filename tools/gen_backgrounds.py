#!/usr/bin/env python3
"""Parallax background layers (seamlessly tileable horizontally).

    python3 tools/gen_backgrounds.py [--preview]

Every layer is BG_W px wide and wraps: all shape functions use periods that
divide BG_W exactly, so x=0 and x=BG_W meet without a seam. The sky itself is
a shader (assets/ui/sky.gdshader), not a texture, so it fills any aspect.

Writes assets/graphics/bg_*.png
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from pixelart import hex_rgba, preview, TRANSPARENT  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "graphics")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")
BG_W = 640

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither(x, y, t):
    """True if the pixel should take the 'next' color at blend t (0..1)."""
    return t * 16 > BAYER4[y % 4][x % 4] + 0.5


def periodic(x, terms):
    """sum of sines, each term (amplitude, integer cycles per BG_W, phase)"""
    return sum(a * math.sin(2 * math.pi * (k * x / BG_W) + p) for a, k, p in terms)


def mountains():
    h = 150
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    base = hex_rgba("#8c9ad6")
    shade = hex_rgba("#6f7cc0")
    deep = hex_rgba("#5c68ac")
    snow = hex_rgba("#f4f7ff")
    snow_sh = hex_rgba("#c6d0f0")
    haze = hex_rgba("#b6c8ee")
    rng = random.Random(7)
    terms = [(34, 2, 0.4), (22, 5, 1.3), (12, 9, 2.2), (6, 17, 0.7), (3, 31, 1.9)]
    tops = []
    for x in range(BG_W):
        v = periodic(x, terms)
        tops.append(int(78 - v))
    for x in range(BG_W):
        top = max(4, tops[x])
        slope = tops[(x + 1) % BG_W] - tops[x - 1]
        for y in range(top, h):
            depth = y - top
            col = base if slope >= 0 else shade
            if slope < -2 and depth < 30:
                col = deep if depth % 7 < 2 else shade
            # snow cap: above a jagged snow line near peaks
            snow_line = 44 + int(periodic(x, [(4, 13, 0.3), (2, 29, 1.1)]))
            if y < snow_line and depth < 18 + (x * 7 % 5):
                col = snow if slope >= 0 else snow_sh
            # haze toward the bottom
            t = max(0.0, (y - 95) / 55.0)
            if t > 0 and dither(x, y, t):
                col = haze
            px[x, y] = col
        # outline pixel on the silhouette
        if top - 1 >= 0:
            px[x, top - 1] = hex_rgba("#5a66a8") if slope >= 0 else hex_rgba("#4d5898")
    return img


def cloud_blob(img, cx, cy, r_list, rng):
    px = img.load()
    w, h = img.size
    white = hex_rgba("#ffffff")
    sh1 = hex_rgba("#e3eefc")
    sh2 = hex_rgba("#c2d6f2")
    edge = hex_rgba("#9fbbe6")
    mask = set()
    for (dx, dy, r) in r_list:
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y <= r * r + r * 0.6:
                    mask.add(((cx + dx + x) % w, cy + dy + y))
    bottom = max(y for _, y in mask)
    for (x, y) in mask:
        if 0 <= y < h:
            t = (y - (cy - 6)) / max(1, bottom - (cy - 6))
            col = white
            if t > 0.55:
                col = sh1
            if t > 0.8:
                col = sh2
            px[x, y] = col
    for (x, y) in mask:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= ny < h and (nx % w, ny) not in mask:
                px[nx % w, ny] = edge


def clouds():
    h = 110
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    rng = random.Random(3)
    specs = [
        (40, 30, [(0, 0, 10), (12, -5, 12), (26, 0, 9), (-10, 3, 7), (36, 4, 6)]),
        (210, 62, [(0, 0, 7), (9, -4, 9), (19, 0, 7), (-7, 2, 5)]),
        (330, 22, [(0, 0, 12), (15, -6, 14), (32, -1, 11), (46, 4, 7), (-12, 4, 8)]),
        (505, 58, [(0, 0, 8), (11, -5, 10), (23, 0, 8), (32, 3, 5)]),
        (590, 18, [(0, 0, 6), (8, -3, 7), (16, 1, 5)]),
    ]
    for cx, cy, blobs in specs:
        cloud_blob(img, cx, cy, blobs, rng)
    return img


def hills(h, colors, terms, base_y, pattern=True, seed=1):
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    light, mid, dark, line = [hex_rgba(c) for c in colors]
    rng = random.Random(seed)
    tops = [int(base_y - periodic(x, terms)) for x in range(BG_W)]
    for x in range(BG_W):
        top = max(1, tops[x])
        slope = tops[(x + 1) % BG_W] - tops[x - 1]
        for y in range(top, h):
            d = y - top
            col = mid
            if d < 2:
                col = light
            elif slope > 1 and d < 10:
                col = dark
            if pattern and d > 6 and (x * 3 + y * 5) % 23 == 0:
                col = dark
            px[x, y] = col
        px[x, top - 1] = line
    return img


def trees():
    h = 100
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    crown = hex_rgba("#2f7a3a")
    crown_l = hex_rgba("#4a9a48")
    crown_d = hex_rgba("#1f5a2c")
    line = hex_rgba("#153f22")
    trunk = hex_rgba("#4a3020")
    rng = random.Random(11)
    mask = {}
    x = 0
    while x < BG_W:
        r = rng.randint(11, 18)
        cy = 50 + rng.randint(-8, 12)
        for yy in range(-r, r + 1):
            for xx in range(-r, r + 1):
                if xx * xx + yy * yy <= r * r:
                    X = (x + xx) % BG_W
                    Y = cy + yy
                    if 0 <= Y < h:
                        d = (xx + r * 0.4) ** 2 + (yy + r * 0.5) ** 2
                        v = 2 if d < (r * 0.55) ** 2 else (0 if yy > r * 0.35 else 1)
                        mask[(X, Y)] = max(mask.get((X, Y), -1), v)
        # trunk
        for yy in range(cy + r - 2, h):
            for xx in range(-1, 2):
                mask.setdefault(((x + xx) % BG_W, yy), -2)
        x += int(r * 1.3) + rng.randint(0, 6)
    # solid undergrowth band at the bottom
    for X in range(BG_W):
        for Y in range(76 + int(periodic(X, [(3, 16, 0.2), (2, 40, 1.0)])), h):
            mask[(X, Y)] = max(mask.get((X, Y), -1), 0)
    for (X, Y), v in mask.items():
        px[X, Y] = {2: crown_l, 1: crown, 0: crown_d, -2: trunk}[v]
    for (X, Y) in list(mask.keys()):
        if Y - 1 >= 0 and (X, Y - 1) not in mask:
            px[X, Y - 1] = line
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    layers = {
        "bg_mountains": mountains(),
        "bg_clouds": clouds(),
        "bg_hills_far": hills(120, ["#a8e6a0", "#86cf86", "#6fb676", "#5a9e66"],
                              [(16, 3, 0.2), (10, 7, 1.7), (5, 13, 0.9)], 48, seed=2),
        "bg_hills_near": hills(110, ["#8ee070", "#5cbc4a", "#46a03c", "#2e7a30"],
                               [(20, 2, 1.1), (12, 5, 0.3), (6, 11, 2.4)], 50, seed=5),
        "bg_trees": trees(),
    }
    for name, im in layers.items():
        im.save(os.path.join(OUT, name + ".png"))
    if PREVIEW:
        # stacked composite on a gradient sky to judge the mood
        H = 300
        comp = Image.new("RGBA", (BG_W, H))
        p = comp.load()
        top, mid, hor = hex_rgba("#3d6fd6"), hex_rgba("#74aef0"), hex_rgba("#d4ecfa")
        for y in range(H):
            t = y / H
            for x in range(BG_W):
                a, b, tt = (top, mid, t / 0.55) if t < 0.55 else (mid, hor, (t - 0.55) / 0.45)
                c = b if dither(x, y, tt) else a
                p[x, y] = c
        comp.alpha_composite(layers["bg_mountains"], (0, 70))
        comp.alpha_composite(layers["bg_clouds"], (0, 20))
        comp.alpha_composite(layers["bg_hills_far"], (0, 150))
        comp.alpha_composite(layers["bg_hills_near"], (0, 180))
        comp.alpha_composite(layers["bg_trees"], (0, 200))
        preview(comp, 2, path=os.path.join(PREVIEW_DIR, "prev_bg.png"))
    print("  " + ", ".join(layers))


if __name__ == "__main__":
    main()
