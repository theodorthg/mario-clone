#!/usr/bin/env python3
"""Terrain tiles, block sprites, pipes, decorations, flagpole and castle.

    python3 tools/gen_tiles.py [--preview]

tiles.png (16x16 cells, 16 columns) — the TileSet atlas built at runtime by
level.gd (see TILE_* constants there; keep the two in sync):
  row 0  grass ground, variant = neighbour mask (1 up-open, 2 down-open,
         4 left-open, 8 right-open)
  row 1  interior dirt variants 0..3, hard block, log bridge L/M/R,
         cave interior 0..1
  row 2  pipe: top L/R, body L/R, side-mouth top/bottom, side-body top/bottom
  row 3  cave (bonus room) ground, variant = neighbour mask
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


def main():
    os.makedirs(OUT, exist_ok=True)
    atlas = Image.new("RGBA", (16 * T, 4 * T), TRANSPARENT)
    for m in range(16):
        atlas.paste(edge_tile(m, DIRT, GRASS), (m * T, 0))
        atlas.paste(edge_tile(m, CAVE, CAVE_TOP), (m * T, 3 * T))
    for i in range(4):
        atlas.paste(dirt_variant(i), (i * T, T))
    atlas.paste(parse(HARD, HARD_PAL), (4 * T, T))
    atlas.paste(bridge("L"), (5 * T, T))
    atlas.paste(bridge("M"), (6 * T, T))
    atlas.paste(bridge("R"), (7 * T, T))
    atlas.paste(dirt_variant(0, CAVE), (8 * T, T))
    atlas.paste(dirt_variant(1, CAVE), (9 * T, T))
    atlas.paste(parse(BRICK, CAVE_BRICK_PAL), (10 * T, T))
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
    ]
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
