#!/usr/bin/env python3
"""Character + item sprite sheets for mario-clone (all original pixel art).

    python3 tools/gen_sprites.py            # writes assets/graphics/*.png + *.tres
    python3 tools/gen_sprites.py --preview  # also writes upscaled previews to /tmp

Conventions (see CLAUDE.md "Grafik"):
  * every frame of a set is drawn in the SAME grid; feet on the last row.
  * outline() adds one dark pixel all round -> frame = grid + 2.
  * sheets are horizontal strips, one cell per frame; the Godot side sets
    AnimatedSprite2D.offset.y = -cell_h/2 so the node origin is the FEET.
  * facing RIGHT everywhere; the game mirrors with flip_h.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelart import parse, outline, recolor, strip, preview, flip_h  # noqa: E402
from spriteframes import write_spriteframes  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "graphics")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")
OUTLINE = "#1a1018"


def ol(img):
    return outline(img, color=OUTLINE, selective=False)


def pad(rows, w):
    return [r.ljust(w, ".") for r in rows]


def bottom(rows, h, w):
    """drop empty trailing rows, then pad on top to h rows (feet on last row)"""
    rows = list(rows)
    while rows and set(rows[-1]) <= {"."}:
        rows.pop()
    while len(rows) < h:
        rows.insert(0, "." * w)
    if len(rows) > h:
        raise ValueError("frame taller than %d" % h)
    return rows


def save_set(name, frames, cell_w, cell_h, anims, fps_default=10):
    """frames: [(frame_name, PIL image)] ; anims: {anim: ([frame_names], fps, loop)}"""
    order = [n for n, _ in frames]
    sheet, _, _ = strip([im for _, im in frames], cell_w, cell_h)
    png = os.path.join(OUT, name + ".png")
    sheet.save(png)
    write_spriteframes(os.path.join(OUT, name + ".tres"), "res://assets/graphics/%s.png" % name,
                       cell_w, cell_h, order, anims)
    if PREVIEW:
        preview(sheet, 6, path=os.path.join(PREVIEW_DIR, "prev_%s.png" % name))
    print("  %-14s %2d frames  cell %dx%d" % (name, len(frames), cell_w, cell_h))


# =========================================================================
# HERO
# =========================================================================
HERO_PAL = {
    "q": "#ff8a70", "r": "#e0302e", "R": "#a01c2c",
    "h": "#6b3514", "m": "#3d1c0a",
    "s": "#ffcc9a", "S": "#e0925c", "e": "#1b1030",
    "w": "#ffffff", "W": "#c9cfe6",
    "b": "#3868e0", "B": "#20388c", "c": "#7aa6ff",
    "y": "#ffd83c", "n": "#8a4418", "N": "#54260c",
}
# fire power: white cap/shirt, red overalls
FIRE_SWAP = {"#ff8a70": "#ffffff", "#e0302e": "#f4f0e8", "#a01c2c": "#b9b3c9",
             "#3868e0": "#e0302e", "#20388c": "#a01c2c", "#7aa6ff": "#ff8a70"}

SMALL_HEAD = [
    ".....rrrrrr.....",
    "....rqqrrrrrr...",
    "...rrrrrrrrrRRR.",
    "...hhhSsssess...",
    "..hhshSsssesss..",
    "..hhsshsssssSSs.",
    "...hhsssmmmmmm..",
    "....SSsssssss...",
]
SMALL = {}
SMALL["idle"] = SMALL_HEAD + [
    "....RrrrbrR.....",
    "...RRrrbbbrrr...",
    "..wwRrbbybbrww..",
    "..wWbbbbbbbbWw..",
    "...Bbbbbbbbbb...",
    "...BBbb..bbBB...",
    "..nnnn....nnnn..",
    ".NNNNn....nNNNN.",
]
SMALL["walk1"] = SMALL_HEAD + [
    "....RrrrbrrWw...",
    "...RRrrbbbbww...",
    "..RRrbbybbbb....",
    ".wwRbbbbbbbb....",
    ".wWbbbbbbbbbb...",
    "...BBbb...bbbb..",
    "..nnnn.....nnnn.",
    ".NNNN......nNNNN",
]
SMALL["walk2"] = SMALL_HEAD + [
    "....RrrrbrR.....",
    "...RRrrbbbrr....",
    "...Rwwbybbbww...",
    "...wWbbbbbbWw...",
    "....Bbbbbbbbb...",
    "....BBbbbbnnn...",
    "....Bbb..nNNN...",
    "...nnnn.........",
]
SMALL["walk3"] = SMALL_HEAD + [
    "....RrrrbrR.....",
    "...RRrrbbbrr....",
    "...RRrbbybbrr...",
    "...wwbbbbbbww...",
    "...wWbbbbbbWw...",
    ".....BBbbbb.....",
    "....nnnnnnn.....",
    "...NNNNnnNNN....",
]
SMALL["jump"] = [
    ".....rrrrrr..ww.",
    "....rqqrrrrrrww.",
    "...rrrrrrrrrRRW.",
    "...hhhSsssess.r.",
    "..hhshSsssesssr.",
    "..hhsshsssssSSs.",
    "...hhsssmmmmmm..",
    "....SSssssssr...",
    "..wwRrrrbrrrr...",
    "..wWRRrbbbbr....",
    "...RRbbybbbb....",
    "....bbbbbbbbb...",
    "...Bbbbbbbbbnn..",
    "..BBbb...bbnNN..",
    ".nnnn.......N...",
    "NNNN............",
]
SMALL["skid"] = [
    "......rrrrrr....",
    ".....rrrrrrqqr..",
    "...RRRrrrrrrrr..",
    "....sseSssshhh..",
    "..ssseSsssshshh.",
    ".sSSsssssshsshh.",
    "..mmmmmmsssshh..",
    "...sssssssSS....",
    "..wwrbrrrrR.....",
    "..wWbbbrrrRR....",
    "....bbybbrR.....",
    "...bbbbbbbbb....",
    "..bbbbbbbbbbB...",
    ".nnbbb....bBB...",
    "nnNN.....nnnn...",
    "NNN.....NNNNN...",
]
SMALL["death"] = [
    ".ww.rrrrrrrr.ww.",
    ".wWrrqqrrrrrrWw.",
    "..rrrrrrrrrrrr..",
    "..rhhsssssshhr..",
    "..hhseSssSeshh..",
    "..hsssssssssssh.",
    "...ssmmmmmmss...",
    "....smmssmms....",
    ".....ssssss.....",
    "....bRrbbrRb....",
    "...rrbbybybrr...",
    "...rbbbbbbbbr...",
    "....bbbbbbbb....",
    "....BBb..bBB....",
    "...nnnn..nnnn...",
    "..NNNNn..nNNNN..",
]
SMALL["climb"] = [
    ".....rrrrrr.ww..",
    "....rqqrrrrrwW..",
    "...rrrrrrrrrRr..",
    "...hhhSsssesr...",
    "..hhshSsssesr...",
    "..hhsshsssssSs..",
    "...hhsssmmmmm...",
    "....SSssssssrr..",
    "....RrrrbrrrrWw.",
    "...RRrrbbbbrww..",
    "...RRrbbybbb....",
    "....Bbbbbbbbb...",
    "....BBbbbbbbbb..",
    "....BBb...bbnnn.",
    "...nnnn....nNNN.",
    "..NNNNn.........",
]
SMALL["ride"] = SMALL_HEAD + [
    "....RrrrbrR.....",
    "...RRrrbbbrrww..",
    "...RRrbybbbrWw..",
    "....bbbbbbbb....",
    "...bbbbbbbbbbb..",
    "...BBbbbbbbbbnn.",
    "..............nN",
]
SMALL["front"] = [
    ".....rrrrrr.....",
    "...rrrqqrrrrr...",
    "..rrrrrrrrrrrr..",
    "..RRRRRRRRRRRR..",
    "..hsssssssssshh.",
    ".hhseSssssSeshh.",
    ".hssssssssssssh.",
    "..ssmmmmmmmmss..",
    "...smmssssmms...",
    "....ssssssss....",
    "..rrrbRrrRbrrr..",
    ".wrrrbbyybbrrrw.",
    ".wwrbbbbbbbbrww.",
    "...BBbbbbbbBB...",
    "..nnnnb..bnnnn..",
    ".NNNNNn..nNNNNN.",
]

BIG_HEAD = [
    "......rrrrrr....",
    ".....rqqqrrrrr..",
    "....rqqrrrrrrrr.",
    "....rrrrrrrrrRRR",
    "....hhhSsssse...",
    "...hhhhSssseSs..",
    "...hhshhSsssesss",
    "...hhsshSsssssss",
    "....hhsssssSmmmm",
    "....hSssssmmmmm.",
    ".....SSssssssss.",
]
BIG = {}
BIG["idle"] = BIG_HEAD + [
    ".....RRrrrbrr...",
    "....RRrrrrbrrr..",
    "...RRrrrrbbbrrr.",
    "...RRrrbbbbbbrr.",
    "...RRbbybbybbrr.",
    "..wwRbbbbbbbbww.",
    "..wWwbbbbbbbbWw.",
    "..wwWbbbbbbbbww.",
    "....Bbbbbbbbbb..",
    "...BBbbbb.bbbbB.",
    "...BBbbb...bbbB.",
    "...BBbbb...bbbB.",
    "..nnnnnn...nnnnn",
    ".NNNNNNn...nNNNN",
]
BIG["walk1"] = BIG_HEAD + [
    ".....RRrrrbrrww.",
    "....RRrrrrbrrwW.",
    "...RRrrrrbbbrr..",
    "...RRrrbbbbbbb..",
    "...RRbbybbybbb..",
    "..RRRbbbbbbbbb..",
    ".wwRbbbbbbbbbbb.",
    ".wWwbbbbbbbbbbbb",
    ".wwBbbbbbbbbbbbb",
    "...BBbbbb..bbbbb",
    "..BBbbb.....bbbb",
    "..BBbb.......nnn",
    ".nnnnn.......nNN",
    "NNNNNN........N.",
]
BIG["walk2"] = BIG_HEAD + [
    ".....RRrrrbrr...",
    "....RRrrrrbrrr..",
    "...RRrrrrbbbrrr.",
    "...RRrrbbbbbbrr.",
    "...RwwbybbybbWw.",
    "...wWwbbbbbbbww.",
    "...wwbbbbbbbbb..",
    "....Bbbbbbbbbb..",
    "....BBbbbbbbbb..",
    "....BBbbbbbnnn..",
    "....BBbbb.nnNN..",
    "....BBbb...NN...",
    "...nnnnn........",
    "..NNNNNn........",
]
BIG["walk3"] = BIG_HEAD + [
    ".....RRrrrbrr...",
    "....RRrrrrbrrr..",
    "...RRrrrrbbbrrr.",
    "...RRrrbbbbbbrr.",
    "...RRbbybbybbrr.",
    "...wwbbbbbbbbww.",
    "...wWbbbbbbbbWw.",
    "....Bbbbbbbbbb..",
    "....BBbbbbbbbb..",
    ".....BBbbbbbb...",
    ".....BBbbbbb....",
    ".....BBbbbbb....",
    "....nnnnnnnnn...",
    "...NNNNNnnNNNN..",
]
BIG["jump"] = [
    "......rrrrrr..ww",
    ".....rqqqrrrr.wW",
    "....rqqrrrrrrrrw",
    "....rrrrrrrrrRRr",
    "....hhhSsssse.r.",
    "...hhhhSssseSsr.",
    "...hhshhSsssesss",
    "...hhsshSsssssss",
    "....hhsssssSmmmm",
    "....hSssssmmmmm.",
    ".....SSsssssssr.",
    "...wwRRrrrbrrrr.",
    "...wWRRrrrbrrr..",
    "...RRRrrrbbbrr..",
    "....RRrbbbbbbb..",
    "....RBbybbybbb..",
    "....BBbbbbbbbbb.",
    "....BBbbbbbbbbbn",
    "...BBBbbbbbbbnNN",
    "..BBBbb....bnNN.",
    ".BBbbb.......N..",
    ".Bbbb...........",
    "nnnn............",
    "NNNN............",
]
BIG["skid"] = [
    "....rrrrrr......",
    "..rrrrrqqqr.....",
    ".rrrrrrrrqqr....",
    "RRRrrrrrrrrr....",
    "...essssShhh....",
    "..sSeSssshhhh...",
    "sssesssshhshh...",
    "sssssssShsshh...",
    "mmmmSsssssshh...",
    ".mmmmmsssssh....",
    ".sssssssSS......",
    "...rrbrrrRR.....",
    "..rrrbrrrrRR....",
    ".rrrbbbrrrrR....",
    ".rrbbbbbbrrR....",
    ".wwbbybbybRR....",
    ".wWbbbbbbbbww...",
    "..bbbbbbbbbwW...",
    "...bbbbbbbbbB...",
    "...bbbbbbbbBB...",
    "..nnbbbb..bbBB..",
    ".nnNbbb....bBB..",
    "nNNbb......bBB..",
    "NN........nnnnn.",
    "..........NNNNNN",
]
BIG["crouch"] = [
    "......rrrrrr....",
    ".....rqqqrrrrr..",
    "....rrrrrrrrrRRR",
    "....hhhSssseS...",
    "...hhshhSssessss",
    "...hhsshSssssmmm",
    "....hhSsssmmmmm.",
    "....RRSSsssssr..",
    "...RRRrrrbbbrrr.",
    "..wwRrbbybbybww.",
    "..wWbbbbbbbbbWw.",
    ".BBbbbbbbbbbbbb.",
    "BBbbbbbbbbbbbbbB",
    "nnnnnbbbbbbbnnnn",
    "NNNNNN....NNNNNN",
]
BIG["climb"] = BIG_HEAD + [
    ".....RRrrrbrrrWw",
    "....RRrrrrbrrrww",
    "...RRrrrrbbbrr..",
    "...RRrrbbbbbbb..",
    "...RRbbybbybbb..",
    "....Bbbbbbbbbb..",
    "....BBbbbbbbbbb.",
    "....BBbbbbbbbbbb",
    "....BBbbbb..bnnn",
    "....BBbbb...nNNN",
    "....BBbbb.......",
    "....BBbbb.......",
    "...nnnnnn.......",
    "..NNNNNNn.......",
]
BIG["ride"] = BIG_HEAD + [
    ".....RRrrrbrr...",
    "....RRrrrrbrrr..",
    "...RRrrrrbbbrrww",
    "...RRrrbbbbbbrwW",
    "...RRbbybbybbb..",
    "....Bbbbbbbbbb..",
    "...BBbbbbbbbbbbb",
    "...BBbbbbbbbbbbb",
    "....BBbbbbbbbbnn",
    "..............nN",
]
BIG["throw"] = BIG_HEAD + [
    ".....RRrrrbrr...",
    "....RRrrrrbrrrrr",
    "...RRrrrrbbbrrww",
    "...RRrrbbbbbbrwW",
    "...RRbbybbybbb..",
    "..wwRbbbbbbbbb..",
    "..wWwbbbbbbbbb..",
    "..wwBbbbbbbbbb..",
    "....Bbbbbbbbbb..",
    "...BBbbbb.bbbbB.",
    "...BBbbb...bbbB.",
    "...BBbbb...bbbB.",
    "..nnnnnn...nnnnn",
    ".NNNNNNn...nNNNN",
]
BIG["front"] = [
    ".....rrrrrr.....",
    "...rrqqqrrrrr...",
    "..rqqrrrrrrrrr..",
    "..rrrrrrrrrrrr..",
    "..RRRRRRRRRRRR..",
    "..hhsssssssshh..",
    ".hhseSssssSeshh.",
    ".hhseSssssSeshh.",
    ".hsssssssssssh..",
    "..ssmmmmmmmmss..",
    "...smmmssmmms...",
    "....ssssssss....",
    "..RRrrrbbrrrRR..",
    ".RRrrrbbbbrrrRR.",
    ".RRrrbbybbybrRR.",
    "wwRrbbbbbbbbrRww",
    "wWwbbbbbbbbbbwWw",
    "wwwbbbbbbbbbbwww",
    "...Bbbbbbbbbbb..",
    "...BBbbb.bbbBB..",
    "...BBbbb.bbbBB..",
    "...BBbbb.bbbBB..",
    "..nnnnnn.nnnnnn.",
    ".NNNNNNn.nNNNNNN",
]

SMALL_ORDER = ["idle", "walk1", "walk2", "walk3", "jump", "skid", "death", "climb", "ride", "front"]
BIG_ORDER = ["idle", "walk1", "walk2", "walk3", "jump", "skid", "crouch", "climb", "ride", "throw", "front"]
HERO_ANIMS_SMALL = {
    "idle": (["idle"], 1, False),
    "walk": (["walk1", "walk2", "walk3", "walk2"], 12, True),
    "jump": (["jump"], 1, False),
    "fall": (["jump"], 1, False),
    "skid": (["skid"], 1, False),
    "death": (["death"], 1, False),
    "climb": (["climb"], 1, False),
    "ride": (["ride"], 1, False),
    "front": (["front"], 1, False),
    "crouch": (["idle"], 1, False),
    "throw": (["walk1"], 1, False),
}
HERO_ANIMS_BIG = dict(HERO_ANIMS_SMALL)
HERO_ANIMS_BIG.update({
    "crouch": (["crouch"], 1, False),
    "throw": (["throw"], 1, False),
    "death": (["front"], 1, False),
})


def hero():
    small = [(n, ol(parse(bottom(SMALL[n], 16, 16), HERO_PAL, "small." + n))) for n in SMALL_ORDER]
    save_set("hero_small", small, 20, 20, HERO_ANIMS_SMALL)
    big_fill = [(n, parse(bottom(BIG[n], 28, 16), HERO_PAL, "big." + n)) for n in BIG_ORDER]
    save_set("hero_big", [(n, ol(im)) for n, im in big_fill], 20, 32, HERO_ANIMS_BIG)
    save_set("hero_fire", [(n, ol(recolor(im, FIRE_SWAP))) for n, im in big_fill], 20, 32, HERO_ANIMS_BIG)
    # small fire (only used for the shrink/grow flicker between fire and small)
    save_set("hero_small_fire", [(n, ol(recolor(parse(bottom(SMALL[n], 16, 16), HERO_PAL, n), FIRE_SWAP)))
                                 for n in SMALL_ORDER], 20, 20, HERO_ANIMS_SMALL)


# =========================================================================
# DRAGON (rideable dino)
# =========================================================================
DINO_PAL = {
    "g": "#3cc43c", "G": "#1f8a2c", "l": "#9af07e",
    "w": "#ffffff", "W": "#c9d3e6", "e": "#1b1030",
    "r": "#e0302e", "R": "#a01c2c", "q": "#ff8a70",
    "o": "#f79a2a", "O": "#b5570e", "k": "#12521c",
    "p": "#ff6a8a", "P": "#c0305a",
}
DW = 26
DINO_HEAD = pad([
    "...............ww",
    "..............wwww",
    ".............wwwewg",
    "............gwwwewggg",
    "..........oggwwwwgggggg",
    ".........oogllgggggggggggg",
    "..........ollgggggggggggkg",
    ".........ooggggggggggggggg",
    "..........oggggggggggggggg",
    "..........oGgggggggggggggG",
    "...........GGwwwwwGgggggG",
    "...........Gwwwwwwwwwww",
    "............Gwwwwwwww",
], DW)
DINO_HEAD_OPEN = pad([
    "...............ww",
    "..............wwww",
    ".............wwwewg",
    "............gwwwewggg",
    "..........oggwwwwgggggg",
    ".........oogllgggggggggggg",
    "..........ollgggggggggggkg",
    ".........ooggggggggggggggg",
    "..........oGgggggggggggggG",
    "...........GPpppppppppPP",
    "...........GPPpppppppp",
    "...........Gwwwwwwwwwwww",
    "............Gwwwwwwwww",
], DW)
DINO_BLINK = pad([
    "...............ww",
    "..............wwww",
    ".............gggggg",
    "............gGGGGGggg",
    "..........oggggggggggg",
] , DW) + DINO_HEAD[5:]
DINO_TORSO = pad([
    ".....wwwwww.Gggwwww",
    "....wrrrrrrwGggwwwgg",
    "...wrqqrrrrrwggwwwgG",
    "...wrrrrrrrrwggwwww",
    "..GRRRRRRRRRRggwwww",
    ".Gggggggggggggwwwww",
    "GGgggggggggggwwwwww",
    ".GGggggggggggwwwwww",
    "..GGGggggggggwwwww",
    "....GGGgggggGwwwW",
], DW)
DINO_LEGS = {
    "stand": pad([
        "....GGgg....Gggg",
        "....GGgg....Gggg",
        "...oooooo...oooooo",
        "..oooooooo.oooooooo",
        "..OOOOOOOO.OOOOOOOO",
    ], DW),
    "walk1": pad([
        "...GGgg......Gggg",
        "..GGgg........Gggg",
        ".oooooo........oooooo",
        "oooooooo......oooooooo",
        "OOOOOOOO......OOOOOOOO",
    ], DW),
    "walk2": pad([
        ".....GGgggGggg",
        "......GGggggg",
        ".....oooooooo",
        "....oooooooooo",
        "....OOOOOOOOOO",
    ], DW),
    "walk3": pad([
        "......Gggg.GGg",
        ".....Gggg...GGg",
        "....oooooo.ooooo",
        "...oooooooooooooo",
        "...OOOOOOOOOOOOOO",
    ], DW),
    "jump": pad([
        "..GGgg.......Ggggoo",
        ".GGgg..........ooooo",
        "oooooo..........OOOO",
        "ooooooo.............",
        "OOOOOOO.............",
    ], DW),
}


def dino_frame(legs, head=DINO_HEAD):
    return head + DINO_TORSO + DINO_LEGS[legs]


EGG_PAL = {"w": "#ffffff", "W": "#d2dbe8", "V": "#98a4ba", "g": "#3cc43c", "G": "#1f8a2c", "l": "#9af07e"}
EGG = {
    "egg": [
        "....wwww....",
        "...wwwwww...",
        "..wwwgglww..",
        "..wwwggGww..",
        ".wgwwwwwwww.",
        ".wgGwwwwggw.",
        ".wwwwwwwgGW.",
        ".wwwwgwwwwW.",
        ".wwwwgGwwwW.",
        "..wwwwwwWW..",
        "..WWwwwWWV..",
        "....VVVV....",
    ],
    "crack": [
        "....wwww....",
        "...wwwwww...",
        "..wwwgglww..",
        "..wwVggGww..",
        ".wgwVwwwwww.",
        ".wgGwVVwggw.",
        ".wwwwwwVgGW.",
        ".wwwwgwwVVW.",
        ".wwwwgGwwwW.",
        "..wwwwwwWW..",
        "..WWwwwWWV..",
        "....VVVV....",
    ],
    "shell": [
        "............",
        "............",
        "............",
        "............",
        "............",
        "............",
        ".w........w.",
        ".ww.w..w.wW.",
        ".wwwwgwwwwW.",
        "..wwwwwwWW..",
        "..WWwwwWWV..",
        "....VVVV....",
    ],
}


def dino():
    frames = [
        ("stand", dino_frame("stand")),
        ("walk1", dino_frame("walk1")),
        ("walk2", dino_frame("walk2")),
        ("walk3", dino_frame("walk3")),
        ("jump", dino_frame("jump")),
        ("eat", dino_frame("stand", DINO_HEAD_OPEN)),
        ("eat_walk", dino_frame("walk1", DINO_HEAD_OPEN)),
        ("blink", dino_frame("stand", DINO_BLINK)),
    ]
    imgs = [(n, ol(parse(f, DINO_PAL, "dino." + n))) for n, f in frames]
    save_set("dino", imgs, 28, 32, {
        "idle": (["stand", "stand", "stand", "stand", "stand", "blink"], 4, True),
        "walk": (["walk1", "walk2", "walk3", "walk2"], 10, True),
        "run": (["walk1", "walk2", "walk3", "walk2"], 16, True),
        "jump": (["jump"], 1, False),
        "eat": (["eat"], 1, False),
        "eat_walk": (["eat_walk"], 1, False),
    })
    eggs = [(n, ol(parse(EGG[n], EGG_PAL, "egg." + n))) for n in ["egg", "crack", "shell"]]
    save_set("egg", eggs, 16, 16, {
        "idle": (["egg"], 1, False),
        "crack": (["egg", "crack", "egg", "crack", "crack"], 8, False),
        "shell": (["shell"], 1, False),
    })


# =========================================================================
# ENEMY: angry walking mushroom ("Stompling")
# =========================================================================
SHROOM_PAL = {
    "c": "#b8612a", "C": "#7c3a18", "h": "#e89a52", "H": "#ffd08a",
    "f": "#f6dcae", "F": "#d4a878", "e": "#1b1030", "w": "#ffffff",
    "B": "#2a1408", "d": "#4a2a14", "D": "#2a160a", "t": "#ffffff",
}
SHROOM = {
    "walk1": [
        "......hhhh......",
        "....hhHHcccc....",
        "...hHHccccccC...",
        "..hccccccccccC..",
        ".hcBBccccccBBcC.",
        ".ccwBBccccBBwcC.",
        "ccwweBccccBewwcC",
        "ccwwe.cccc.ewwcC",
        "Ccccccccccccccc.",
        ".CCffffffffffCC.",
        "...ftffffftfF...",
        "...ffffffffFF...",
        "..dddFfffFF.....",
        ".dddddd..dddd...",
        ".DDDDD..ddddddd.",
    ],
    "walk2": [
        "......hhhh......",
        "....hhHHcccc....",
        "...hHHccccccC...",
        "..hccccccccccC..",
        ".hcBBccccccBBcC.",
        ".ccwBBccccBBwcC.",
        "ccwweBccccBewwcC",
        "ccwwe.cccc.ewwcC",
        "Ccccccccccccccc.",
        ".CCffffffffffCC.",
        "...ftffffftfF...",
        "...ffffffffFF...",
        ".....FffFFddd...",
        "...dddd..dddddd.",
        ".ddddddd..DDDDD.",
    ],
    "squish": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "......hhhh......",
        "...hhHHccccccC..",
        ".hHccccccccccccC",
        "cccBBBccccBBBccC",
        "CccwwBccccBwwccC",
        ".CCffffffffffCC.",
        ".dddffffffffddd.",
        "DDDDD......DDDDD",
    ],
}


WING_PAL = {"w": "#ffffff", "W": "#c9d3e6", "V": "#8f9ab4"}
WING_UP = [
    "w....",
    "ww...",
    "wWw..",
    "wWWw.",
    ".wWWw",
    "..wVw",
]
WING_DOWN = [
    ".....",
    ".....",
    "..wVw",
    ".wWWw",
    "wWWw.",
    "ww...",
]


def winged(frame_rows, wing):
    """shroom fill (16 wide) on a 24-wide canvas with a wing on each side"""
    from PIL import Image as _I
    body = parse(frame_rows, SHROOM_PAL)
    canvas = _I.new("RGBA", (24, body.height), (0, 0, 0, 0))
    canvas.paste(body, (4, 0), body)
    wr = parse(wing, WING_PAL)
    canvas.paste(wr.transpose(_I.FLIP_LEFT_RIGHT), (0, 1), wr.transpose(_I.FLIP_LEFT_RIGHT))
    canvas.paste(wr, (19, 1), wr)
    return canvas


CHOMP_PAL = {
    "r": "#e0302e", "R": "#a01c2c", "w": "#ffffff", "m": "#4a0a16", "t": "#f4f0e8",
    "g": "#3cc43c", "G": "#1f8a2c", "l": "#9af07e",
}
CHOMP_STEM = [
    ".......gG.......",
    "..ll...gG...ll..",
    ".lggl..gG..lggl.",
    "..lggl.gG.lggl..",
    "...lgggGgggl....",
    ".......gG.......",
    ".......gG.......",
    ".......gG.......",
    ".......gG.......",
]
CHOMP_OPEN = [
    "...rrrrrrrrrr...",
    "..rrwrrrrrrwrr..",
    ".rrrrrrwwrrrrrr.",
    ".rwrrrrrrrrrrwr.",
    "rrrrrrrrrrrrrrrr",
    "RRRRRRRRRRRRRRRR",
    "RtmtmtmtmtmtmtmR",
    "RmmmmmmmmmmmmmmR",
    "RmmmmmmmmmmmmmmR",
    "RmtmtmtmtmtmtmtR",
    "RRRRRRRRRRRRRRRR",
    "rrrrrrrrrrrrrrrr",
    ".rrwrrrrrrrwrrr.",
    "..rrrrrrrrrrrr..",
    "....rrrrrrrr....",
]
CHOMP_SHUT = [
    "................",
    "................",
    "...rrrrrrrrrr...",
    "..rrwrrrrrrwrr..",
    ".rrrrrrwwrrrrrr.",
    ".rwrrrrrrrrrrwr.",
    "rrrrrrrrrrrrrrrr",
    "RtRtRtRtRtRtRtRR",
    "RRRRRRRRRRRRRRRR",
    "rrrrrrrrrrrrrrrr",
    "rrrrrrrrrrrrrrrr",
    ".rrwrrrrrrrwrrr.",
    "..rrrrrrrrrrrr..",
    "....rrrrrrrr....",
    "................",
]


def enemies():
    frames = [(n, ol(parse(SHROOM[n], SHROOM_PAL, "shroom." + n))) for n in ["walk1", "walk2", "squish"]]
    frames.append(("fly1", ol(winged(SHROOM["walk1"], WING_UP))))
    frames.append(("fly2", ol(winged(SHROOM["walk2"], WING_DOWN))))
    save_set("enemy_shroom", frames, 26, 18, {
        "walk": (["walk1", "walk2"], 6, True),
        "squish": (["squish"], 1, False),
        "flipped": (["walk1"], 1, False),
        "fly": (["fly1", "fly2"], 8, True),
    })
    chomp = [("open", ol(parse(CHOMP_OPEN + CHOMP_STEM, CHOMP_PAL, "chomp.open"))),
             ("shut", ol(parse(CHOMP_SHUT + CHOMP_STEM, CHOMP_PAL, "chomp.shut")))]
    save_set("chomper", chomp, 18, 26, {"chomp": (["open", "shut"], 5, True)})


# =========================================================================
# TURTLES — walker (facing right), shell (4 spin frames), peek, winged
# =========================================================================
TURTLE_PAL = {
    "y": "#ffd84a", "Y": "#d49a1c", "o": "#8a4a10", "t": "#ffffff", "e": "#1b1030",
    "g": "#3cc43c", "G": "#1f8a2c", "l": "#9af07e", "w": "#fff4d8", "W": "#d8c090",
    "b": "#f07830", "B": "#b04818", "m": "#2a1a10",
}
RED_SWAP = {"#3cc43c": "#e8402e", "#1f8a2c": "#a8202a", "#9af07e": "#ff9a7a"}
TURTLE_TOP = [
    "..........yyyy..",
    ".........yyyyyy.",
    ".........yyyytty",
    "........yyyyytey",
    "........yyyyytey",
    "........Yyyyyyyy",
    "........YYyyyyoy",
    ".........YYyyyy.",
    "..........YYyy..",
    "....ggggg..Yyy..",
    "...gllggggGyyy..",
    "..gllgGGgggGyy..",
    ".gllgGggGggGyyY.",
    ".glgGggggGgGyyYY",
    ".gggGggggGGgyyY.",
    ".ggggGGGGggGyy..",
    ".GgggggggggGYy..",
    ".wwwwwwwwwwwwY..",
    "..WWWWWWWWWWy...",
]
TURTLE_LEGS = {
    "walk1": [
        "...yyY....yyY...",
        "...yyY....yyY...",
        "..bbbb...bbbb...",
        ".bbbbbB.bbbbbB..",
        ".BBBBBB.BBBBBB..",
    ],
    "walk2": [
        "....yyY..yyY....",
        "....yyY..yyY....",
        "...bbbb.bbbb....",
        "..bbbbbBbbbbbB..",
        "..BBBBBBBBBBBB..",
    ],
}
SHELL_ROWS = [(4, 11), (2, 13), (1, 14), (1, 14), (0, 15), (0, 15), (0, 15)]


def shell_rows(off, peek=False):
    """side view of the shell (16x10); `off` shifts the plate seams -> spin"""
    rows = []
    for y, (a, b) in enumerate(SHELL_ROWS):
        r = ""
        for x in range(16):
            if x < a or x > b:
                r += "."
            elif x == a or x == b or y == 6:
                r += "G"
            elif (y == 3) or (y < 3 and (x + off) % 8 == 0) or (y > 3 and (x + off + 4) % 8 == 0):
                r += "G"
            elif x + y * 1.6 < 8 and y < 3:
                r += "l"
            else:
                r += "g"
        rows.append(r)
    rows.append("wwwwwwwwwwwwwwww" if not peek else "wwwwmmmmmmmmwwww")
    rows.append("WwwwwwwwwwwwwwwW" if not peek else "Wwwwmtemmtemwwww")
    rows.append(".WWWWWWWWWWWWWW.")
    return rows


def turtle_frames(swap=None):
    def img(rows):
        im = parse(rows, TURTLE_PAL, "turtle")
        return recolor(im, swap) if swap else im
    from PIL import Image as _I
    frames = []
    walk = {}
    for n in ["walk1", "walk2"]:
        walk[n] = img(TURTLE_TOP + TURTLE_LEGS[n])
        frames.append((n, ol(walk[n])))
    for i in range(4):
        frames.append(("shell%d" % i, ol(img(shell_rows(i * 2)))))
    frames.append(("peek", ol(img(shell_rows(0, True)))))
    # winged: wing on the shell's back (left), canvas kept symmetric (26 wide)
    for n, wing in [("fly1", WING_UP), ("fly2", WING_DOWN)]:
        body = walk["walk1" if n == "fly1" else "walk2"]
        canvas = _I.new("RGBA", (26, body.height), (0, 0, 0, 0))
        canvas.paste(body, (5, 0), body)
        wr = parse(wing, WING_PAL).transpose(_I.FLIP_LEFT_RIGHT)
        canvas.paste(wr, (2, 9), wr)
        frames.append((n, ol(canvas)))
    return frames


TURTLE_ANIMS = {
    "walk": (["walk1", "walk2"], 6, True),
    "fly": (["fly1", "fly2"], 8, True),
    "shell": (["shell0"], 1, False),
    "spin": (["shell0", "shell1", "shell2", "shell3"], 18, True),
    "peek": (["peek", "shell0"], 8, True),
    "flipped": (["shell0"], 1, False),
}


def turtles():
    save_set("enemy_turtle", turtle_frames(), 28, 26, TURTLE_ANIMS)
    save_set("enemy_turtle_red", turtle_frames(RED_SWAP), 28, 26, TURTLE_ANIMS)


# =========================================================================
# BIOME ENEMIES — cave bat, desert cactus stack, snow penguin
# =========================================================================
BAT_PAL = {"k": "#3a2a5a", "b": "#6a4a9a", "B": "#4a3278", "r": "#ff4a4a", "t": "#ffffff"}
BAT = {
    "fly1": ["b..............b", "bb....k..k....bb", "bBb...kkkk...bBb", "bBBb.kkkkkk.bBBb",
             ".bBBbkrkkrkbBBb.", "..bBBkkkkkkBBb..", "...bbkktkkkbb...", ".....kkkkkk.....",
             "......kkkk......", "................"],
    "fly2": ["................", "......k..k......", "......kkkk......", ".....kkkkkk.....",
             "....bkrkkrkb....", "..bbBkkkkkkBbb..", ".bBBbkktkkkbBBb.", "bBBb.kkkkkk.bBBb",
             "bBb...kkkk...bBb", "bb............bb"],
    "hang": ["......k..k......", "......kkkk......", ".....bkkkkb.....", "....bBkkkkBb....",
             "....bBkkkkBb....", "....bBkBBkBb....", ".....bkkkkb.....", "......kttk......",
             ".......kk.......", "................"],
}
PENGUIN_PAL = {"k": "#1e2a48", "w": "#ffffff", "e": "#1b1030", "o": "#ff9a2a"}
PENGUIN_TOP = [
    "....kkkkk.....", "...kkkkkkk....", "..kkkkkwwkk...", "..kkkkkwekoo..", "..kkkkkkkkoo..",
    "..kkkkwwwwkk..", ".kkkkwwwwwwk..", "kkkkwwwwwwwk..", "kkkkwwwwwwwk..", ".kkkwwwwwwwk..",
    "..kkwwwwwwk...", "..kkkwwwwwk...", "...kkkkkkk....",
]
PENGUIN = {
    "walk1": PENGUIN_TOP + ["..oo....oo...."],
    "walk2": PENGUIN_TOP + ["...oo..oo....."],
    "slide": ["..........kkk...", "...kkkkkkkkkkwk.", ".kkkkkkkkkkkkeoo", "kkwwwwwwwwwwkkk.",
              ".wwwwwwwwwwwwk..", "..oo............"],
    "squish": ["..kkkkkkkkkk..", ".kkkkwwwwkkoo.", "kkwwwwwwwwwwk.", ".oo.......oo.."],
}
CACTUS_PAL = {"L": "#b0e67a", "g": "#5aa83c", "G": "#3a7a2a", "t": "#fff4c8", "e": "#1b1030",
              "w": "#ffffff", "p": "#ff6ab0", "y": "#ffd83c", "m": "#2a4a1a"}


def cactus_ball(head=False):
    rows = []
    for y in range(12):
        r = ""
        for x in range(14):
            dx, dy = (x - 6.5) / 7.0, (y - 5.5) / 6.0
            d = dx * dx + dy * dy
            if d > 1.0:
                r += "."
            elif (x + y * 2) % 5 == 0 and d > 0.55:
                r += "t"
            elif dx + dy < -0.5:
                r += "L"
            elif dx + dy > 0.6:
                r += "G"
            else:
                r += "g"
        rows.append(r)
    if head:
        for x, y, ch in ((4, 4, "w"), (4, 5, "e"), (8, 4, "w"), (8, 5, "e"), (5, 8, "m"), (6, 8, "m"), (7, 8, "m")):
            rows[y] = rows[y][:x] + ch + rows[y][x + 1:]
        top = ["......pp......", ".....pyyp.....", "......pp......"]
        rows = top + rows
    return rows


def biome_enemies():
    bat = [(n, ol(parse(BAT[n], BAT_PAL, "bat." + n))) for n in ["hang", "fly1", "fly2"]]
    save_set("enemy_bat", bat, 18, 12, {"hang": (["hang"], 1, False), "fly": (["fly1", "fly2"], 10, True),
                                        "flipped": (["fly1"], 1, False)})
    pen = [(n, ol(parse(PENGUIN[n], PENGUIN_PAL, "penguin." + n))) for n in ["walk1", "walk2", "slide", "squish"]]
    save_set("enemy_penguin", pen, 18, 18, {"walk": (["walk1", "walk2"], 8, True), "slide": (["slide"], 1, False),
                                            "squish": (["squish"], 1, False), "flipped": (["walk1"], 1, False),
                                            "fly": (["walk1"], 1, False)})
    cac = [("seg", ol(parse(cactus_ball(), CACTUS_PAL, "cactus"))), ("head", ol(parse(cactus_ball(True), CACTUS_PAL, "cactus.h")))]
    save_set("enemy_cactus", cac, 16, 17, {"seg": (["seg"], 1, False), "head": (["head"], 1, False)})


# =========================================================================
# BOSS — horned dragon-ogre king (own design), built from shapes + details
# =========================================================================
BOSS_PAL = {
    "b": "#8a4ac0", "B": "#5a2a88", "l": "#b27ae0",       # skin
    "c": "#f4d8a0", "C": "#c8a060",                        # belly plate
    "h": "#f4ecd8", "H": "#b8ae98",                        # horns, spikes, claws
    "y": "#ffd83c", "Y": "#d09018",                        # crown
    "e": "#ffffff", "p": "#d01818", "m": "#3a0a14", "t": "#ffffff",
}
BOSS_WORLD_SWAP = {
    1: {"#8a4ac0": "#4aa84a", "#5a2a88": "#2a6a30", "#b27ae0": "#86d86a"},   # green
    2: {},                                                                      # purple
    3: {"#8a4ac0": "#d86a2a", "#5a2a88": "#8a3414", "#b27ae0": "#f4a060"},   # orange
    4: {"#8a4ac0": "#3a78c8", "#5a2a88": "#1e4488", "#b27ae0": "#7ab4f0"},   # blue
}
BW, BH = 30, 32


def _boss_canvas(legs=0, mouth=False, crouch=0):
    g = [["."] * BW for _ in range(BH)]

    def put(x, y, ch):
        if 0 <= x < BW and 0 <= y < BH:
            g[y][x] = ch

    def ell(cx, cy, rx, ry, fill, shade=True):
        for y in range(BH):
            for x in range(BW):
                dx, dy = (x - cx) / rx, (y - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    ch = fill
                    if shade and fill == "b":
                        if dx + dy < -0.9:
                            ch = "l"
                        elif dx + dy > 0.8:
                            ch = "B"
                    put(x, y, ch)
    oy = crouch
    # tail
    for i in range(7):
        for k in range(3 - i // 3):
            put(5 - i, 22 + oy + i // 2 + k, "b" if k else "B")
    # legs (behind body)
    for lx, dy in ((9, legs), (17, -legs)):
        for y in range(24 + oy, 30 + min(0, dy)):
            for x in range(lx, lx + 5):
                put(x, y, "B" if x == lx + 4 else "b")
        for x in range(lx - 1, lx + 6):
            put(x, 30 + min(0, dy), "h" if x % 2 == 0 else "H")
        for x in range(lx - 1, lx + 6):
            put(x, 31 + min(0, dy), "H")
    # body + belly
    ell(13, 19 + oy, 10, 8, "b")
    ell(16, 21 + oy, 5.5, 5.5, "c", False)
    for y in range(17 + oy, 27 + oy):
        if (y - oy) % 3 == 0:
            for x in range(12, 21):
                if g[y][x] == "c":
                    g[y][x] = "C"
    # back spikes
    for sx, sy in ((5, 14), (8, 11), (12, 10)):
        for k in range(3):
            put(sx - 1 + k, sy + oy, "h")
        put(sx, sy - 1 + oy, "h")
        put(sx, sy - 2 + oy, "H")
    # head
    ell(21, 9 + oy, 7, 6, "b")
    # jaw + teeth
    jaw_y = 12 + oy
    if mouth:
        for y in range(jaw_y, jaw_y + 4):
            for x in range(20, 29):
                put(x, y, "m")
        for x in range(21, 29, 2):
            put(x, jaw_y, "t")
            put(x, jaw_y + 3, "t")
        for x in range(19, 29):
            put(x, jaw_y + 4, "b")
            put(x, jaw_y + 5, "B")
    else:
        for x in range(21, 29):
            put(x, jaw_y, "m")
        for x in range(22, 29, 2):
            put(x, jaw_y - 1, "t")
            put(x, jaw_y + 1, "t")
        for x in range(19, 28):
            put(x, jaw_y + 2, "b")
            put(x, jaw_y + 3, "B")
    # snout nostril
    put(27, 8 + oy, "B")
    # eye (angry brow)
    for x, y, ch in ((22, 7, "e"), (23, 7, "e"), (22, 8, "e"), (23, 8, "p"), (21, 6, "B"), (22, 6, "B"), (23, 5, "B")):
        put(x, y + oy, ch)
    # horns
    for i, (x, y) in enumerate(((16, 4), (15, 3), (14, 2), (14, 1), (13, 0))):
        put(x, y + oy, "h" if i < 4 else "H")
        put(x + 1, y + oy, "H")
    for i, (x, y) in enumerate(((25, 4), (26, 3), (27, 2), (27, 1), (28, 0))):
        put(x, y + oy, "h")
        put(x - 1, y + oy, "H")
    # crown
    for x in range(18, 24):
        put(x, 3 + oy, "y")
        put(x, 2 + oy, "Y" if x % 2 else "y")
    for x in (18, 20, 22):
        put(x, 1 + oy, "y")
    # arm with claws
    ell(21, 18 + oy, 3, 2.5, "b")
    for x in (23, 24, 25):
        put(x, 19 + oy, "h")
    return ["".join(r) for r in g]


FLAME = [
    "....yyyrr.......",
    "..yyfffyyrrr....",
    ".yfffwwffyyrrrr.",
    "yffwwwwwfffyyrrr",
    ".yfffwwffyyrrrr.",
    "..yyfffyyrrr....",
    "....yyyrr.......",
]
FLAME_PAL = {"w": "#fffbe0", "f": "#ffd84a", "y": "#ff9a2a", "r": "#e03a1a"}
BUBBLE = [
    "....rrrr....",
    "..rryyyyrr..",
    ".ryyffffyyr.",
    ".ryfwwwwfyr.",
    "ryfwewwewfyr",
    "ryfwewwewfyr",
    "ryffwwwwffyr",
    "ryyffffffyyr",
    ".ryyyyyyyyr.",
    ".rryyyyyyrr.",
    "..rrryyrrr..",
    "...rr..rr...",
]
BUBBLE_PAL = {"w": "#fffbe0", "f": "#ffd84a", "y": "#ff8a1a", "r": "#c82a14", "e": "#3a0a14"}


def boss():
    frames_def = [("walk1", dict(legs=1)), ("walk2", dict(legs=-1)), ("roar", dict(mouth=True)),
                  ("jump", dict(legs=-2, crouch=0))]
    for w, swap in BOSS_WORLD_SWAP.items():
        frames = []
        for n, kw in frames_def:
            im = parse(_boss_canvas(**kw), BOSS_PAL, "boss." + n)
            frames.append((n, ol(recolor(im, swap) if swap else im)))
        save_set("boss_%d" % w, frames, BW + 2, BH + 2, {
            "walk": (["walk1", "walk2"], 5, True),
            "roar": (["roar"], 1, False),
            "jump": (["jump"], 1, False),
        })
    fl = ol(parse(FLAME, FLAME_PAL, "flame"))
    fl2 = ol(parse([r[::-1][::-1] for r in FLAME[1:] + FLAME[:1]], FLAME_PAL, "flame2"))
    save_set("boss_flame", [("f0", fl), ("f1", fl2)], 18, 9, {"burn": (["f0", "f1"], 10, True)})
    b = ol(parse(BUBBLE, BUBBLE_PAL, "bubble"))
    save_set("lava_bubble", [("b0", b)], 14, 14, {"idle": (["b0"], 1, False)})


# =========================================================================
# ITEMS
# =========================================================================
COIN_PAL = {"y": "#ffd83c", "Y": "#e09a18", "o": "#a8600c", "w": "#fff8c0", "l": "#ffea80"}
COIN = {
    "c0": [
        "...yyyy...",
        "..ywwlyY..",
        ".ywlyyyYY.",
        ".wlyoyyyY.",
        "ywlyoyyyYY",
        "ylyyoyyyYY",
        "ylyyoyyyYY",
        "ylyyoyyyYY",
        "ylyyoyyyYY",
        "yyyyoyyyYY",
        ".yyyoyyYY.",
        ".yyyyyyYY.",
        "..yyyyYY..",
        "...YYYY...",
    ],
    "c1": [
        "....yyY...",
        "...ywyY...",
        "...wlyYY..",
        "..ywyoyY..",
        "..wlyoyY..",
        "..ylyoyY..",
        "..ylyoyY..",
        "..ylyoyY..",
        "..ylyoyY..",
        "..yyyoyY..",
        "..yyyyYY..",
        "...yyyY...",
        "...yyYY...",
        "....YY....",
    ],
    "c2": [
        "....yY....",
        "....wY....",
        "....lY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....yY....",
        "....YY....",
    ],
}
ITEM_PAL = {
    "r": "#e0302e", "R": "#a01c2c", "q": "#ff8a70", "w": "#ffffff", "W": "#d2d6e8",
    "f": "#f6dcae", "F": "#d4a878", "e": "#1b1030",
    "g": "#3cc43c", "G": "#1f8a2c", "l": "#9af07e",
    "y": "#ffd83c", "Y": "#e09a18", "o": "#f79a2a", "O": "#c0501a",
}
MUSHROOM = [
    ".....rrrrrr.....",
    "...rrwwwwrrrr...",
    "..rrwwwwwwrqrr..",
    ".rrrwwwwwwrrrrr.",
    ".rwwrwwwwrrrwwR.",
    "rwwwwrrrrrrwwwwR",
    "rwwwwrrrrrrwwwwR",
    "rrwwrrrrrrrrwwRR",
    "RRRRRRRRRRRRRRRR",
    "..fffffffffffF..",
    ".ffffewffwefffF.",
    ".ffffewffwefffF.",
    ".fffffffffffffF.",
    "..ffffffffffFF..",
    "...FFFFFFFFFF...",
]
ONEUP_SWAP = {"#e0302e": "#3cc43c", "#a01c2c": "#1f8a2c", "#ff8a70": "#9af07e"}
FLOWER = [
    "....oooooooo....",
    "..ooyyyyyyyyoo..",
    ".oyywwwwwwwwyyo.",
    "oyywwewwwwewwyyo",
    "oyywwewwwwewwyyo",
    ".oyywwwwwwwwyyo.",
    "..ooyyyyyyyyoo..",
    "....oooooooo....",
    ".......gG.......",
    ".ll....gG....ll.",
    "lggl...gG...lggl",
    ".lggl..gG..lggl.",
    "..lgggggGgggGl..",
    "...lGGGgGGGGl...",
    ".....GGgGGG.....",
]
FLOWER_CYCLE = [
    {},
    {"#f79a2a": "#e0302e", "#ffd83c": "#ff8a70"},
    {"#f79a2a": "#ffd83c", "#ffd83c": "#ffffff"},
    {"#f79a2a": "#ff8a70", "#ffd83c": "#ffd83c"},
]
STAR = [
    ".......yy.......",
    "......yyyy......",
    "......yyyy......",
    ".....yyyyyy.....",
    "yyyyyyyyyyyyyyyy",
    ".yyyyyyyyyyyyyy.",
    "..yyyyeyyeyyyy..",
    "...yyyeyyeyyy...",
    "....yyyyyyyy....",
    "...yyyyyyyyyy...",
    "...yyyyYYyyyy...",
    "..yyyyY..Yyyyy..",
    "..yyyY....Yyyy..",
    ".yyY........Yyy.",
    ".yY..........Yy.",
]
STAR_CYCLE = [
    {},
    {"#ffd83c": "#f79a2a", "#e09a18": "#c0501a"},
    {"#ffd83c": "#ffffff", "#e09a18": "#d2d6e8"},
    {"#ffd83c": "#ffea80", "#e09a18": "#ffd83c"},
]
FIREBALL = {
    "f0": ["..oo..", ".oyyo.", "oywyyo", "oyyyyo", ".oyyo.", "..oo.."],
    "f1": ["..o...", ".oyoo.", "oyywyo", ".oyyyo", ".ooyo.", "...o.."],
}


def items():
    coin_frames = [(n, ol(parse(COIN[n], COIN_PAL, "coin." + n))) for n in ["c0", "c1", "c2"]]
    coin_frames.append(("c3", flip_h(coin_frames[1][1])))
    save_set("coin", coin_frames, 12, 16, {
        "spin": (["c0", "c0", "c1", "c2", "c3"], 8, True),
        "fast": (["c0", "c1", "c2", "c3"], 20, True),
    })
    m = parse(MUSHROOM, ITEM_PAL, "mushroom")
    fl = parse(FLOWER, ITEM_PAL, "flower")
    st = parse(STAR, ITEM_PAL, "star")
    frames = [("mushroom", ol(m)), ("oneup", ol(recolor(m, ONEUP_SWAP)))]
    for i, sw in enumerate(FLOWER_CYCLE):
        frames.append(("flower%d" % i, ol(recolor(fl, sw))))
    for i, sw in enumerate(STAR_CYCLE):
        frames.append(("star%d" % i, ol(recolor(st, sw))))
    save_set("powerups", frames, 18, 17, {
        "mushroom": (["mushroom"], 1, False),
        "oneup": (["oneup"], 1, False),
        "flower": (["flower0", "flower1", "flower2", "flower3"], 10, True),
        "star": (["star0", "star1", "star2", "star3"], 14, True),
    })
    fb = [(n, ol(parse(FIREBALL[n], ITEM_PAL, "fb." + n))) for n in ["f0", "f1"]]
    fb += [("f2", fb[0][1].rotate(90)), ("f3", fb[1][1].rotate(90))]
    save_set("fireball", fb, 8, 8, {"spin": (["f0", "f1", "f2", "f3"], 16, True)})


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    hero()
    dino()
    enemies()
    turtles()
    biome_enemies()
    boss()
    items()
