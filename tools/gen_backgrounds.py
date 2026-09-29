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


def sea_rays():
    """slanted shafts of light from the surface, fading with depth"""
    h = 170
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    for x0, w, a in ((40, 22, 60), (150, 12, 44), (250, 30, 52), (390, 16, 48), (470, 26, 58), (580, 10, 40)):
        for y in range(h):
            fade = 1.0 - y / h
            xs = x0 + int(y * 0.35)
            for x in range(xs, xs + w):
                edge = min(x - xs, xs + w - 1 - x)
                al = int(a * fade * min(1.0, (edge + 1) / 4.0))
                if al > 0 and dither(x, y, 0.75):
                    px[x % BG_W, y] = (220, 244, 255, al)
    return img


def kelp_forest():
    """band of tall wavy kelp strands (dark teal, far away)"""
    h = 150
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    rng = random.Random(41)
    cols = [hex_rgba(c) for c in ("#2a8a7a", "#1f6e66", "#185a58")]
    for i in range(34):
        x0 = rng.randrange(BG_W)
        hh = rng.randint(60, 140)
        ph = rng.uniform(0, 6.28)
        c = cols[rng.randrange(3)]
        for y in range(h - hh, h):
            k = (h - y) / hh
            x = x0 + int(round(3.0 * k * math.sin(y * 0.09 + ph)))
            for dx in (0, 1, 2):
                px[(x + dx) % BG_W, y] = c
            if y % 9 == 0:
                for dx in (3, 4):
                    px[(x + dx) % BG_W, y] = c
    return img


def beach_sea():
    """sea horizon band behind the beach: light line, waves, sparkles"""
    h = 70
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    top, mid, deep = hex_rgba("#8ad4f4"), hex_rgba("#3aa0e0"), hex_rgba("#2a7ac8")
    rng = random.Random(9)
    for y in range(h):
        for x in range(BG_W):
            t = y / h
            col = top if y < 2 else (mid if not dither(x, y, max(0.0, t - 0.2)) else deep)
            px[x, y] = col
    for i in range(60):
        x, y = rng.randrange(BG_W), rng.randrange(4, h - 4)
        for dx in range(rng.randint(3, 8)):
            px[(x + dx) % BG_W, y] = hex_rgba("#d8f2ff")
    return img


def palms_band():
    """palm silhouettes on a strip of sand (beach exit areas)"""
    h = 90
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    sand, sand_d = hex_rgba("#f4dca0"), hex_rgba("#e0c07c")
    trunk, leaf, leaf_d = hex_rgba("#7a5a3a"), hex_rgba("#3a8a4a"), hex_rgba("#2a6a3a")
    for x in range(BG_W):
        top = 70 + int(periodic(x, [(3, 3, 0.4), (2, 7, 1.3)]))
        for y in range(top, h):
            px[x, y] = sand if y - top < 3 else sand_d
    for x0, hh, lean in ((60, 50, 0.25), (210, 62, -0.2), (300, 44, 0.3), (470, 58, -0.25), (560, 40, 0.2)):
        tx = x0
        for y in range(72, 72 - hh, -1):
            tx = x0 + int((72 - y) * lean)
            for dx in (0, 1, 2):
                px[(tx + dx) % BG_W, y] = trunk
        cx, cy = tx + 1, 72 - hh
        for ang in (-2.8, -2.2, -1.5, -0.9, -0.3, 0.3):
            for i in range(16):
                x = cx + int(round(math.cos(ang) * i * 1.3))
                y = cy + int(round(math.sin(ang) * i * 0.6 + (i / 15) ** 2 * 9))
                for dy in (0, 1):
                    if 0 <= y + dy < h:
                        px[x % BG_W, y + dy] = leaf if dy == 0 else leaf_d
    return img


