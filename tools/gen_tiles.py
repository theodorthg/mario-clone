#!/usr/bin/env python3
"""Terrain tiles, block sprites, pipes, decorations, flagpole and castle.

    python3 tools/gen_tiles.py [--preview]

tiles.png (16x16 cells, 16 columns) — the TileSet atlas built at runtime by
level.gd (see TILE_* constants there; keep the two in sync):
  row 0  grass ground, variant = neighbour mask (1 up-open, 2 down-open,
         4 left-open, 8 right-open)
  row 1  interior dirt variants 0..3, hard block, log bridge L/M/R,
         cave interior 0..1, cave brick, water surface x4 (animation), water body
  row 2  pipe: top L/R, body L/R, side-mouth top/bottom, side-body top/bottom
  row 3  cave (bonus room) ground, variant = neighbour mask
  row 4/5 sand / snow ground, row 6 extras (see main()), row 7/8 castle
  row 9  cloud ground (sky world), variant = neighbour mask
  row 10 cloud bridge L/M/R (one-way), sky marble brick, cloud interior x2
blocks.png  ?-block x4, used, brick, cave brick (single 16x16 cells)
decor.png   free-standing decorations, packed with a JSON-ish index in
            decor_index.gd (name -> Rect2)
"""
import os
import sys
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image  # noqa: E402
from pixelart import parse, outline, hex_rgba, preview, strip, TRANSPARENT  # noqa: E402
from spriteframes import write_spriteframes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "graphics")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")
T = 16
OUTLINE = "#1a1018"

# ---------------------------------------------------------------- palette --
DIRT = {
    "a": "#b8763f", "b": "#a0612f", "c": "#834a22", "d": "#5e3016",
    "e": "#d8a060", "s": "#a89c90", "S": "#716660", "T": "#d4cabe",
    "r": "#6a3a1a",
}
GRASS = {
    "L": "#b6f36a", "g": "#6fd33c", "G": "#43a82e", "H": "#2c7c24",
    "D": "#1b4d18", "d": "#5e3016",
}
CAVE = {
    "a": "#5a6aa8", "b": "#46548e", "c": "#343f70", "d": "#222a4e",
    "e": "#8a9ad0", "s": "#7a88bc", "S": "#303a64", "T": "#b0bce4", "r": "#2a3258",
}
CAVE_TOP = {
    "L": "#c4d0f4", "g": "#8e9ed8", "G": "#6878b8", "H": "#4a5896",
    "D": "#1c2344", "d": "#222a4e",
}
SAND = {
    "a": "#e0b060", "b": "#cc9a4c", "c": "#b0803a", "d": "#8a5c26",
    "e": "#f4d08a", "s": "#c8a070", "S": "#9a7040", "T": "#f0dcb0", "r": "#a0703a",
}
SAND_TOP = {
    "L": "#fff4c8", "g": "#f8dc8c", "G": "#ecc670", "H": "#d4a656",
    "D": "#9a6a30", "d": "#8a5c26",
}
SNOW = {
    "a": "#7a8cb0", "b": "#6878a0", "c": "#56648a", "d": "#3c4868",
    "e": "#a0b0d0", "s": "#8a9ac0", "S": "#4c5878", "T": "#c8d4ec", "r": "#465274",
}
SNOW_TOP = {
    "L": "#ffffff", "g": "#f2f7ff", "G": "#d4e2f6", "H": "#aac0e0",
    "D": "#6a7ea8", "d": "#3c4868",
}
LAVA_PAL = {"f": "#fff6a0", "l": "#ffc83a", "w": "#ff7a1a", "m": "#e0401a", "d": "#a8200e"}
ICE_PAL = {"k": OUTLINE, "w": "#ffffff", "l": "#d4f4ff", "i": "#a0e0fa", "I": "#6cc0ec", "D": "#3a8ac8"}
ICE = [
    "kkkkkkkkkkkkkkkk",
    "kwwlllllllllliIk",
    "kwlliiiiiiiiiiIk",
    "klliwiiiiiiiiiIk",
    "kliwwiiiiiiiiiIk",
    "kliwiiiiiiiwiiIk",
    "kliiiiiiiiwwiiIk",
    "kliiiiiiiwwiiiIk",
    "kliiiiiiwwiiiiIk",
    "kliiiiiwwiiiiiIk",
    "kliiiiiwiiiiiiIk",
    "kliiiiiiiiiwiiIk",
    "kliiiiiiiiwiiiIk",
    "kiiiiiiiiiiiiIIk",
    "kIIIIIIIIIIIIIDk",
    "kkkkkkkkkkkkkkkk",
]
SANDSTONE_PAL = {"k": OUTLINE, "l": "#fbe0a0", "b": "#e0b060", "B": "#b0803a", "m": "#6a4418"}
ICEBRICK_PAL = {"k": OUTLINE, "l": "#f0faff", "b": "#b8e4fa", "B": "#78b8e4", "m": "#34608e"}

CASTLE_PAL = {"k": OUTLINE, "l": "#8c8aa0", "s": "#6a687e", "S": "#4e4c62", "m": "#2c2a3a", "L": "#b0aec4"}
CASTLE_STONE = [
    "sssssssmssssssss",
    "sllllllmslllllls",
    "slssssSmslsssssS",
    "sssssSSmsssssSSS",
    "SSSSSSSmSSSSSSSS",
    "mmmmmmmmmmmmmmmm",
    "sssmsssssssmssss",
    "lllmslllllsmslll",
    "sssmslssssSmslss",
    "sSSmsssssSSmsssS",
    "SSSmSSSSSSSmSSSS",
    "mmmmmmmmmmmmmmmm",
    "sssssssmssssssss",
    "sllllllmslllllls",
    "slssssSmslsssssS",
    "mmmmmmmmmmmmmmmm",
]
CASTLE_WALL_PAL = {"k": OUTLINE, "l": "#b0584a", "b": "#843a30", "B": "#5a2420", "m": "#2a1014"}
TORCH = [
    "..y..",
    ".yfy.",
    "yfwfy",
    "yfwfy",
    ".yfy.",
    "kbbbk",
    ".bBb.",
    ".bBb.",
    "..B..",
    "..B..",
    ".kkk.",
]
TORCH_PAL = {"k": OUTLINE, "w": "#fffbe0", "f": "#ffd84a", "y": "#ff8a1a", "b": "#8a5a2a", "B": "#5a3414"}
BANNER = [
    "kkkkkkkkkk",
    "krrrrrrrrk",
    "krRyyyyRrk",
    "krRyrryRrk",
    "krRyrryRrk",
    "krRyyyyRrk",
    "krrrrrrrrk",
    "krrrrrrrrk",
    "krrRrrRrrk",
    "krRk..kRrk",
    "kRk....kRk",
    "kk......kk",
]
BANNER_PAL = {"k": OUTLINE, "r": "#c02838", "R": "#80141e", "y": "#ffd83c"}
SKULL = [".www.", "wwwww", "wkwkw", "wwwww", ".wkw."]
SKULL_PAL = {"w": "#ece4d4", "k": "#2a2030"}


