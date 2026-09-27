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


# ------------------------------------------------------------------ desert --
def pyramids():
    h = 110
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    lit, shade, line, course = (hex_rgba(c) for c in ("#f4cc80", "#c8904a", "#8a5c2c", "#dcaa62"))
    for cx, hh in [(70, 46), (190, 88), (262, 58), (420, 70), (560, 40)]:
        for y in range(h - hh, h):
            half = y - (h - hh)
            for dx in range(-half, half + 1):
                X = (cx + dx) % BG_W
                col = lit if dx < 0 else shade
                if (y - (h - hh)) % 6 == 5 and dx < 0:
                    col = course
                if abs(dx) == half:
                    col = line
                px[X, y] = col
        px[cx % BG_W, h - hh - 1] = line
    return img


def cacti_band():
    """near dune strip with saguaro silhouettes standing on it"""
    img = hills(96, ["#f0c070", "#d8a052", "#c08840", "#9a6a30"],
                [(9, 2, 0.6), (5, 5, 1.9), (3, 10, 0.4)], 56, pattern=True, seed=9)
    px = img.load()
    dark, lite = hex_rgba("#4a6a2c"), hex_rgba("#6a8a3a")
    rng = random.Random(21)
    x = 20
    while x < BG_W - 10:
        top = 56 - int(periodic(x, [(9, 2, 0.6), (5, 5, 1.9), (3, 10, 0.4)]))
        hh = rng.randint(16, 30)
        for y in range(top - hh, top + 2):
            for dx in range(-2, 2):
                px[(x + dx) % BG_W, y] = lite if dx < 0 else dark
        for side, ay, ah in [(-1, top - hh + 8, 8), (1, top - hh + 5, 9)]:
            ax = x + side * 5
            for y in range(ay, ay + ah):
                for dx in range(-1, 1):
                    px[(ax + dx) % BG_W, y] = dark
            for dx in range(min(ax, x), max(ax, x)):
                px[dx % BG_W, ay + ah - 1] = dark
                px[dx % BG_W, ay + ah - 2] = dark
        x += rng.randint(55, 110)
    return img