# ------------------------------------------------------ ghost house (v1.4) --
def ghost_hall():
    """mansion wall, full height: striped wallpaper, wainscoting, tall windows
    (transparent -> the moonlit night sky shows through), portraits, sconces"""
    h = 270
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    paper, paper_d, stripe = hex_rgba("#2e2240"), hex_rgba("#271c38"), hex_rgba("#3a2c50")
    wood, wood_l, wood_d = hex_rgba("#3a2630"), hex_rgba("#4e3440"), hex_rgba("#221418")
    for y in range(h):
        for x in range(BG_W):
            if y >= 196:                                   # wainscoting
                c = wood if (x % 32) not in (0, 31) else wood_d
                if y in (196, 197):
                    c = wood_l
                elif (y - 204) % 30 == 0 or ((x % 32) in (4, 27) and 206 < y < 262):
                    c = wood_d
            else:
                c = stripe if x % 12 < 3 else (paper if (x // 6 + y // 9) % 5 else paper_d)
                if (x % 12 == 7) and (y % 18) in (4, 5) :
                    c = stripe                              # tiny fleur dots
            px[x, y] = c
    frame, frame_d = hex_rgba("#4a3a5a"), hex_rgba("#1c1428")
    for cx in range(48, BG_W, 160):                        # tall arched windows
        top, bot, hw = 60, 170, 16
        for y in range(top - 20, bot + 4):
            for x in range(cx - hw - 4, cx + hw + 5):
                dx = x - cx
                if y < top:
                    inside = dx * dx + (y - top) ** 2 <= hw * hw
                    rim = dx * dx + (y - top) ** 2 <= (hw + 4) ** 2
                else:
                    inside = abs(dx) <= hw and y <= bot
                    rim = abs(dx) <= hw + 4
                if inside:
                    px[x % BG_W, y] = TRANSPARENT
                elif rim:
                    px[x % BG_W, y] = frame if abs(dx) < hw + 3 and y < bot + 3 else frame_d
        for y in range(top - 14, bot):                     # window cross
            px[cx % BG_W, y] = frame_d
        for x in range(cx - hw, cx + hw + 1):
            px[x % BG_W, top + 30] = frame_d
    gold, gold_d, canvas = hex_rgba("#b8903a"), hex_rgba("#7a5a1a"), hex_rgba("#1e1a26")
    face = hex_rgba("#3a3448")
    for cx in range(128, BG_W, 160):                       # portraits
        x0, x1, y0, y1 = cx - 18, cx + 18, 70, 122
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                edge = min(x - x0, x1 - x, y - y0, y1 - y)
                c = gold if edge < 2 else (gold_d if edge < 3 else canvas)
                dx, dy = x - cx, y - 90
                if edge >= 3 and (dx * dx / 90.0 + dy * dy / 150.0 <= 1 or (y > 104 and abs(dx) < 13 - (y - 104) // 3 * -1 and abs(dx) < 14)):
                    c = face
                if edge >= 3 and y in (86, 87) and dx in (-4, -3, 3, 4):
                    c = hex_rgba("#c8c060")                 # the eyes glow a little
                px[x % BG_W, y] = c
    flame, flame_c, brass = hex_rgba("#ff9a2a"), hex_rgba("#fff6a0"), hex_rgba("#8a6a2a")
    for cx in range(88, BG_W, 160):                        # wall sconces
        for y in range(128, 146):
            px[cx % BG_W, y] = brass
        for dx in range(-4, 5):
            px[(cx + dx) % BG_W, 146] = brass
        for dy in range(6):
            for dx in (-1, 0, 1):
                if abs(dx) + dy // 2 < 3:
                    px[(cx + dx) % BG_W, 121 + dy] = flame_c if dx == 0 and dy > 2 else flame
    return img


def ghost_curtains():
    """near layer: dark posts with torn curtains and cobwebs"""
    h = 200
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    post, post_l, line = hex_rgba("#2a1c26"), hex_rgba("#3e2a38"), hex_rgba("#120a10")
    cloth, cloth_d = hex_rgba("#5a1e3a"), hex_rgba("#3e1228")
    web = hex_rgba("#8a86a0")
    for cx in range(80, BG_W, 213 if False else 160):
        for y in range(h):
            for dx in range(-7, 8):
                c = post_l if dx < -3 else post
                if abs(dx) == 7:
                    c = line
                px[(cx + dx) % BG_W, y] = c
        for side in (-1, 1):                               # curtain on both sides
            for y in range(0, 120):
                width = 26 - y // 8 + int(3 * math.sin(y / 7.0 + side))
                for k in range(max(width, 4)):
                    x = cx + side * (8 + k)
                    tear = y > 90 and (k * 7 + y) % 11 < 3
                    if tear:
                        continue
                    c = cloth if (k // 4) % 2 else cloth_d
                    px[x % BG_W, y] = c
        # cobweb in the upper corner right of the post
        for r in range(4, 30, 7):
            for a in range(0, 90, 3):
                x = cx + 8 + int(r * math.cos(math.radians(a)))
                y = int(r * math.sin(math.radians(a)))
                if y < h:
                    px[x % BG_W, y] = web
        for a in (15, 45, 75):
            for r in range(0, 30):
                x = cx + 8 + int(r * math.cos(math.radians(a)))
                y = int(r * math.sin(math.radians(a)))
                px[x % BG_W, y] = web
    return img


def haunted_manor():
    """far layer: a crooked mansion on a hill with lit windows, dead trees"""
    h = 130
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    hill, hill_l = hex_rgba("#241c36"), hex_rgba("#302644")
    for x in range(BG_W):
        top = int(92 - periodic(x, [(10, 1, 0.3), (5, 3, 1.4), (2, 9, 0.8)]))
        for y in range(top, h):
            px[x, y] = hill_l if y - top < 2 else hill
    wall, roof, lit = hex_rgba("#1a1428"), hex_rgba("#120e1c"), hex_rgba("#e8c860")
    cx = 200
    base = 92 - int(periodic(cx, [(10, 1, 0.3), (5, 3, 1.4), (2, 9, 0.8)]))
    def rect(x0, y0, x1, y1, c):
        for y in range(y0, y1):
            for x in range(x0, x1):
                if 0 <= y < h:
                    px[x % BG_W, y] = c
    rect(cx - 40, base - 44, cx + 40, base + 2, wall)          # main house
    rect(cx + 18, base - 70, cx + 36, base - 40, wall)         # tower
    rect(cx - 30, base - 58, cx - 20, base - 44, wall)         # chimney
    for i in range(24):                                         # crooked roofs
        rect(cx - 44 + i, base - 44 - i, cx + 44 - i, base - 43 - i, roof)
    for i in range(12):
        rect(cx + 15 + i, base - 70 - i, cx + 39 - i, base - 69 - i, roof)
    for wx, wy in ((-28, -34), (-12, -34), (4, -34), (-28, -18), (4, -18), (24, -60)):
        if (wx * 3 + wy) % 5:                                   # some windows lit
            rect(cx + wx, base + wy, cx + wx + 6, base + wy + 8, lit)
    rect(cx - 6, base - 16, cx + 2, base + 2, hex_rgba("#0a0610"))  # door
    branch = hex_rgba("#1a1424")
    for tx in (60, 330, 470, 560):                              # dead trees on the ridge
        ty = 92 - int(periodic(tx, [(10, 1, 0.3), (5, 3, 1.4), (2, 9, 0.8)]))
        for y in range(ty - 30, ty + 1):
            px[tx % BG_W, y] = branch
            px[(tx + 1) % BG_W, y] = branch
        for k in range(12):
            px[(tx - k) % BG_W, ty - 22 - k // 2] = branch
            px[(tx + 2 + k) % BG_W, ty - 16 - k // 2] = branch
            px[(tx - k // 2) % BG_W, ty - 30 - k // 3] = branch
    return img


def graves_band():
    """mid layer: dark rolling ground with tombstones, crosses and a fence"""
    h = 110
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    ground, ground_l = hex_rgba("#2e2640"), hex_rgba("#3e3454")
    stone, stone_l = hex_rgba("#4a4660"), hex_rgba("#62607a")
    tops = [int(50 - periodic(x, [(8, 2, 0.6), (4, 5, 2.0), (2, 13, 0.1)])) for x in range(BG_W)]
    for x in range(BG_W):
        for y in range(tops[x], h):
            px[x, y] = ground_l if y - tops[x] < 2 else ground
    rng = random.Random(71)
    x = 10
    while x < BG_W - 10:
        t = tops[x]
        kind = rng.randint(0, 2)
        if kind == 0:                                            # rounded stone
            for y in range(t - 14, t + 2):
                for dx in range(-5, 6):
                    if y < t - 9 and dx * dx + (y - (t - 9)) ** 2 > 25:
                        continue
                    px[(x + dx) % BG_W, y] = stone_l if dx < -2 else stone
        elif kind == 1:                                          # cross
            for y in range(t - 16, t + 1):
                px[x % BG_W, y] = stone
                px[(x + 1) % BG_W, y] = stone
            for dx in range(-4, 6):
                px[(x + dx) % BG_W, t - 12] = stone
                px[(x + dx) % BG_W, t - 11] = stone
        else:                                                    # fence piece
            for k in range(5):
                fx = x + k * 4
                for y in range(tops[fx % BG_W] - 12, tops[fx % BG_W] + 1):
                    px[fx % BG_W, y] = stone
            for k in range(18):
                fx = x + k
                px[fx % BG_W, tops[x] - 9] = stone
        x += rng.randint(24, 46)
    return img


def dead_trees():
    """near layer: big twisted dead trees + a low fog bank"""
    h = 120
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    bark, bark_l = hex_rgba("#1c1622"), hex_rgba("#2a2232")
    rng = random.Random(83)

    def branch(x, y, ang, length, width):
        for i in range(length):
            xx = x + math.cos(ang) * i
            yy = y - math.sin(ang) * i
            for w in range(-width, width + 1):
                X, Y = int(xx + w * 0.5) % BG_W, int(yy)
                if 0 <= Y < h:
                    px[X, Y] = bark_l if w < 0 else bark
            ang += rng.uniform(-0.08, 0.08)
        return int(x + math.cos(ang) * length), int(y - math.sin(ang) * length)

    for tx in range(60, BG_W, 213):
        top = branch(tx, h - 1, math.pi / 2 + rng.uniform(-0.1, 0.1), 78, 7)
        for a, l, off in ((2.4, 40, 10), (0.7, 36, 18), (2.0, 26, 30), (1.0, 30, 38), (1.6, 20, 0)):
            bx, by = branch(top[0], top[1] + off, a, l, 3)
            for k in range(2):
                cx_, cy_ = branch(bx, by, a + rng.uniform(-0.7, 0.7), l // 2, 1)
                branch(cx_, cy_, a + rng.uniform(-0.9, 0.9), l // 4, 0)
    fog = (190, 190, 230)
    for y in range(80, h):
        for x in range(BG_W):
            t = (y - 80) / 40.0
            wav = 0.5 + 0.5 * math.sin(2 * math.pi * 3 * x / BG_W + y * 0.2)
            if dither(x, y, t * 0.6 * wav) and px[x, y][3] == 0:
                px[x, y] = (fog[0], fog[1], fog[2], 70)
    return img


# ----------------------------------------------------------- volcano (v1.5) --
def _heat(img, k=1.0):
    """recolor a (blue/gray) layer into glowing-rock reds by luminance"""
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r * 0.3 + g * 0.5 + b * 0.2) * k
            px[x, y] = (min(255, int(lum * 1.35 + 8)), int(lum * 0.52), int(lum * 0.46), a)
    return img


def volcano_peak():
    """far layer: a big smoking volcano with lava running down, two small
    cones beside it (one volcano per 640 px)"""
    h = 200
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    rock, rock_l, rock_d = hex_rgba("#3e1c20"), hex_rgba("#5a2a2c"), hex_rgba("#2a1216")
    lava, lava_h, glow = hex_rgba("#ff6a1a"), hex_rgba("#ffc040"), hex_rgba("#8a2a18")

    def cone(cx, top, half_top, base_half):
        for y in range(top, h):
            t = (y - top) / (h - top)
            half = int(half_top + (base_half - half_top) * (t ** 0.8))
            for dx in range(-half, half + 1):
                x = (cx + dx) % BG_W
                px[x, y] = rock_l if dx < -half + 3 else (rock_d if dx > half - 4 else rock)
    cone(96, 128, 6, 110)
    cone(548, 120, 7, 120)
    cone(320, 46, 18, 200)
    # crater glow + lava streams
    for dx in range(-17, 18):
        px[(320 + dx) % BG_W, 46] = lava_h if abs(dx) < 12 else lava
        px[(320 + dx) % BG_W, 47] = lava
    rng = random.Random(81)
    for start in (-12, -3, 7, 14):
        x = 320 + start
        for y in range(48, h - 20):
            x += rng.choice((-1, 0, 0, 1)) + (1 if start > 0 and y % 5 == 0 else (-1 if start < 0 and y % 5 == 0 else 0))
            px[x % BG_W, y] = lava_h if y < 70 else lava
            px[(x + 1) % BG_W, y] = glow
    # smoke plume drifting right
    puffs = []
    for i in range(18):
        r = 6 + i * 0.55 + rng.randint(0, 2)
        puffs.append((322 + i * 8 + rng.randint(-3, 3), max(r + 1, 38 - i * 1.8 + 3 * math.sin(i * 1.3)), r))
    for cx, cy, r in reversed(puffs):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if 0 <= y < h and (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    shade = 58 + (8 if (x - cx) + (y - cy) < -r * 0.4 else 0)
                    px[x % BG_W, y] = (shade, shade - 14, shade - 12, 235)
    return img


def lava_fields():
    """mid layer: dark basalt hills with glowing lava rivers"""
    img = hills(120, ["#6a3a36", "#40262a", "#321c22", "#1e1216"],
                [(14, 2, 0.9), (8, 5, 2.4), (4, 11, 0.4)], 48, pattern=False, seed=41)
    px = img.load()
    lava, lava_h = hex_rgba("#ff6a1a"), hex_rgba("#ffb040")
    for x0 in (60, 250, 430, 590):
        x = x0
        top = next(y for y in range(120) if px[x % BG_W, y][3])
        for y in range(top + 2, 120):
            x += (1 if (y // 3) % 3 == 0 else 0) - (1 if (y // 7) % 4 == 1 else 0)
            for dx in range(0, 2 + (y - top) // 18):
                px[(x + dx) % BG_W, y] = lava_h if dx == 0 else lava
    return img


def basalt_spires():
    """near layer: jagged basalt columns with a hot rim on the left"""
    h = 120
    img = Image.new("RGBA", (BG_W, h), TRANSPARENT)
    px = img.load()
    body, dark, rim = hex_rgba("#2a1a1e"), hex_rgba("#1a1014"), hex_rgba("#a8442a")
    base = [int(96 - periodic(x, [(5, 3, 0.3), (3, 8, 1.1)])) for x in range(BG_W)]
    for x in range(BG_W):
        for y in range(base[x], h):
            px[x, y] = body
    rng = random.Random(91)
    x = 8
    while x < BG_W - 6:
        w, top = rng.randint(7, 15), rng.randint(18, 70)
        for dx in range(w):
            peak = top + abs(dx - w // 2) * 2 + rng.randint(0, 1)
            for y in range(peak, base[(x + dx) % BG_W] + 1):
                px[(x + dx) % BG_W, y] = rim if dx == 0 else (dark if dx >= w - 2 else body)
        x += w + rng.randint(10, 40)
    return img


def magma_cave_far():
    """inside the volcano: the cave wall in reds, with lava falls"""
    img = _heat(cave_far())
    px = img.load()
    lava, lava_h, lava_w = hex_rgba("#ff6a1a"), hex_rgba("#ffb040"), hex_rgba("#fff0a0")
    for fx in (60, 230, 440, 590):
        top = next(y for y in range(270) if not px[fx, y][3] or px[fx, y][0] < 60) if px[fx, 0][3] else 0
        for y in range(max(0, top - 4), 236):
            wob = int(1.5 * math.sin(y / 6.0 + fx))
            for dx in range(-3, 4):
                x = (fx + dx + wob) % BG_W
                px[x, y] = lava_w if dx == 0 and y % 9 < 3 else (lava_h if abs(dx) < 2 else lava)
        for y in range(232, 240):
            half = 3 + (y - 232)
            for dx in range(-half, half + 1):
                px[(fx + dx) % BG_W, y] = lava_h if abs(dx) < half - 2 else lava
    return img


def magma_cave_near():
    return _heat(cave_near(), 0.9)


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
        # sea (underwater) + beach
        "bg_sea_rays": sea_rays(),
        "bg_sea_far": hills(120, ["#2e76b4", "#245f9c", "#1d5088", "#1a4478"],
                            [(14, 2, 0.5), (8, 5, 1.9), (4, 13, 0.2)], 46, pattern=False, seed=12),
        "bg_sea_kelp": kelp_forest(),
        "bg_sea_near": hills(100, ["#4a7aa8", "#34608e", "#284e78", "#1e3c62"],
                             [(12, 3, 1.4), (7, 7, 0.6), (3, 17, 2.2)], 44, seed=13),
        "bg_beach_sea": beach_sea(),
        "bg_palms": palms_band(),
        # ghost house (v1.4)
        "bg_ghost_hall": ghost_hall(),
        "bg_ghost_curtains": ghost_curtains(),
        "bg_ghost_manor": haunted_manor(),
        "bg_ghost_graves": graves_band(),
        "bg_ghost_trees": dead_trees(),
        # volcano (v1.5)
        "bg_volcano_peak": volcano_peak(),
        "bg_volcano_fields": lava_fields(),
        "bg_volcano_spires": basalt_spires(),
        "bg_magma_far": magma_cave_far(),
        "bg_magma_near": magma_cave_near(),
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