def castle_tile(mask):
    img = parse(CASTLE_STONE, CASTLE_PAL)
    px = img.load()
    ol = hex_rgba(OUTLINE)
    hi = hex_rgba(CASTLE_PAL["L"])
    dk = hex_rgba(CASTLE_PAL["m"])
    if mask & 1:
        for x in range(T):
            px[x, 0] = ol
            px[x, 1] = hi
    if mask & 2:
        for x in range(T):
            px[x, T - 1] = ol
            px[x, T - 2] = dk
    if mask & 4:
        for y in range(T):
            px[0, y] = ol
            if not (mask & 1 and y < 2):
                px[1, y] = hi
    if mask & 8:
        for y in range(T):
            px[T - 1, y] = ol
            px[T - 2, y] = dk if not (mask & 1 and y < 2) else px[T - 2, y]
    return img

DIRT_BASE = [
    "aaabaaaaaaabaaaa",
    "aabbbaaeaaaaabaa",
    "abbcbaaaaaaaaaaa",
    "aabbaaaaaabbaaae",
    "aaaaaaaaabbcbaaa",
    "aeaaaaaaaabbaaaa",
    "aaaaabaaaaaaaaaa",
    "aaaabbbaaaaaeaab",
    "baaaabaaaaaaaaba",
    "aaaaaaaaabaaaaaa",
    "aaeaaaaabbbaaaaa",
    "aaaaaaaaabcbaaba",
    "aaabaaaaaaaaabbb",
    "aabbbaaaaeaaaaba",
    "aaabaaaaaaaaaaaa",
    "aaaaaaabaaaaaaea",
]
# small hand-made features stamped onto the base for the 4 interior variants
FEATURES = {
    "stone": ["..sss.", ".sTsss", "sTsssS", ".sssS.", "..SS.."],
    "pebble": [".e", "ec"],
    "root": ["r...", ".r..", ".rr.", "...r"],
    "crack": ["c..", ".c.", ".cc", "..c"],
}
GRASS_CAP = [
    "..L....LL.....L.",
    ".LgL..LggL...LgL",
    "LgggLLgggggLLggg",
    "gggggggggggggggg",
    "ggGggggggGgggggG",
    "GgGGgGGgGGgGGgGG",
    "HGHHGHHHHGHHGHHH",
    "dHddHdddHddHddHd",
]


def img_from(rows, pal):
    return parse(rows, pal)


def stamp(img, rows, pal, x0, y0, wrap=True):
    px = img.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            xx, yy = x0 + x, y0 + y
            if wrap:
                xx %= T
                yy %= T
            if 0 <= xx < T and 0 <= yy < T:
                px[xx, yy] = hex_rgba(pal[ch])


def dirt_variant(i, pal=DIRT):
    base = img_from(DIRT_BASE, pal)
    if i == 1:
        stamp(base, FEATURES["stone"], pal, 7, 6)
    elif i == 2:
        stamp(base, FEATURES["pebble"], pal, 3, 10)
        stamp(base, FEATURES["root"], pal, 10, 2)
    elif i == 3:
        stamp(base, FEATURES["crack"], pal, 11, 9)
        stamp(base, FEATURES["pebble"], pal, 4, 3)
    return base


def edge_tile(mask, pal, top_pal):
    """mask bits: 1 up-open, 2 down-open, 4 left-open, 8 right-open"""
    img = dirt_variant(0, pal)
    px = img.load()
    dark = hex_rgba(pal["d"])
    mid = hex_rgba(pal["c"])
    ol = hex_rgba(OUTLINE)
    up, down, left, right = mask & 1, mask & 2, mask & 4, mask & 8
    if left:
        for y in range(T):
            px[0, y] = ol
            px[1, y] = dark
            px[2, y] = mid if y % 3 else px[2, y]
    if right:
        for y in range(T):
            px[T - 1, y] = ol
            px[T - 2, y] = dark
            px[T - 3, y] = mid if (y + 1) % 3 else px[T - 3, y]
    if down:
        for x in range(T):
            px[x, T - 1] = ol
            px[x, T - 2] = dark
            if x % 3:
                px[x, T - 3] = mid
    if up:
        cap = parse(GRASS_CAP, top_pal)
        # clear the dirt where the cap has transparent bumps
        for y in range(3):
            for x in range(T):
                px[x, y] = TRANSPARENT
        img.alpha_composite(cap)
        px = img.load()
        # dark outline over the grass silhouette (only against transparency)
        for y in range(3):
            for x in range(T):
                if px[x, y][3] == 0 and y + 1 < T and px[x, y + 1][3] and px[x, y + 1] != ol:
                    px[x, y] = ol
        if left:
            # rounded grass shoulder hanging over the left side
            for y in range(0, 7):
                px[0, y] = ol if y > 0 else TRANSPARENT
                px[1, y] = hex_rgba(top_pal["H"]) if y > 2 else hex_rgba(top_pal["g"])
            px[0, 0] = TRANSPARENT
            px[1, 0] = TRANSPARENT
            px[0, 1] = TRANSPARENT
            px[1, 1] = ol
            px[0, 7] = ol
            px[1, 7] = hex_rgba(top_pal["D"])
            px[2, 7] = hex_rgba(top_pal["D"])
        if right:
            for y in range(0, 7):
                px[T - 1, y] = ol if y > 0 else TRANSPARENT
                px[T - 2, y] = hex_rgba(top_pal["H"]) if y > 2 else hex_rgba(top_pal["g"])
            px[T - 1, 0] = TRANSPARENT
            px[T - 2, 0] = TRANSPARENT
            px[T - 1, 1] = TRANSPARENT
            px[T - 2, 1] = ol
            px[T - 1, 7] = ol
            px[T - 2, 7] = hex_rgba(top_pal["D"])
            px[T - 3, 7] = hex_rgba(top_pal["D"])
    return img