# -------------------------------------------------------------------- snow --
def pines(h, seed, size, colors, base_y, band=True):
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    body, dark, snow, snow_sh, line = (hex_rgba(c) for c in colors)
    rng = random.Random(seed)
    mask = {}
    x = 0
    while x < BG_W:
        th = rng.randint(*size)
        foot = base_y + rng.randint(-4, 4)
        for y in range(foot - th, foot):
            d = y - (foot - th)
            half = int(d * 0.42) + 1 - (2 if d % 7 == 0 and d > 6 else 0)
            for dx in range(-half, half + 1):
                v = 2 if (d % 7 < 2 or dx < -half + 2) else (1 if dx < 0 else 0)
                mask[((x + dx) % BG_W, y)] = v
        x += rng.randint(th // 3, th // 2 + 4)
    if band:
        for X in range(BG_W):
            for Y in range(base_y + int(periodic(X, [(3, 8, 0.3), (2, 20, 1.2)])), h):
                mask[(X, Y)] = 3
    for (X, Y), v in mask.items():
        px[X, Y] = {0: dark, 1: body, 2: snow, 3: snow_sh}[v]
    for (X, Y) in list(mask.keys()):
        if Y - 1 >= 0 and (X, Y - 1) not in mask:
            px[X, Y - 1] = line
    return img


# -------------------------------------------------------------------- cave --
def cave_far():
    """ceiling with stalactites on top, columns, floor bumps — full height"""
    h = 270
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    rock, rock_l, rock_d, line = (hex_rgba(c) for c in ("#232a52", "#2f3868", "#1a1f3e", "#12162e"))
    rng = random.Random(5)
    ceil = [int(22 + periodic(x, [(6, 4, 0.2), (3, 11, 1.4)])) for x in range(BG_W)]
    floor_ = [int(230 - periodic(x, [(8, 3, 1.0), (4, 13, 0.3)])) for x in range(BG_W)]
    fill = {}
    for x in range(BG_W):
        for y in range(0, ceil[x]):
            fill[(x, y)] = 1
        for y in range(floor_[x], h):
            fill[(x, y)] = 1
    # stalactites
    x = 4
    while x < BG_W:
        ln, w = rng.randint(14, 46), rng.randint(3, 7)
        for y in range(ceil[x % BG_W] - 2, ceil[x % BG_W] + ln):
            half = max(0, int(w * (1 - (y - ceil[x % BG_W]) / ln)))
            for dx in range(-half, half + 1):
                fill[((x + dx) % BG_W, y)] = 2 if dx < 0 else 1
        x += rng.randint(12, 34)
    # columns
    for cx in (110, 350, 520):
        for y in range(0, h):
            wv = 9 + int(3 * math.sin(y / 17.0))
            for dx in range(-wv, wv + 1):
                fill[((cx + dx) % BG_W, y)] = 2 if dx < -wv + 4 else (3 if dx > wv - 3 else 1)
    for (X, Y), v in fill.items():
        px[X, Y] = {1: rock, 2: rock_l, 3: rock_d}[v]
    for (X, Y) in list(fill.keys()):
        for nx, ny in ((X, Y - 1), (X, Y + 1)):
            if 0 <= ny < h and (nx, ny) not in fill:
                px[nx, ny] = line
    return img


def cave_crystals():
    img = hills(120, ["#3a4478", "#2c3462", "#222850", "#161a36"],
                [(14, 3, 0.9), (7, 7, 0.2), (4, 17, 1.6)], 60, pattern=True, seed=13)
    px = img.load()
    rng = random.Random(17)
    cols = [("#d8fcff", "#5ce0f0", "#2a8ab8"), ("#f4d8ff", "#b474f4", "#6a38b0")]
    x = 12
    while x < BG_W:
        top = 60 - int(periodic(x, [(14, 3, 0.9), (7, 7, 0.2), (4, 17, 1.6)]))
        lt, md, dk = (hex_rgba(c) for c in rng.choice(cols))
        hh, w = rng.randint(7, 16), rng.randint(3, 5)
        for y in range(top - hh, top + 2):
            d = y - (top - hh)
            half = min(w, d // 2 + 1)
            for dx in range(-half, half + 1):
                px[(x + dx) % BG_W, y] = lt if dx < -half + 2 else (md if dx < 1 else dk)
        # soft glow dots around the crystal
        for _ in range(6):
            gx, gy = x + rng.randint(-10, 10), top - hh + rng.randint(-8, 10)
            if 0 <= gy < 120 and px[gx % BG_W, gy][3] == 0:
                px[gx % BG_W, gy] = (md[0], md[1], md[2], 150)
        x += rng.randint(26, 64)
    return img


def cave_near():
    h = 90
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    body, lite, line = hex_rgba("#141a34"), hex_rgba("#1f264a"), hex_rgba("#0a0d1e")
    rng = random.Random(3)
    fill = {}
    for X in range(BG_W):
        for Y in range(70 + int(periodic(X, [(4, 5, 0.1), (2, 16, 0.8)])), h):
            fill[(X, Y)] = 0
    x = 8
    while x < BG_W:
        hh, w = rng.randint(20, 58), rng.randint(5, 10)
        for y in range(h - 20 - hh, h):
            d = y - (h - 20 - hh)
            half = min(w, int(d * w / max(hh * 0.8, 1)) + 1)
            for dx in range(-half, half + 1):
                fill[((x + dx) % BG_W, y)] = 1 if dx < -half + 2 else 0
        x += rng.randint(30, 80)
    for (X, Y), v in fill.items():
        px[X, Y] = lite if v else body
    for (X, Y) in list(fill.keys()):
        if Y - 1 >= 0 and (X, Y - 1) not in fill:
            px[X, Y - 1] = line
    return img


# ------------------------------------------------------------------ castle --
def castle_wall():
    """dark brick wall, full height, with tall arched windows (transparent ->
    the red night sky of the sky shader shows through)"""
    h = 270
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    brick, brick_d, mortar = hex_rgba("#2c2838"), hex_rgba("#24202e"), hex_rgba("#16131e")
    for y in range(h):
        for x in range(BG_W):
            row = y // 8
            off = 8 if row % 2 else 0
            if y % 8 == 7 or (x + off) % 16 == 15:
                px[x, y] = mortar
            else:
                px[x, y] = brick if (x // 16 + row) % 3 else brick_d
    frame = hex_rgba("#3e3850")
    for cx in range(40, BG_W, 160):
        top, bot, hw = 46, 150, 14
        for y in range(top - 18, bot + 3):
            for x in range(cx - hw - 3, cx + hw + 4):
                dx = x - cx
                if y < top:
                    inside = dx * dx + (y - top) ** 2 <= hw * hw
                    rim = dx * dx + (y - top) ** 2 <= (hw + 3) ** 2
                else:
                    inside = abs(dx) <= hw and y <= bot
                    rim = abs(dx) <= hw + 3
                if inside:
                    px[x % BG_W, y] = TRANSPARENT
                elif rim:
                    px[x % BG_W, y] = frame
        for x in range(cx - hw, cx + hw + 1):      # window bars
            if (x - cx) % 7 == 0:
                for y in range(top - 12, bot):
                    if px[x % BG_W, y][3] == 0:
                        px[x % BG_W, y] = hex_rgba("#1a1622")
    return img


def castle_pillars():
    h = 200
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    col, col_l, col_d, line = (hex_rgba(c) for c in ("#3a3448", "#524a64", "#26202e", "#120e18"))
    red, red_d, gold = hex_rgba("#8a1e2c"), hex_rgba("#5a121c"), hex_rgba("#c8a030")
    for cx in range(60, BG_W, 128):
        for y in range(h):
            for dx in range(-11, 12):
                x = (cx + dx) % BG_W
                c = col_l if dx < -6 else (col_d if dx > 6 else col)
                if abs(dx) == 11:
                    c = line
                if y < 10 or y > h - 12:     # capital + base
                    c = col_l if y % 5 else line
                px[x, y] = c
        # hanging banner between pillars
        bx = cx + 64
        for y in range(14, 90):
            for dx in range(-9, 10):
                x = (bx + dx) % BG_W
                if y > 80 and abs(dx) < (y - 80):
                    continue
                c = red if abs(dx) < 8 else red_d
                if abs(dx) == 9:
                    c = line
                if 30 < y < 50 and abs(dx) < 4:
                    c = gold
                px[x, y] = c
    return img


def cloud_sea(h, base_y, puffs, colors, edge, seed):
    """continuous band of cloud tops (seamless): the silhouette is the upper
    envelope of round puffs along a baseline, filled down to the bottom,
    shaded darker with depth. colors: [top, body, deep]"""
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    rng = random.Random(seed)
    specs = []
    x = 0
    while x < BG_W:
        r = rng.randint(*puffs)
        specs.append((x, r))
        x += int(r * rng.uniform(1.1, 1.6))
    tops = []
    for xx in range(BG_W):
        t = base_y
        for cx, r in specs:
            for off in (-BG_W, 0, BG_W):
                d = xx - (cx + off)
                if abs(d) < r:
                    t = min(t, base_y - int((r * r - d * d) ** 0.5 * 0.8))
        tops.append(t)
    c_top, c_body, c_deep = (hex_rgba(c) for c in colors)
    for xx in range(BG_W):
        for y in range(max(0, tops[xx]), h):
            depth = y - tops[xx]
            col = c_top if depth < 3 else c_body
            t = max(0.0, (y - base_y - 6) / 26.0)
            if t > 0 and dither(xx, y, min(1.0, t)):
                col = c_deep
            px[xx, y] = col
        if tops[xx] - 1 >= 0:
            px[xx, tops[xx] - 1] = hex_rgba(edge)
    return img


def sky_islands():
    """distant floating islands: grassy top, rock body tapering down,
    blossom trees, one little waterfall (hazy blue = far away)"""
    h = 120
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    grass, grass_d = hex_rgba("#a8dca0"), hex_rgba("#84bf86")
    rock, rock_d, rock_dd = hex_rgba("#b4b8e0"), hex_rgba("#9296c8"), hex_rgba("#7a7eb4")
    edge = hex_rgba("#6a70a8")
    tree, tree_d = hex_rgba("#f4c4e0"), hex_rgba("#d8a0c8")
    fall = hex_rgba("#e6f4ff")
    rng = random.Random(11)
    for cx, top, w, depth, trees, water in ((95, 46, 64, 44, 2, False), (320, 30, 90, 62, 3, True),
                                             (520, 60, 48, 34, 1, False)):
        x0 = cx - w // 2
        for x in range(x0, x0 + w):
            k = (x - x0) / (w - 1)
            bottom = top + 4 + int(depth * (1 - abs(k - 0.5) * 2) ** 0.7) + rng.randint(0, 2)
            for y in range(top, min(h, bottom)):
                if y < top + 3:
                    col = grass if y == top else grass_d
                else:
                    col = rock if k < 0.45 else rock_d
                    if (x * 3 + y * 5) % 11 == 0:
                        col = rock_dd
                px[x % BG_W, y] = col
            px[x % BG_W, top - 1] = edge
            if bottom < h:
                px[x % BG_W, bottom] = edge
        for i in range(trees):
            tx = x0 + 8 + i * (w - 16) // max(1, trees - 1) if trees > 1 else cx
            for y in range(top - 12, top):
                for x in range(tx - 6, tx + 7):
                    if (x - tx) ** 2 + ((y - (top - 8)) * 1.3) ** 2 <= 30:
                        px[x % BG_W, y] = tree if y < top - 8 else tree_d
            for y in range(top - 3, top):
                px[tx % BG_W, y] = rock_dd
        if water:
            wx = cx + w // 2 - 14
            for y in range(top + 2, h):
                for x in (wx, wx + 1, wx + 2):
                    if dither(x, y, max(0.0, 1.0 - (y - top) / (h - top))):
                        px[x % BG_W, y] = fall
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
        # desert
        "bg_pyramids": pyramids(),
        "bg_dunes_far": hills(120, ["#fbe0a0", "#eec27c", "#dcaa62", "#c8904a"],
                              [(12, 2, 0.4), (7, 5, 1.1), (3, 11, 2.0)], 46, pattern=False, seed=4),
        "bg_cacti": cacti_band(),
        # snow
        "bg_pines_far": pines(110, 31, (22, 40), ["#5a7ca0", "#4a6a8c", "#e4eefa", "#c4d4ea", "#3a5476"], 70),
        "bg_snowhills": hills(110, ["#ffffff", "#e0eaf8", "#c4d4ea", "#98acd0"],
                              [(18, 2, 0.8), (10, 5, 2.1), (5, 13, 0.4)], 52, pattern=False, seed=6),
        "bg_pines_near": pines(110, 37, (34, 58), ["#2f6a58", "#1f4a40", "#ffffff", "#d4e2f6", "#123a30"], 84),
        # cave
        "bg_cave_far": cave_far(),
        "bg_cave_crystals": cave_crystals(),
        "bg_cave_near": cave_near(),
        # castle
        "bg_castle_wall": castle_wall(),
        "bg_castle_pillars": castle_pillars(),
        # sky
        "bg_sky_sea_far": cloud_sea(90, 30, (14, 26), ["#ffffff", "#eaf0fc", "#d4dcf4"], "#b8c6ea", 21),
        "bg_sky_islands": sky_islands(),
        "bg_sky_sea_near": cloud_sea(110, 34, (20, 36), ["#ffffff", "#f4f8ff", "#dde8fa"], "#a8bce6", 23),
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
