#!/usr/bin/env python3
"""World map (v1.1): one wide illustrated map with all six worlds side by side.

    python3 tools/gen_map.py [--preview]

Writes
  assets/graphics/world_map.png   the landscape (no roads, no course markers:
                                  those are drawn at runtime by world_map.gd so
                                  a road can be revealed after a course)
  assets/graphics/map_nodes.png   course marker: open / cleared / locked
  assets/graphics/map_castles.png castle marker: open / cleared / locked
  world_map_data.gd               course positions (in game.gd LEVELS order),
                                  road polylines between neighbours, road look
--preview renders the map with every road and marker (PREVIEW_DIR/prev_map.png).
"""
import math
import os
import random
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from pixelart import hex_rgba, outline, parse, TRANSPARENT  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GFX = os.path.join(ROOT, "assets", "graphics")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")
OUTLINE = "#1a1018"
W, H = 1400, 270

# region x ranges (left edges wobble a little, see region_at)
REGIONS = [(0, 250, "grass"), (250, 480, "cave"), (480, 710, "sand"),
           (710, 940, "snow"), (940, 1170, "sky"), (1170, 1400, "sea")]
# course markers in game.gd LEVELS order: 1-1 .. 1-4, 2-1 .. 2-3, ... 6-3
NODES = [
    (48, 196), (104, 150), (160, 198), (218, 142),
    (292, 182), (360, 212), (428, 152),
    (522, 198), (590, 146), (656, 196),
    (748, 206), (816, 158), (884, 198),
    (984, 150), (1050, 106), (1116, 140),
    (1206, 204), (1276, 222), (1350, 168),
]
CASTLES = {3, 6, 9, 12, 15, 18}
# bend of each road (perpendicular offset of the Bezier control point, px)
BEND = {0: -14, 1: 16, 2: -16, 3: 18, 4: -12, 5: 16, 6: -18, 7: 14, 8: -14, 9: 16, 10: -12,
        11: 14, 12: -26, 13: 14, 14: -12, 15: 26, 16: -10, 17: 14}

PAL = {
    "grass": ((92, 188, 74), (142, 224, 112), (62, 160, 50)),
    "cave": ((86, 84, 116), (118, 116, 152), (60, 58, 88)),
    "sand": ((232, 200, 120), (248, 226, 164), (204, 164, 92)),
    "snow": ((232, 240, 252), (255, 255, 255), (192, 208, 234)),
    "sky": ((150, 208, 250), (206, 236, 255), (120, 186, 240)),
    "sea": ((42, 122, 200), (96, 178, 240), (30, 96, 170)),
}


def hsh(x, y, s=0):
    return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0xFFFF


def region_at(x, y):
    for k, (x0, x1, name) in enumerate(REGIONS):
        edge = x1 + int(5 * math.sin(y * 0.09 + k * 1.7) + 2 * math.sin(y * 0.31 + k))
        if k == len(REGIONS) - 1 or x < edge:
            return k, name
    return len(REGIONS) - 1, "sea"


def bezier(a, c, b, n):
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * c[0] + t * t * b[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * c[1] + t * t * b[1]) for t in (i / n for i in range(n + 1))]


def roads():
    out = []
    for i in range(len(NODES) - 1):
        a, b = NODES[i], NODES[i + 1]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy) or 1
        off = BEND.get(i, 0)
        c = (mx - dy / ln * off, my + dx / ln * off)
        pts = bezier(a, c, b, 10)
        out.append([(round(x), round(y)) for x, y in pts])
    return out