# ------------------------------------------------------------------ clouds --
CLOUD_PAL = {"w": "#ffffff", "l": "#eef4ff", "m": "#d8e6fb", "b": "#b8cbef", "d": "#93a9dc",
             "k": "#4a5a8e"}


def _bump(i):
    """scallop depth (0..2) along a cloud edge, two puffs per tile"""
    u = abs((i % 8) - 3.5)
    return int(round(max(0.0, 3.5 - (max(0.0, 3.9 * 3.9 - u * u)) ** 0.5)))


def cloud_tile(mask, variant=0):
    """cloud ground: same neighbour mask as the other autotiles; open sides
    get puffy scalloped edges with a soft blue outline, the underside a
    blue shade (light from above)"""
    up, down, left, right = mask & 1, mask & 2, mask & 4, mask & 8
    inside = [[False] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            ok = True
            if up and y < 1 + _bump(x):
                ok = False
            if down and y > T - 2 - _bump(x):
                ok = False
            if left and x < 1 + _bump(y):
                ok = False
            if right and x > T - 2 - _bump(y):
                ok = False
            # round the outer corners
            for cu, cl, cx, cy in ((up, left, 5, 5), (up, right, T - 6, 5),
                                   (down, left, 5, T - 6), (down, right, T - 6, T - 6)):
                if cu and cl and abs(x - cx) + 0 <= 5 and ((x < cx) == (cx < 8)) and ((y < cy) == (cy < 8)):
                    if (x - cx) ** 2 + (y - cy) ** 2 > 5.3 ** 2:
                        ok = False
            inside[y][x] = ok
    img = Image.new("RGBA", (T, T), TRANSPARENT)
    px = img.load()
    for y in range(T):
        for x in range(T):
            if not inside[y][x]:
                continue
            col = "l"
            if up:
                top = 1 + _bump(x)
                if y - top < 2:
                    col = "w"
            if down:
                bot = T - 2 - _bump(x)
                if bot - y < 1:
                    col = "d"
                elif bot - y < 3:
                    col = "b"
                elif bot - y < 5:
                    col = "m"
            if right and x > T - 5 - _bump(y) and col in "lw":
                col = "m"
            if variant and col == "l":
                # interior swirl variants
                sw = {1: [(4, 5), (5, 4), (6, 4), (7, 5), (11, 11), (12, 10)],
                      2: [(9, 3), (10, 3), (11, 4), (3, 11), (4, 12), (5, 12)]}[variant]
                if (x, y) in sw:
                    col = "m"
            px[x, y] = hex_rgba(CLOUD_PAL[col])
    # soft outline on the open sides (only against transparency inside the tile)
    k = hex_rgba(CLOUD_PAL["k"])
    for y in range(T):
        for x in range(T):
            if inside[y][x]:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < T and 0 <= ny < T and inside[ny][nx]:
                    px[x, y] = k
                    break
    return img


def cloud_bridge(end):
    """one-way cloud strip (top 7 px of the tile)"""
    img = Image.new("RGBA", (T, T), TRANSPARENT)
    px = img.load()
    inside = set()
    for x in range(T):
        top = 1 + _bump(x)
        bot = 6 - _bump(x + 4) // 2
        for y in range(top, bot + 1):
            if end == "L" and x < 4 and (x - 4) ** 2 + (y - 3.5) ** 2 > 3.6 ** 2:
                continue
            if end == "R" and x > 11 and (x - 11) ** 2 + (y - 3.5) ** 2 > 3.6 ** 2:
                continue
            inside.add((x, y))
    for (x, y) in inside:
        top = 1 + _bump(x)
        col = "w" if y - top < 2 else ("b" if (x, y + 1) not in inside else "l")
        px[x, y] = hex_rgba(CLOUD_PAL[col])
    k = hex_rgba(CLOUD_PAL["k"])
    for y in range(T):
        for x in range(T):
            if (x, y) in inside:
                continue
            if any((nx, ny) in inside for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                px[x, y] = k
    return img


SKY_BRICK_PAL = {"k": OUTLINE, "l": "#ffffff", "b": "#e4eaf8", "B": "#b4c0dc", "m": "#c8a24a"}


# ------------------------------------------------------------------ blocks --
QB_PAL = {
    "k": OUTLINE, "y": "#ffe27a", "Y": "#f7b52c", "o": "#c26f10", "O": "#7a3e08",
    "p": "#6a3408", "P": "#ffd98a",
}
QB_BASE = [
    ".kkkkkkkkkkkkkk.",
    "kyyyyyyyyyyyyyok",
    "kyPYYYYYYYYYYPok",
    "kyppYYYYYYYYYpok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyYYYYYYYYYYYYok",
    "kyPYYYYYYYYYYPok",
    "kyppYYYYYYYYYpok",
    "koooooooooooooOk",
    ".kkkkkkkkkkkkkk.",
]
QMARK = [
    ".wwww.",
    "ww..ww",
    "....ww",
    "...ww.",
    "..ww..",
    "..ww..",
    "......",
    "..ww..",
]
USED_PAL = {"k": OUTLINE, "y": "#c98a52", "Y": "#a2622e", "o": "#7a4420", "O": "#4e2810",
            "p": "#4e2810", "P": "#e0b080"}
BRICK_PAL = {"k": OUTLINE, "l": "#f4a060", "b": "#d0692a", "B": "#9a4214", "m": "#3a1a08"}
BRICK = [
    "llllllllmlllllll",
    "lbbbbbbBmlbbbbbb",
    "lbbbbbbBmlbbbbbb",
    "lbbbbbbBmlbbbbbb",
    "lbbbbbbBmlbbbbbb",
    "lbbbbbbBmlbbbbbb",
    "BBBBBBBBmBBBBBBB",
    "mmmmmmmmmmmmmmmm",
    "llllmllllllllmll",
    "bbbBmlbbbbbbbBml",
    "bbbBmlbbbbbbbBml",
    "bbbBmlbbbbbbbBml",
    "bbbBmlbbbbbbbBml",
    "bbbBmlbbbbbbbBml",
    "BBBBmBBBBBBBBBmB",
    "mmmmmmmmmmmmmmmm",
]
CAVE_BRICK_PAL = {"k": OUTLINE, "l": "#9ab0f0", "b": "#5a74c8", "B": "#34488e", "m": "#161c3a"}
HARD_PAL = {"k": OUTLINE, "l": "#f0d0a0", "L": "#fff0d0", "b": "#c8925a", "B": "#8e5a2c", "D": "#5a3416"}
HARD = [
    "LLLLLLLLLLLLLLLl",
    "LlllllllllllllbD",
    "LllbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbbbbbbbbbbbbBD",
    "LlbBBBBBBBBBBBBD",
    "lbBBBBBBBBBBBBBD",
    "lDDDDDDDDDDDDDDD",
]


def qblock(glyph_col, shadow_col, base_pal=QB_PAL):
    img = parse(QB_BASE, base_pal)
    px = img.load()
    for y, r in enumerate(QMARK):
        for x, ch in enumerate(r):
            if ch == "w":
                px[5 + x + 1, 4 + y + 1] = hex_rgba(shadow_col)
    for y, r in enumerate(QMARK):
        for x, ch in enumerate(r):
            if ch == "w":
                px[5 + x, 4 + y] = hex_rgba(glyph_col)
    return img


# ------------------------------------------------------------------- pipes --
PIPE_COLS = {"k": OUTLINE, "D": "#0c4a16", "d": "#177a26", "g": "#23a632", "l": "#5ad65a",
             "L": "#a8f59a", "W": "#e8ffe0"}
# 32 px wide lip profile and 28 px body profile, left to right
LIP = "kdggLWLllgggggggggggggdddDDDDDDk"
BODY = "kdgLWLlgggggggggggggdddDDDDDk"[:28]
BODY = BODY.ljust(28, "k")


def pipe_tiles():
    lip_rows = 16
    lip = Image.new("RGBA", (32, 16), TRANSPARENT)
    px = lip.load()
    for y in range(lip_rows):
        for x in range(32):
            ch = LIP[x]
            if y == 0 or y == lip_rows - 1:
                ch = "k"
            elif y == lip_rows - 2:
                ch = "D" if ch not in "k" else "k"
            elif y == 1 and ch in "gl":
                ch = "l"
            px[x, y] = hex_rgba(PIPE_COLS[ch])
    body = Image.new("RGBA", (32, 16), TRANSPARENT)
    px = body.load()
    for y in range(16):
        for x in range(28):
            px[x + 2, y] = hex_rgba(PIPE_COLS[BODY[x]])
    # side pipe: rotate profiles 90 degrees -> mouth faces LEFT; the extra
    # vertical flip keeps the highlight band on TOP (light from above)
    side_mouth = lip.rotate(90, expand=True).transpose(Image.FLIP_TOP_BOTTOM)   # 16 x 32
    side_body = body.rotate(90, expand=True).transpose(Image.FLIP_TOP_BOTTOM)
    return lip, body, side_mouth, side_body


# ------------------------------------------------------------ log bridge --
BRIDGE_PAL = {"k": OUTLINE, "l": "#e8b070", "b": "#b87838", "B": "#7c4a1c", "n": "#d8d0c8", "r": "#9a6a3a"}
BRIDGE_M = [
    "kkkkkkkkkkkkkkkk",
    "llllllllllllllll",
    "bbbbbbbnbbbbbbbb",
    "bbbbbbbbbbbbbbbb",
    "BBBBBBBBBBBBBBBB",
    "kkkkkkkkkkkkkkkk",
    "......rr........",
    "......rr........",
    ".......r........",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]


def bridge(end):
    rows = [list(r) for r in BRIDGE_M]
    if end == "L":
        for y in range(1, 5):
            rows[y][0] = "k"
    if end == "R":
        for y in range(1, 5):
            rows[y][15] = "k"
    return parse(["".join(r) for r in rows], BRIDGE_PAL)


# ------------------------------------------------------------- decorations --
DECOR_PAL = {
    "k": OUTLINE, "L": "#b6f36a", "g": "#6fd33c", "G": "#43a82e", "H": "#2c7c24",
    "D": "#1b4d18", "w": "#ffffff", "y": "#ffd83c", "r": "#ff5a5a", "p": "#ff9ad0",
    "b": "#9a6a3a", "B": "#6a4420", "s": "#b8b0a8", "S": "#7a726c", "T": "#e0d8d0",
    "o": "#f79a2a",
}
BUSH_L = [
    "..........gggg...........gggg...",
    "........ggLLggg........ggLLggg..",
    "...ggg.gLLgggggg.ggg..gLLggggggg",
    "..gLLggggggggggggLLggggggggggGgg",
    ".gLLgggggGgggggggggggggGgggggGGg",
    ".gggggggGGgggggGgggggggGGgggGGGG",
    "gggGggggGGgggggGGggggGGGgggGGGGG",
    "gggGGgggGGGgggGGGgggGGGGggGGHGGG",
    "ggGGGggGGGGGgGGGGGgGGGGHGGGHHHGH",
    "HGGGHGGGHGGHGGHHGGGGHGHHHGHHHHHH",
    "HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
]
FLOWER_A = ["..r.", ".ryr", "..rG", "..G.", ".GG.", "..G."]
FLOWER_B = [".p..", "pyp.", ".pG.", "..G.", "..GG", "..G."]
FLOWER_C = [".w..", "wyw.", ".wG.", "..G.", ".GG.", "..G."]
TUFT = ["L...L..L", "gL.gg.Lg", "ggLgggLg", "GgggGggG"]
ROCK = ["..sssT..", ".sTTsss.", "sTssssSs", "ssssSSSS", "SSSSSSSk"]
SIGN = [
    ".bbbbbbbbbb.",
    "bTTTTTTTTTTb",
    "bTTTTTkTTTTb",
    "bTTTTTkkTTTb",
    "bTkkkkkkkTTb",
    "bTTTTTkkTTTb",
    "bTTTTTkTTTTb",
    "bTTTTTTTTTTb",
    ".bbbbbbbbbb.",
    ".....BB.....",
    ".....BB.....",
    ".....BB.....",
    ".....BB.....",
]
FENCE = [
    ".bB....bB....bB.",
    "bbbbbbbbbbbbbbbB",
    "bBBBBBBBBBBBBBBB",
    ".bB....bB....bB.",
    ".bB....bB....bB.",
    "bbbbbbbbbbbbbbbB",
    "bBBBBBBBBBBBBBBB",
    ".bB....bB....bB.",
    ".bB....bB....bB.",
]


# ------------------------------------------------------------ biome decor --
CACTUS = {"L": "#9ad86a", "g": "#5aa83c", "G": "#3a7a2a", "t": "#f4ecc0", "p": "#ff6ab0", "y": "#ffd83c"}


def _rib(px, x0, y0, w, h, pal, round_top=True):
    cols = [pal["L"], pal["g"], pal["g"], pal["G"]][:w] if w <= 4 else \
        [pal["L"]] + [pal["g"]] * (w - 2) + [pal["G"]]
    for y in range(y0, y0 + h):
        for i in range(w):
            if round_top and y == y0 and (i == 0 or i == w - 1):
                continue
            c = cols[i]
            if 0 < i < w - 1 and (y - y0) % 5 == 2 and i == w // 2:
                c = pal["t"]
            px[x0 + i, y] = hex_rgba(c)


def cactus_l():
    img = Image.new("RGBA", (14, 26), TRANSPARENT)
    px = img.load()
    _rib(px, 5, 0, 4, 26, CACTUS)          # trunk
    _rib(px, 0, 9, 4, 9, CACTUS)           # left arm (up)
    _rib(px, 3, 14, 3, 4, CACTUS, False)   # left elbow
    _rib(px, 10, 5, 4, 9, CACTUS)          # right arm (up)
    _rib(px, 8, 10, 3, 4, CACTUS, False)   # right elbow
    return outline(img, color=OUTLINE, selective=False)


def cactus_s():
    img = Image.new("RGBA", (10, 10), TRANSPARENT)
    px = img.load()
    for y in range(2, 10):
        for x in range(10):
            dx, dy = (x - 4.5) / 5.0, (y - 6.0) / 4.6
            if dx * dx + dy * dy <= 1.0:
                c = CACTUS["g"]
                if x in (2, 5, 8):
                    c = CACTUS["G"]
                if x < 2 or (x == 3 and y < 5):
                    c = CACTUS["L"]
                px[x, y] = hex_rgba(c)
    for x, y, c in [(4, 0, "p"), (5, 0, "p"), (3, 1, "p"), (4, 1, "y"), (5, 1, "y"), (6, 1, "p")]:
        px[x, y] = hex_rgba(CACTUS[c])
    return outline(img, color=OUTLINE, selective=False)


PINE = {"n": "#1f5a3a", "N": "#12402a", "l": "#2f7a4a", "w": "#ffffff", "W": "#d4e2f6", "b": "#5a3a22"}


def pine():
    w, h = 18, 30
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()
    tiers = [(0, 8, 4), (6, 9, 6), (12, 10, 8), (18, 9, 9)]   # (top, height, half width)
    for top, th, hw in tiers:
        for y in range(top, top + th):
            half = max(1, round((y - top + 1) / th * hw))
            for x in range(9 - half, 9 + half):
                c = PINE["l"] if x < 9 else PINE["n"]
                if y - top >= th - 2:
                    c = PINE["N"]
                # snow on the upper slope of every tier
                if y - top < 3 or (x - (9 - half) < 2 and y - top < th - 2):
                    c = PINE["w"] if x < 11 else PINE["W"]
                px[x, y] = hex_rgba(c)
    for y in range(27, h):
        for x in (8, 9):
            px[x, y] = hex_rgba(PINE["b"])
    return outline(img, color=OUTLINE, selective=False)


CRYSTAL_CYAN = ("#d8fcff", "#5ce0f0", "#2a8ab8")
CRYSTAL_PURPLE = ("#f4d8ff", "#b474f4", "#6a38b0")
CRYSTAL_ICE = ("#ffffff", "#bfe8ff", "#7ab4e4")


def crystal(img, x0, h, w, cols):
    px = img.load()
    H = img.size[1]
    light, mid, dark = [hex_rgba(c) for c in cols]
    tip = w // 2 + 1
    for y in range(H - h, H):
        d = y - (H - h)
        half = min(w / 2.0, (d + 1) * w / (2.0 * tip))
        for x in range(w):
            if abs(x + 0.5 - w / 2.0) <= half:
                c = light if x < w / 2.0 - 1 else (mid if x < w / 2.0 + 1 else dark)
                px[x0 + x, y] = c


def crystal_l():
    img = Image.new("RGBA", (18, 20), TRANSPARENT)
    crystal(img, 0, 11, 6, CRYSTAL_PURPLE)
    crystal(img, 11, 13, 6, CRYSTAL_PURPLE)
    crystal(img, 5, 20, 8, CRYSTAL_CYAN)
    return outline(img, color=OUTLINE, selective=False)


def crystal_s(cols=CRYSTAL_CYAN, cols2=CRYSTAL_PURPLE):
    img = Image.new("RGBA", (10, 11), TRANSPARENT)
    crystal(img, 4, 7, 5, cols2)
    crystal(img, 0, 11, 6, cols)
    return outline(img, color=OUTLINE, selective=False)


GLOW = {"c": "#6af0ff", "C": "#2ab0d8", "w": "#e8ffff", "s": "#d8d0e8", "S": "#8a84a8"}
GLOWSHROOM = [
    "..cccc..",
    ".cwcccC.",
    "ccccwcCC",
    "CCCCCCCC",
    "...ss...",
    "...sS...",
    "..ssS...",
]


def recolored(rows, **kw):
    pal = dict(DECOR_PAL)
    pal.update(kw)
    return parse(rows, pal)


def biome_decor():
    ol_ = lambda im: outline(im, color=OUTLINE, selective=False)  # noqa: E731
    small_bush = [r[:18] for r in BUSH_L[1:]]
    return [
        ("cactus_l", cactus_l()),
        ("cactus_s", cactus_s()),
        ("dflower", recolored(FLOWER_A, G="#8a9a3a", r="#ff6ab0")),
        ("tuft_sand", recolored(TUFT, L="#fff0a8", g="#e8c860", G="#b8923a")),
        ("rock_sand", ol_(recolored(ROCK, s="#d8b078", T="#f4dcb0", S="#a07848"))),
        ("pine", pine()),
        ("bush_snow", ol_(recolored(small_bush, L="#ffffff", g="#eef4ff", G="#c4d4ec", H="#8aa0c8", D="#4a5e88"))),
        ("frost", crystal_s(CRYSTAL_ICE, CRYSTAL_ICE)),
        ("tuft_snow", recolored(TUFT, L="#ffffff", g="#e4eeff", G="#a8bcdc")),
        ("rock_snow", ol_(recolored(ROCK, s="#8a9ac0", T="#ffffff", S="#56648a"))),
        ("crystal_l", crystal_l()),
        ("crystal_s", crystal_s()),
        ("glowshroom", ol_(parse(GLOWSHROOM, GLOW))),
        ("tuft_cave", recolored(TUFT, L="#8ae0d0", g="#4aa8a0", G="#2a7078")),
        ("rock_cave", ol_(recolored(ROCK, s="#6a78a8", T="#9aa8d4", S="#3e4876"))),
        ("torch", parse(TORCH, TORCH_PAL)),
        ("banner", parse(BANNER, BANNER_PAL)),
        ("skull", ol_(parse(SKULL, SKULL_PAL))),
        ("rock_castle", ol_(recolored(ROCK, s="#6a687e", T="#8c8aa0", S="#4e4c62"))),
        # sky: blossom bushes (pink reads well on white cloud ground)
        ("sky_bush_l", ol_(recolored(BUSH_L, L="#ffe4f2", g="#ffb4da", G="#ec86be", H="#c05c98", D="#7e3464"))),
        ("sky_bush_s", ol_(recolored(small_bush, L="#ffe4f2", g="#ffb4da", G="#ec86be", H="#c05c98", D="#7e3464"))),
        ("sky_flower", recolored(FLOWER_C, w="#8ad4ff", y="#ffe060", G="#58c060")),
        ("tuft_sky", recolored(TUFT, L="#ffffff", g="#e8f0ff", G="#b8cbef")),
        ("rock_sky", ol_(recolored(ROCK, s="#e4eaf8", T="#ffffff", S="#a8b6d6"))),
    ]


def castle():
    """80 x 88 px small castle, door centered at x=40 (door 16 wide, 24 tall)."""
    w, h = 80, 88
    img = Image.new("RGBA", (w, h), TRANSPARENT)
    px = img.load()
    stone = hex_rgba("#b9a58c")
    light = hex_rgba("#e3d3bc")
    dark = hex_rgba("#7c6a58")
    mortar = hex_rgba("#4a3c30")
    ol = hex_rgba(OUTLINE)

    def brick_fill(x0, y0, x1, y1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                row = (y - y0) // 6
                off = 0 if row % 2 == 0 else 5
                if (y - y0) % 6 == 5 or (x - x0 + off) % 10 == 9:
                    px[x, y] = mortar
                elif (y - y0) % 6 == 0:
                    px[x, y] = light
                elif (x - x0 + off) % 10 == 8:
                    px[x, y] = dark
                else:
                    px[x, y] = stone

    def box_outline(x0, y0, x1, y1):
        for x in range(x0, x1):
            px[x, y0] = ol
            px[x, y1 - 1] = ol
        for y in range(y0, y1):
            px[x0, y] = ol
            px[x1 - 1, y] = ol

    def battlements(x0, x1, y):
        for x in range(x0, x1, 8):
            brick_fill(x, y, min(x + 5, x1), y + 6)
            box_outline(x, y, min(x + 5, x1), y + 7)

    # lower keep
    brick_fill(0, 44, 80, 88)
    box_outline(0, 44, 80, 88)
    battlements(0, 80, 38)
    # tower
    brick_fill(20, 12, 60, 45)
    box_outline(20, 12, 60, 45)
    battlements(20, 60, 6)
    # tower window
    for y in range(20, 32):
        for x in range(36, 44):
            if (y < 23 and (x < 38 or x > 41)):
                continue
            px[x, y] = ol
    # door (arched)
    for y in range(64, 88):
        for x in range(32, 48):
            if y < 68 and (x < 32 + (68 - y) or x > 47 - (68 - y)):
                continue
            px[x, y] = ol if (x in (32, 47) or y == 64) else hex_rgba("#20141c")
    # flag pole on tower
    for y in range(0, 7):
        px[40, y] = hex_rgba("#e8e8e8")
    return img


def flag_parts():
    pole = Image.new("RGBA", (4, 16), TRANSPARENT)
    p = pole.load()
    for y in range(16):
        p[0, y] = hex_rgba(OUTLINE)
        p[1, y] = hex_rgba("#e8f8e0")
        p[2, y] = hex_rgba("#7ac870")
        p[3, y] = hex_rgba(OUTLINE)
    ball = outline(parse([
        ".gggg.", "gLLggg", "gLgggG", "ggggGG", "ggGGGG", ".GGGG."],
        {"g": "#3cc43c", "G": "#1f8a2c", "L": "#b6f36a"}), color=OUTLINE, selective=False)
    flag = outline(parse([
        "wwwwwwwwwwwwwww",
        ".wwwwwwwwwwwwww",
        "..wwwwggwwwwwww",
        "...wwgggggwwwww",
        "....wwgggwwwwww",
        ".....wgwgwwwwww",
        "......wwwwwwwww",
        ".......wwwwwwww",
        "........wwwwwww",
        ".........wwwwww",
        "..........wwwww",
        "...........wwww",
        "............www",
    ], {"w": "#ffffff", "g": "#3cc43c"}), color=OUTLINE, selective=False)
    castle_flag = outline(parse([
        "rrrrrrrr", "rrryrrr.", "rryyyr..", "rrryr...", "rrrr....", "rrr.....",
    ], {"r": "#e0302e", "y": "#ffd83c"}), color=OUTLINE, selective=False)
    return pole, ball, flag, castle_flag


CHECKPOINT = [
    ".kk.........",
    "kwwkFFFFFF..",
    "kwwkFFFFFFF.",
    ".kk.FFFFFFFF",
    ".bb.FFFFFFF.",
    ".bb.FFFFFF..",
    ".bb.FFFFF...",
    ".bb.........",
    ".bb.........",
    ".bb.........",
    ".bb.........",
    ".bb.........",
    ".bb.........",
    ".bb.........",
    "bbbb........",
    "BBBB........",
]


def checkpoint(flag_col):
    pal = dict(DECOR_PAL)
    pal["F"] = flag_col
    return outline(parse(CHECKPOINT, pal), color=OUTLINE, selective=False)


WATER_PAL = {"f": "#f4fbff", "l": "#a8dcff", "w": "#4a9ae8", "m": "#3a82d6", "d": "#2a64b8"}


def water_surface(frame, pal=WATER_PAL, alpha=225):
    """16x16, 4 animation frames: a travelling wave crest + foam on top."""
    img = Image.new("RGBA", (T, T), TRANSPARENT)
    px = img.load()
    import math as _m
    for x in range(T):
        crest = 2 + round(1.2 * _m.sin(2 * _m.pi * (x + frame * 4) / T))
        for y in range(crest, T):
            d = y - crest
            ch = "f" if d == 0 else ("l" if d == 1 else ("w" if d < 7 else "m"))
            if d > 2 and (x + y * 3 + frame * 5) % 13 == 0:
                ch = "l"
            c = hex_rgba(pal[ch])
            px[x, y] = (c[0], c[1], c[2], alpha)
    return img


def lava_body():
    img = Image.new("RGBA", (T, T), TRANSPARENT)
    px = img.load()
    for y in range(T):
        for x in range(T):
            ch = "m" if y < 9 else "d"
            if (x * 5 + y * 7) % 19 == 0:
                ch = "w"
            px[x, y] = hex_rgba(LAVA_PAL[ch])
    return img


def water_body():
    img = Image.new("RGBA", (T, T), TRANSPARENT)
    px = img.load()
    for y in range(T):
        for x in range(T):
            ch = "m" if y < 10 else "d"
            if (x * 5 + y * 7) % 23 == 0:
                ch = "w"
            c = hex_rgba(WATER_PAL[ch])
            px[x, y] = (c[0], c[1], c[2], 225)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    atlas = Image.new("RGBA", (16 * T, 11 * T), TRANSPARENT)
    for m in range(16):
        atlas.paste(edge_tile(m, DIRT, GRASS), (m * T, 0))
        atlas.paste(edge_tile(m, CAVE, CAVE_TOP), (m * T, 3 * T))
        atlas.paste(edge_tile(m, SAND, SAND_TOP), (m * T, 4 * T))
        atlas.paste(edge_tile(m, SNOW, SNOW_TOP), (m * T, 5 * T))
        atlas.paste(castle_tile(m), (m * T, 7 * T))
        atlas.paste(cloud_tile(m), (m * T, 9 * T))
    # row 10: cloud bridge L/M/R (one-way), sky marble brick, cloud interior 1/2
    atlas.paste(cloud_bridge("L"), (0, 10 * T))
    atlas.paste(cloud_bridge("M"), (T, 10 * T))
    atlas.paste(cloud_bridge("R"), (2 * T, 10 * T))
    atlas.paste(parse(BRICK, SKY_BRICK_PAL), (3 * T, 10 * T))
    atlas.paste(cloud_tile(0, 1), (4 * T, 10 * T))
    atlas.paste(cloud_tile(0, 2), (5 * T, 10 * T))
    # row 8: castle interior 0 (plain) 1 (cracked), castle wall brick 2
    atlas.paste(castle_tile(0), (0, 8 * T))
    cracked = castle_tile(0)
    stamp(cracked, FEATURES["crack"], {"c": CASTLE_PAL["m"]}, 9, 7)
    atlas.paste(cracked, (T, 8 * T))
    atlas.paste(parse(BRICK, CASTLE_WALL_PAL), (2 * T, 8 * T))
    # row 6: sand interior 0-3, snow interior 4-7, ice 8, lava top 9-12
    # (animation), lava 13, sandstone brick 14, ice brick 15
    for i in range(4):
        atlas.paste(dirt_variant(i, SAND), (i * T, 6 * T))
        atlas.paste(dirt_variant(i, SNOW), ((4 + i) * T, 6 * T))
    atlas.paste(parse(ICE, ICE_PAL), (8 * T, 6 * T))
    for f in range(4):
        atlas.paste(water_surface(f, LAVA_PAL, 255), ((9 + f) * T, 6 * T))
    atlas.paste(lava_body(), (13 * T, 6 * T))
    atlas.paste(parse(BRICK, SANDSTONE_PAL), (14 * T, 6 * T))
    atlas.paste(parse(BRICK, ICEBRICK_PAL), (15 * T, 6 * T))
    for i in range(4):
        atlas.paste(dirt_variant(i), (i * T, T))
    atlas.paste(parse(HARD, HARD_PAL), (4 * T, T))
    atlas.paste(bridge("L"), (5 * T, T))
    atlas.paste(bridge("M"), (6 * T, T))
    atlas.paste(bridge("R"), (7 * T, T))
    atlas.paste(dirt_variant(0, CAVE), (8 * T, T))
    atlas.paste(dirt_variant(1, CAVE), (9 * T, T))
    atlas.paste(parse(BRICK, CAVE_BRICK_PAL), (10 * T, T))
    for f in range(4):                       # water surface animation 11..14
        atlas.paste(water_surface(f), ((11 + f) * T, T))
    atlas.paste(water_body(), (15 * T, T))
    lip, body, side_mouth, side_body = pipe_tiles()
    atlas.paste(lip.crop((0, 0, 16, 16)), (0, 2 * T))
    atlas.paste(lip.crop((16, 0, 32, 16)), (T, 2 * T))
    atlas.paste(body.crop((0, 0, 16, 16)), (2 * T, 2 * T))
    atlas.paste(body.crop((16, 0, 32, 16)), (3 * T, 2 * T))
    atlas.paste(side_mouth.crop((0, 0, 16, 16)), (4 * T, 2 * T))
    atlas.paste(side_mouth.crop((0, 16, 16, 32)), (5 * T, 2 * T))
    atlas.paste(side_body.crop((0, 0, 16, 16)), (6 * T, 2 * T))
    atlas.paste(side_body.crop((0, 16, 16, 32)), (7 * T, 2 * T))
    atlas.save(os.path.join(OUT, "tiles.png"))

    # animated / interactive blocks (nodes, not tiles)
    blocks = [
        ("q0", qblock("#ffffff", "#7a3e08")),
        ("q1", qblock("#fff3c0", "#7a3e08")),
        ("q2", qblock("#ffd98a", "#7a3e08")),
        ("q3", qblock("#fff3c0", "#7a3e08")),
        ("used", parse(QB_BASE, USED_PAL)),
        ("brick", parse(BRICK, BRICK_PAL)),
        ("cave_brick", parse(BRICK, CAVE_BRICK_PAL)),
        ("hard", parse(HARD, HARD_PAL)),
    ]
    sheet, _, _ = strip([im for _, im in blocks], T, T)
    sheet.save(os.path.join(OUT, "blocks.png"))
    order = [n for n, _ in blocks]
    write_spriteframes(os.path.join(OUT, "blocks.tres"), "res://assets/graphics/blocks.png", T, T, order, {
        "question": (["q0", "q0", "q0", "q1", "q2", "q3"], 8, True),
        "used": (["used"], 1, False),
        "brick": (["brick"], 1, False),
        "cave_brick": (["cave_brick"], 1, False),
        "hard": (["hard"], 1, False),
    })

    # moving platform ("lift"): 3-tile orange girder, one sprite
    lift_seg = [
        "LLLLLLLLLLLLLLLL",
        "oobooooooooooboo",
        "oooooooooooooooo",
        "OoooOOOOOOOOoooO",
        "OOOOO......OOOOO",
    ]
    lift_pal = {"L": "#ffd8a0", "o": "#e8872a", "O": "#a8561a", "b": "#fff4c8"}
    lift = parse([r * 3 for r in lift_seg], lift_pal)
    outline(lift, color=OUTLINE, selective=False).save(os.path.join(OUT, "lift.png"))

    # falling platform ('D'): 3-tile cracked sandstone slab
    drop_rows = [
        "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL",
        "lllllllllclllllllllllllllllllllllllllcllllllllll",
        "llslllllccllllllllsllllcllllllllllllcclllllslllll"[:48],
        "SSSSSSSScSSSSSSSSSSSSSccSSSSSSSSSSSSScSSSSSSSSSS",
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD",
        "..rr.......rr........rr.........rr.........rr...",
    ]
    drop_pal = {"L": "#fff0cc", "l": "#e8c88e", "s": "#d0a866", "S": "#b88a52", "D": "#8a5c30",
                "c": "#5a3418", "r": "#8a5c30"}
    outline(parse(drop_rows, drop_pal), color=OUTLINE, selective=False).save(os.path.join(OUT, "drop.png"))

    # tipping plank ('T'): 4-tile wooden board, golden pivot bolt in the middle
    tip_rows = []
    for y, row in enumerate(["LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL",
                             "bbbbbbbbbbbbbbbBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBbbbbbbbbbbbbbbb",
                             "bbbbBbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbBbbbbbb",
                             "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                             "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"]):
        r = list(row)
        if 1 <= y <= 3:
            for x in (30, 31, 32, 33):
                r[x] = "y" if (y == 2 or x in (31, 32)) else "Y"
            r[31] = "w" if y == 1 else r[31]
        for x in (0, 15, 16, 47, 48, 63):
            if y in (1, 2, 3):
                r[x] = "B"
        tip_rows.append("".join(r))
    tip_pal = {"L": "#f8d8a0", "b": "#d8964e", "B": "#a86a30", "D": "#6e4018", "y": "#ffd83c",
               "Y": "#c89018", "w": "#fff8c8"}
    outline(parse(tip_rows, tip_pal), color=OUTLINE, selective=False).save(os.path.join(OUT, "tipper.png"))

    # brick shards (4 frames rotating)
    shard = parse(["lbb.", "bbbB", "bbBB", ".BB."], BRICK_PAL)
    shard = outline(shard, color=OUTLINE, selective=False)
    shards = [shard.rotate(a, expand=False) for a in (0, 90, 180, 270)]
    s, _, _ = strip(shards, 6, 6)
    s.save(os.path.join(OUT, "shard.png"))

    # decorations, packed left to right on one row, index written for Godot
    decos = [
        ("bush_l", outline(parse(BUSH_L, DECOR_PAL), color=OUTLINE, selective=False)),
        ("bush_s", outline(parse([r[:18] for r in BUSH_L[1:]], DECOR_PAL), color=OUTLINE, selective=False)),
        ("flower_a", parse(FLOWER_A, DECOR_PAL)),
        ("flower_b", parse(FLOWER_B, DECOR_PAL)),
        ("flower_c", parse(FLOWER_C, DECOR_PAL)),
        ("tuft", parse(TUFT, DECOR_PAL)),
        ("rock", outline(parse(ROCK, DECOR_PAL), color=OUTLINE, selective=False)),
        ("sign", outline(parse(SIGN, DECOR_PAL), color=OUTLINE, selective=False)),
        ("fence", parse(FENCE, DECOR_PAL)),
        ("castle", castle()),
    ] + biome_decor()
    pole, ball, flag, castle_flag = flag_parts()
    decos += [("pole", pole), ("pole_ball", ball), ("flag", flag), ("castle_flag", castle_flag),
              ("cp_off", checkpoint("#9aa0b0")), ("cp_on", checkpoint("#3cc43c"))]
    wtot = sum(im.size[0] + 1 for _, im in decos)
    htot = max(im.size[1] for _, im in decos)
    dsheet = Image.new("RGBA", (wtot, htot), TRANSPARENT)
    x = 0
    idx = []
    for n, im in decos:
        dsheet.paste(im, (x, 0))
        idx.append((n, x, 0, im.size[0], im.size[1]))
        x += im.size[0] + 1
    dsheet.save(os.path.join(OUT, "decor.png"))
    with open(os.path.join(ROOT, "decor_index.gd"), "w") as fh:
        fh.write("class_name DecorIndex\n\n## Generated by tools/gen_tiles.py — do not edit by hand.\n"
                 "## name -> Rect2 inside res://assets/graphics/decor.png\n\nconst RECTS := {\n")
        for n, x0, y0, w, h in idx:
            fh.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % (n, x0, y0, w, h))
        fh.write("}\n")
    if PREVIEW:
        preview(atlas, 5, path=os.path.join(PREVIEW_DIR, "prev_tiles.png"))
        preview(sheet, 6, path=os.path.join(PREVIEW_DIR, "prev_blocks.png"))
        preview(dsheet, 4, path=os.path.join(PREVIEW_DIR, "prev_decor.png"))
    print("  tiles.png, blocks.png, shard.png, decor.png + decor_index.gd")


if __name__ == "__main__":
    main()
