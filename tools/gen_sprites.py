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
    items()