def road_kind(i):
    """look of road i (from course i to i+1) — by the region of its middle"""
    a, b = NODES[i], NODES[i + 1]
    _, name = region_at((a[0] + b[0]) // 2, (a[1] + b[1]) // 2)
    if i == 12:
        return "cloud"                      # snow -> sky: a cloud stair
    return {"sky": "cloud", "sea": "plank"}.get(name, "dirt")


# ------------------------------------------------------------ landscape --
def blob(px, cx, cy, rx, ry, col, rim=None, dither_edge=False):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if 0 <= x < W and 0 <= y < H:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0:
                    px[x, y] = rim if rim and d > 0.72 else col


def paste(img, sprite, x, y):
    """paste with the sprite's feet (bottom centre) at x, y"""
    img.alpha_composite(sprite, (int(x - sprite.width // 2), int(y - sprite.height)))


def near_road(x, y, rds, d=16):
    for r in rds:
        for (rx, ry) in r:
            if abs(rx - x) < d and abs(ry - y) < d:
                return True
    return False


def landscape(rds):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    px = img.load()
    reg = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            k, name = region_at(x, y)
            reg[y][x] = k
            base, light, dark = PAL[name]
            col = base
            v = hsh(x, y) % 100
            if name == "sky":
                t = y / H
                col = tuple(int(PAL["sky"][2][i] + (PAL["sky"][1][i] - PAL["sky"][2][i]) * t) for i in range(3))
            elif name == "sea":
                # short wave dashes in rows
                if (y % 9 == 0 and (x + y * 3) % 23 < 5) or v < 2:
                    col = light
                elif v > 96:
                    col = dark
            elif name == "sand":
                if math.sin(x * 0.06 + y * 0.35 + math.sin(x * 0.02) * 2) > 0.93:
                    col = dark
                elif v < 5:
                    col = light
            else:
                if v < 6:
                    col = light
                elif v > 93:
                    col = dark
            px[x, y] = col + (255,)
    # region seams: a darker line where two worlds meet
    for y in range(H):
        for x in range(1, W):
            if reg[y][x] != reg[y][x - 1]:
                for xx in (x - 1, x):
                    r, g, b, _ = px[xx, y]
                    px[xx, y] = (int(r * 0.72), int(g * 0.72), int(b * 0.78), 255)
    rng = random.Random(5)
    decor = Image.open(os.path.join(GFX, "decor.png")).convert("RGBA")
    idx = {}
    for line in open(os.path.join(ROOT, "decor_index.gd")):
        m = re.match(r'\s*"(\w+)": Rect2\((\d+), (\d+), (\d+), (\d+)\)', line)
        if m:
            n, x, y, w, h = m.group(1), *map(int, m.groups()[1:])
            idx[n] = decor.crop((x, y, x + w, y + h))

    def scatter(names, x0, x1, n, y0=40, y1=H - 12, keep=18):
        placed = 0
        tries = 0
        while placed < n and tries < n * 30:
            tries += 1
            x, y = rng.randint(x0, x1), rng.randint(y0, y1)
            if near_road(x, y, rds, keep) or any(abs(x - nx) < 20 and abs(y - ny) < 20 for nx, ny in NODES):
                continue
            paste(img, idx[rng.choice(names)], x, y)
            placed += 1

    # 1 meadows: a pond, bushes, flowers
    blob(px, 150, 88, 36, 17, (58, 160, 224, 255), (140, 212, 244, 255))
    blob(px, 146, 84, 12, 3, (170, 226, 250, 255))
    for i in range(70):
        x, y = rng.randint(6, 240), rng.randint(40, 262)
        if not near_road(x, y, rds, 8):
            px[x, y] = rng.choice([(255, 90, 90, 255), (255, 216, 60, 255), (255, 255, 255, 255)])
    scatter(["bush_s", "bush_l"], 10, 238, 13)
    # 2 caverns: a ridge with cave mouths, crystals, a little lava pool
    for x in range(252, 478):
        top = 44 + int(16 * math.sin(x * 0.05) + 8 * math.sin(x * 0.13 + 1))
        for y in range(28, top + 40):
            if y >= top:
                px[x, y] = (60, 58, 88, 255) if (x + y) % 7 else (46, 44, 70, 255)
        px[x, top - 1] = (40, 38, 60, 255)
    for cx in (292, 366, 440):
        top = 44 + int(16 * math.sin(cx * 0.05) + 8 * math.sin(cx * 0.13 + 1))
        blob(px, cx, top + 40, 11, 13, (14, 12, 22, 255))
    blob(px, 336, 118, 18, 7, (232, 92, 26, 255), (255, 200, 60, 255))
    scatter(["crystal_s", "rock_cave"], 256, 474, 11, y0=108)
    # 3 desert: a pyramid, an oasis, cacti
    for y in range(26, 92):
        half = int((y - 26) * 0.75)
        for x in range(592 - half, 592 + half + 1):
            px[x, y] = (238, 206, 132, 255) if x < 592 else (204, 164, 92, 255)
            if (y - 26) % 8 == 0:
                px[x, y] = (180, 140, 72, 255)
    blob(px, 684, 98, 22, 9, (58, 160, 224, 255), (140, 212, 244, 255))
    paste(img, idx["palm"], 666, 100)
    scatter(["cactus_s", "cactus_l", "rock_sand"], 486, 704, 11)
    # 4 snow: peaks, a frozen lake, pines
    for cx, hgt in ((740, 60), (790, 78), (850, 64), (910, 70)):
        for y in range(28 + (78 - hgt), 96):
            half = int((y - (28 + 78 - hgt)) * 0.9)
            for x in range(cx - half, cx + half + 1):
                if 0 <= x < W and region_at(x, y)[1] == "snow":
                    snow = y < 28 + (78 - hgt) + 16
                    px[x, y] = ((255, 255, 255, 255) if x < cx else (214, 226, 246, 255)) if snow else \
                        ((150, 170, 210, 255) if x < cx else (116, 136, 180, 255))
    blob(px, 800, 116, 30, 11, (190, 232, 255, 255), (240, 250, 255, 255))
    scatter(["pine", "bush_snow"], 716, 934, 11, y0=100)
    # 5 sky: a cloud floor, cloud islands under the courses, a rainbow
    for x in range(940, 1172):
        top = 232 + int(7 * math.sin(x * 0.08) + 4 * math.sin(x * 0.21))
        for y in range(top, H):
            if region_at(x, y)[1] == "sky":
                px[x, y] = (255, 255, 255, 255) if y - top < 4 else (226, 238, 252, 255)
    bands = [(255, 90, 90), (255, 170, 60), (255, 230, 80), (110, 210, 110), (90, 160, 240)]
    for y in range(150, 225):
        for x in range(975, 1146):
            r = math.hypot((x - 1060) / 1.5, 224 - y)
            b = int((56 - r) // 3)
            if 0 <= b < len(bands) and region_at(x, y)[1] == "sky":
                px[x, y] = bands[b] + (255,)
    for i in (13, 14, 15):
        nx, ny = NODES[i]
        blob(px, nx, ny + 6, 26, 9, (255, 255, 255, 255), (206, 222, 246, 255))
    for cx, cy in ((968, 60), (1030, 40), (1120, 64), (1150, 200), (1000, 210)):
        blob(px, cx, cy, 16, 6, (255, 255, 255, 255), (220, 234, 252, 255))
    # 6 sea: beach, islands with palms, foam
    for y in range(H):
        for x in range(1170, 1240):
            if region_at(x, y)[1] == "sea":
                edge = 1224 + int(6 * math.sin(y * 0.07))
                if x < edge:
                    px[x, y] = (240, 214, 150, 255) if hsh(x, y, 3) % 30 else (210, 180, 120, 255)
                elif x < edge + 2:
                    px[x, y] = (255, 255, 255, 255)
    for i in (17, 18):
        nx, ny = NODES[i]
        blob(px, nx, ny + 4, 24, 11, (240, 214, 150, 255), (255, 255, 255, 255))
    paste(img, idx["palm"], 1300, 214)
    paste(img, idx["palm"], 1372, 152)
    paste(img, idx["palm"], 1190, 120)
    return img


# --------------------------------------------------------------- markers --
def marker_frames():
    """a raised disc seen from above (top face + side), 20x13 incl. outline:
    open (yellow, red dot), cleared (green, white check), locked (grey)"""
    looks = [("#fff4b0", "#ffd83c", "#c88a10", "#c0381c"),
             ("#c8f4c0", "#48c050", "#23803a", "#ffffff"),
             ("#6e6e88", "#4a4a62", "#2e2e40", "#e8e8f4")]
    frames = []
    for n, (hi, top, side, mark) in enumerate(looks):
        im = Image.new("RGBA", (18, 11), TRANSPARENT)
        p = im.load()
        for y in range(11):
            for x in range(18):
                dx = (x - 8.5) / 8.8
                d_top = dx * dx + ((y - 4.0) / 4.4) ** 2
                d_side = dx * dx + ((y - 6.5) / 4.4) ** 2
                if d_top <= 1.0:
                    p[x, y] = hex_rgba(hi if d_top > 0.62 and y < 4 else top)
                elif d_side <= 1.0 and y >= 4:
                    p[x, y] = hex_rgba(side)
        if n == 1:
            for x, y in ((6, 4), (7, 5), (8, 6), (9, 5), (10, 4), (11, 3), (12, 2)):
                p[x, y] = hex_rgba(mark)
        elif n == 2:
            # padlock: shackle + body
            for x, y in ((8, 1), (9, 1), (7, 2), (10, 2)):
                p[x, y] = hex_rgba(mark)
            for x in range(7, 11):
                for y in (3, 4, 5):
                    p[x, y] = hex_rgba(mark)
            p[8, 4] = hex_rgba(side)
        else:
            for x in range(7, 11):
                for y in (3, 4, 5):
                    if not (y != 4 and x in (7, 10)):
                        p[x, y] = hex_rgba(mark)
        frames.append(outline(im, color=OUTLINE, selective=False))
    return frames


def castle_frames():
    """mini castle, drawn at 2x (outline stays 1 px): open (red flag),
    cleared (green flag), locked (grey)"""
    rows = ["..w.........",
            "..ww........",
            "..w.........",
            "..s......s..",
            ".sss.ss.sss.",
            ".sls.ll.sls.",
            ".sssssssssS.",
            ".slssssslsS.",
            ".ssssddsssS.",
            ".sssddddssS.",
            ".sssddddssS.",
            ".SSSddddSSS."]
    out = []
    for flag, stone, light, shade in (("#e8402e", "#b0aec4", "#dcdaea", "#7a788e"),
                                      ("#48c050", "#b0aec4", "#dcdaea", "#7a788e"),
                                      ("#8a8a9c", "#6a6a7c", "#8a8a9c", "#4a4a5a")):
        im = parse(rows, {"w": flag, "s": stone, "l": light, "S": shade, "d": OUTLINE})
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        out.append(outline(im, color=OUTLINE, selective=False))
    return out


def strip(frames):
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    s = Image.new("RGBA", (w * len(frames), h), TRANSPARENT)
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * w + (w - f.width) // 2, h - f.height))
    return s, w, h


def draw_road(img, pts, kind):
    px = img.load()
    fill = {"dirt": (236, 212, 158), "cloud": (255, 255, 255), "plank": (178, 122, 66)}[kind]
    edge = {"dirt": (150, 112, 62), "cloud": (150, 180, 220), "plank": (96, 60, 26)}[kind]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = int(max(abs(bx - ax), abs(by - ay))) + 1
        for i in range(n + 1):
            x = round(ax + (bx - ax) * i / n)
            y = round(ay + (by - ay) * i / n)
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if 0 <= x + dx < W and 0 <= y + dy < H:
                        px[x + dx, y + dy] = edge + (255,)
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = int(max(abs(bx - ax), abs(by - ay))) + 1
        for i in range(n + 1):
            x = round(ax + (bx - ax) * i / n)
            y = round(ay + (by - ay) * i / n)
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if 0 <= x + dx < W and 0 <= y + dy < H:
                        px[x + dx, y + dy] = fill + (255,)


def main():
    rds = roads()
    img = landscape(rds)
    img.save(os.path.join(GFX, "world_map.png"))
    ns, nw, nh = strip(marker_frames())
    ns.save(os.path.join(GFX, "map_nodes.png"))
    cs, cw, ch = strip(castle_frames())
    cs.save(os.path.join(GFX, "map_castles.png"))
    with open(os.path.join(ROOT, "world_map_data.gd"), "w") as fh:
        fh.write("class_name WorldMapData\n\n## Generated by tools/gen_map.py — do not edit by hand.\n"
                 "## NODES: course markers in game.gd LEVELS order; ROADS[i]: polyline from\n"
                 "## course i to course i+1; ROAD_KIND[i]: its look (dirt / cloud / plank).\n\n")
        fh.write("const SIZE := Vector2i(%d, %d)\n" % (W, H))
        fh.write("const NODE_CELL := Vector2i(%d, %d)\nconst CASTLE_CELL := Vector2i(%d, %d)\n" % (nw, nh, cw, ch))
        fh.write("const CASTLES := [%s]\n" % ", ".join(str(c) for c in sorted(CASTLES)))
        fh.write("const REGIONS := [%s]\n" % ", ".join("Vector2i(%d, %d)" % (a, b) for a, b, _ in REGIONS))
        fh.write("const NODES := [\n")
        for x, y in NODES:
            fh.write("\tVector2(%d, %d),\n" % (x, y))
        fh.write("]\nconst ROADS := [\n")
        for r in rds:
            fh.write("\t[%s],\n" % ", ".join("Vector2(%d, %d)" % p for p in r))
        fh.write("]\nconst ROAD_KIND := [%s]\n" % ", ".join('"%s"' % road_kind(i) for i in range(len(rds))))
    if PREVIEW:
        prev = img.copy()
        for i, r in enumerate(rds):
            draw_road(prev, r, road_kind(i))
        for i, (x, y) in enumerate(NODES):
            spr = cs.crop((0, 0, cw, ch)) if i in CASTLES else ns.crop((nw * (1 if i < 7 else 0), 0, nw * (2 if i < 7 else 1), nh))
            prev.alpha_composite(spr, (x - spr.width // 2, y - spr.height + (5 if i not in CASTLES else 6)))
        prev.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(PREVIEW_DIR, "prev_map.png"))
    print("  world_map.png (%dx%d), map_nodes.png, map_castles.png, world_map_data.gd" % (W, H))


if __name__ == "__main__":
    main()
