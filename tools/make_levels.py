#!/usr/bin/env python3
"""Level authoring for mario-clone.

    python3 tools/make_levels.py [--preview]

Levels are BUILT here with small helper calls (ground, pipe, blocks, coin
arcs, enemies, ...) and EMITTED as levels/level_<id>.gd — a plain GDScript
file holding the ASCII grid plus metadata (start, flag, warps, areas). The
ASCII grid is what level.gd reads; it stays human-readable in the repo.
--preview additionally renders each level to a PNG using the real tiles and
sprites so the whole layout can be checked at a glance.

Grid legend (one char per 16x16 cell, row 0 = top):
  .  empty            #  grass ground (autotiled)   c  cave ground (autotiled)
  X  hard block       w  cave wall brick (solid)    =  log bridge (one-way)
  B  brick            ?  ?-block (coin)             M  ?-block (power-up)
  Y  ?-block (dragon egg)  S brick (star)  C brick (10 coins)  U brick (1-UP)
  h  hidden 1-UP block   v  water (no collision, drawn in front)
  P  pipe top-left (body extends down to the next solid cell)
  W  warp pipe top-left (enterable, see WARPS)
  >  side pipe mouth (top cell, 2 high; body extends right)
  o  coin             g  walking mushroom enemy   G  winged (hopping) one
  Q  pipe top-left with a biting plant inside
  k  green shell turtle (walks off ledges)   K  red one (turns at ledges)
  J  winged green turtle (hops)
  I  ice block (solid, slippery)            L  lava (no collision, drawn in front)
  F  hard block with a rotating fire bar     b  lava bubble (in a lava pit's top row)
  Z  castle boss (arena = Level.arena)     N  ?-block that always holds a fire flower
  a  cave bat (hangs under the ceiling)      p  desert cactus stack (spiky)
  q  snow penguin (walks, belly-slides)
  ~  3-tile lift moving sideways (4 tiles)   ^  3-tile lift moving up (4.5 tiles)
  D  3-tile falling slab (drops after standing on it, comes back)
  T  4-tile tipping plank (pivot in its middle; tips toward the heavy side)
     (lifts/slabs/planks: top-left at the cell; one-way from below; not
     part of surface())
  u  cloud imp (throws spiky balls; place it high)   x  spiky walker (no stomp)
  y  seagull (glides toward the hero)
  e  slow wavy fish   E  fast darting fish   j  jellyfish (pulses at you)
  z  crab (sea floor walker)   i  sea urchin (hazard, can't be defeated)
  Underwater areas (theme sea / sea_deep): the hero swims; put water
  surface tiles 'v' in row 2 (see add_surface()).
  decorations: * bush  + small bush  f flower  t grass tuft  r rock
               s sign  n fence
  Ground '#', bricks 'w' and decorations take the look of the BIOME of the
  area they are in (area theme -> biome, see level.gd THEME_BIOME): e.g. in a
  desert area '#' is sand, 'w' sandstone, '*' a cactus.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVEL_DIR = os.path.join(ROOT, "levels")
PREVIEW = "--preview" in sys.argv
PREVIEW_DIR = os.environ.get("PREVIEW_DIR", "/tmp")
ROWS = 20
GROUND = 17          # top row of the default ground
SOLID = set("#cXwBP W?MYSCUh>IN")
THEME_BIOME = {"cave": "cave", "cavern": "cave", "desert": "sand", "desert_dusk": "sand",
               "snow": "snow", "snow_night": "snow", "fortress": "castle", "sky": "sky", "sky_dusk": "sky",
               "sea": "sea", "sea_deep": "sea", "beach": "beach", "fortress_magma": "castle",
               "fortress_sun": "castle", "fortress_ice": "castle", "fortress_storm": "castle",
               "fortress_tide": "castle"}


class Level:
    def __init__(self, lid, name, cols, time=400, theme="grass"):
        self.id = lid
        self.name = name
        self.cols = cols
        self.time = time
        self.theme = theme
        self.g = [["."] * cols for _ in range(ROWS)]
        self.start = (3, GROUND - 1)
        self.flag = None
        self.castle = None
        self.checkpoints = []
        self.warps = []
        self.areas = {}
        self.top = 0
        self.arena = None

    # ---------------------------------------------------------------- basics
    def set(self, c, r, ch):
        if 0 <= c < self.cols and 0 <= r < ROWS:
            self.g[r][c] = ch

    def get(self, c, r):
        if 0 <= c < self.cols and 0 <= r < ROWS:
            return self.g[r][c]
        return "."

    def fill(self, c0, c1, r0, r1, ch):
        for c in range(c0, c1 + 1):
            for r in range(r0, r1 + 1):
                self.set(c, r, ch)

    def ground(self, c0, c1, top=GROUND, ch="#"):
        self.fill(c0, c1, 0, ROWS - 1, ".") if False else None
        self.fill(c0, c1, top, ROWS - 1, ch)

    def pit(self, c0, c1):
        self.fill(c0, c1, 0, ROWS - 1, ".")

    def ledge(self, c0, c1, top, depth=2, ch="#"):
        """floating grass ledge"""
        self.fill(c0, c1, top, top + depth - 1, ch)

    def water(self, c0, c1, top=GROUND):
        self.fill(c0, c1, top, ROWS - 1, "v")

    def lava(self, c0, c1, top=GROUND + 1):
        """lava pit: clears the ground below `top`, fills with lava"""
        self.fill(c0, c1, self.top, ROWS - 1, ".")
        self.fill(c0, c1, top, ROWS - 1, "L")

    def ceiling(self, c0, c1, depth=3):
        self.fill(c0, c1, 0, depth - 1, "#")

    def bridge(self, c0, c1, r):
        self.fill(c0, c1, r, r, "=")

    def blocks(self, c, r, s):
        for i, ch in enumerate(s):
            if ch != " ":
                self.set(c + i, r, ch)

    def coins(self, c, r, n, step=1):
        for i in range(n):
            self.set(c + i * step, r, "o")

    def coin_arc(self, c, r, n):
        """coins along a parabola over a gap/obstacle, r = apex row"""
        mid = (n - 1) / 2.0
        for i in range(n):
            d = abs(i - mid) / max(mid, 1)
            self.set(c + i, r + int(round(d * d * 2.2)), "o")

    def enemy(self, c, r=None, ch="g"):
        if r is None:
            r = self.surface(c) - 1
        self.set(c, r, ch)

    def bat(self, c):
        """bat hanging right under the ceiling at column c"""
        r = 0
        while r < ROWS and self.g[r][c] != ".":
            r += 1
        self.set(c, r, "a")

    def surface(self, c, below=None):
        """topmost solid cell at column c, searching from row `self.top` down
        (cave levels set top below their ceiling)"""
        for r in range(self.top if below is None else below, ROWS):
            if self.g[r][c] in "#cXI":
                return r
        return ROWS

    def decor(self, c, ch, r=None):
        if r is None:
            r = self.surface(c) - 1
        if self.get(c, r) == ".":
            self.set(c, r, ch)

    def stairs(self, c, n, up=True, base=GROUND):
        for i in range(n):
            h = i + 1 if up else n - i
            for k in range(h):
                self.set(c + i, base - 1 - k, "X")

    def pipe(self, c, h, warp=False, base=None):
        base = self.surface(c) if base is None else base
        top = base - h
        self.set(c, top, "W" if warp else "P")
        # body cells stay '.', level.gd extends the pipe down to the ground
        return (c, top)

    def side_pipe(self, c, r):
        self.set(c, r, ">")
        return (c, r)

    # ---------------------------------------------------------------- output
    def emit(self):
        path = os.path.join(LEVEL_DIR, "level_%s.gd" % self.id.replace("-", "_"))
        rows = ["".join(r) for r in self.g]
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("extends RefCounted\n\n")
            fh.write("## GENERATED by tools/make_levels.py — edit the generator, not this file.\n")
            fh.write("## Legend: see the docstring at the top of tools/make_levels.py.\n\n")
            fh.write('const ID := "%s"\n' % self.id)
            fh.write('const NAME := "%s"\n' % self.name)
            fh.write("const TIME := %d\n" % self.time)
            fh.write("const START := Vector2i(%d, %d)\n" % self.start)
            fh.write("const FLAG := Vector2i(%d, %d)\n" % (self.flag or (-1, -1)))
            fh.write("const CASTLE := Vector2i(%d, %d)\n" % (self.castle or (-1, -1)))
            if self.arena:
                fh.write("const ARENA := Vector2i(%d, %d)\n" % self.arena)
            fh.write("const CHECKPOINTS := [%s]\n" % ", ".join("Vector2i(%d, %d)" % p for p in self.checkpoints))
            fh.write("const AREAS := {\n")
            for k, (c0, c1, theme) in self.areas.items():
                fh.write('\t"%s": {"from": %d, "to": %d, "theme": "%s"},\n' % (k, c0, c1, theme))
            fh.write("}\n")
            fh.write("const WARPS := [\n")
            for w in self.warps:
                fh.write('\t{"entry": Vector2i(%d, %d), "kind": "%s", "arrive": Vector2i(%d, %d), '
                         '"arrive_kind": "%s", "area": "%s"},\n'
                         % (w["entry"][0], w["entry"][1], w["kind"], w["arrive"][0], w["arrive"][1],
                            w["arrive_kind"], w["area"]))
            fh.write("]\n")
            fh.write("const GRID := [\n")
            for r in rows:
                fh.write('\t"%s",\n' % r)
            fh.write("]\n")
        print("  %s  (%d x %d)" % (os.path.relpath(path, ROOT), self.cols, ROWS))
        if PREVIEW:
            render_preview(self, os.path.join(PREVIEW_DIR, "level_%s.png" % self.id))


# =========================================================================
# 1-1  "Green Hills" — grass & earth, long, pipes + coin room, dragon egg
# =========================================================================
def level_1_1():
    L = Level("1-1", "GREEN HILLS", 312, time=400)
    MAIN_END = 262
    L.ground(0, MAIN_END - 1)
    L.start = (3, GROUND - 1)

    # --- start meadow ------------------------------------------------------
    L.decor(1, "s")
    L.decor(7, "*")
    L.decor(12, "f")
    L.decor(13, "t")
    L.blocks(16, 13, "?")
    L.blocks(21, 13, "BMB?B")
    L.blocks(23, 9, "?")
    L.enemy(24)
    L.decor(28, "+")
    L.decor(31, "f")

    # --- pipe field ----------------------------------------------------------
    L.pipe(33, 2)
    L.enemy(38)
    L.pipe(42, 3)
    L.decor(46, "t")
    L.enemy(48)
    L.enemy(50)
    warp_in = L.pipe(53, 4, warp=True)
    L.decor(57, "*")
    L.pipe(61, 4)
    L.enemy(65)

    # --- first hill with a hidden 1-UP ---------------------------------------
    L.fill(68, 76, 15, GROUND - 1, "#")         # plateau two tiles higher
    L.fill(71, 74, 13, 14, "#")                 # summit
    L.set(72, 9, "h")
    L.coins(71, 11, 4)
    L.decor(69, "f")
    L.decor(76, "t")
    L.enemy(75)

    # --- pit with a coin arc ---------------------------------------------------
    L.pit(80, 82)
    L.coin_arc(79, 12, 5)
    L.decor(85, "r")

    # --- brick run: low row + a long high row with enemies on top -------------
    L.blocks(88, 13, "BMB")
    L.blocks(92, 9, "BBBBBBBB")
    L.enemy(94, 8)
    L.enemy(97, 8)
    L.blocks(103, 9, "BBB?")
    L.blocks(106, 13, "C")
    L.enemy(101)
    L.enemy(103)
    L.blocks(112, 13, "B??B")
    L.blocks(113, 9, "o o")
    L.blocks(118, 13, "S")
    L.decor(110, "*")
    L.decor(121, "n")
    L.decor(122, "n")

    # --- dragon egg + a long field to ride through -------------------------
    L.blocks(128, 13, "BYB")
    L.enemy(136)
    L.enemy(138)
    L.enemy(140)
    L.decor(133, "f")
    L.decor(134, "f")
    L.checkpoints.append((142, GROUND - 1))
    L.ledge(145, 150, 13)
    L.coins(145, 12, 6)
    L.enemy(148, 12)
    # pond crossing on a log bridge
    L.pit(155, 163)
    L.water(155, 163)
    L.bridge(154, 164, 14)
    L.coins(156, 12, 7)
    L.enemy(160, 13)
    L.decor(167, "*")
    L.enemy(170)
    L.enemy(172)
    L.blocks(174, 13, "?B?B?")
    L.blocks(176, 9, "M")

    # --- double staircase with a gap -----------------------------------------
    L.stairs(182, 4, up=True)
    L.pit(186, 187)
    L.stairs(188, 4, up=False)
    L.coin_arc(185, 9, 4)

    # --- exit pipe of the coin room, more enemies ----------------------------
    L.pipe(196, 3)
    warp_out = L.pipe(203, 2)
    L.enemy(208)
    L.enemy(210)
    L.blocks(212, 12, "BUB")
    L.decor(215, "t")
    L.ledge(218, 222, 12)
    L.coins(218, 11, 5)
    L.enemy(225)
    L.enemy(227)
    L.pipe(230, 2)
    L.decor(233, "f")

    # --- final staircase, flag, castle ----------------------------------------
    L.stairs(236, 8, up=True)
    L.fill(244, 244, GROUND - 8, GROUND - 1, "X")
    L.flag = (252, GROUND - 1)
    L.set(252, GROUND - 1, "X")
    L.castle = (256, GROUND - 1)
    L.decor(250, "t")

    # --- coin room (bonus area), separate columns --------------------------
    B0 = 268
    B1 = 307
    L.ground(B0, B1, top=GROUND, ch="c")
    L.fill(B0, B0 + 1, 0, GROUND - 1, "w")
    L.fill(B0, B1, 0, 2, "w")
    L.fill(B1 - 1, B1, 0, GROUND - 1, "w")
    # staggered brick shelves, each reachable with a normal jump from the one
    # below (3 tiles apart), every shelf topped with coins
    L.blocks(B0 + 5, 14, "wwww")
    L.coins(B0 + 5, 13, 4)
    L.blocks(B0 + 11, 11, "wwww")
    L.coins(B0 + 11, 10, 4)
    L.blocks(B0 + 17, 8, "wwwwww")
    L.coins(B0 + 17, 7, 6)
    L.coins(B0 + 17, 6, 6)
    L.blocks(B0 + 25, 11, "wwww")
    L.coins(B0 + 25, 10, 4)
    L.coins(B0 + 10, 16, 14)
    L.coins(B0 + 10, 15, 14)
    exit_mouth = L.side_pipe(B1 - 6, GROUND - 2)
    L.fill(B1 - 5, B1 - 2, 3, GROUND - 3, "w")

    L.areas = {"main": (0, MAIN_END - 1, "grass"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


def coin_room(L, B0, B1, exit_row=GROUND - 2):
    """standard 40-column coin cave; returns the side-pipe exit mouth"""
    L.ground(B0, B1, top=GROUND, ch="c")
    L.fill(B0, B0 + 1, 0, GROUND - 1, "w")
    L.fill(B0, B1, 0, 2, "w")
    L.fill(B1 - 1, B1, 0, GROUND - 1, "w")
    L.blocks(B0 + 5, 14, "wwww")
    L.coins(B0 + 5, 13, 4)
    L.blocks(B0 + 11, 11, "wwww")
    L.coins(B0 + 11, 10, 4)
    L.blocks(B0 + 17, 8, "wwwwww")
    L.coins(B0 + 17, 7, 6)
    L.coins(B0 + 17, 6, 6)
    L.blocks(B0 + 25, 11, "wwww")
    L.coins(B0 + 25, 10, 4)
    L.coins(B0 + 10, 16, 14)
    L.coins(B0 + 10, 15, 14)
    mouth = L.side_pipe(B1 - 6, exit_row)
    L.fill(B1 - 5, B1 - 2, 3, exit_row - 1, "w")
    return mouth


def finale(L, stairs_at, flag_at, castle_at):
    L.stairs(stairs_at, 8, up=True)
    L.fill(stairs_at + 8, stairs_at + 8, GROUND - 8, GROUND - 1, "X")
    L.flag = (flag_at, GROUND - 1)
    L.set(flag_at, GROUND - 1, "X")
    L.castle = (castle_at, GROUND - 1)


# =========================================================================
# 1-2  "Sunset Meadows" — evening light, hills, ponds, winged enemies,
#      biting plants in pipes
# =========================================================================
def level_1_2():
    L = Level("1-2", "SUNSET MEADOWS", 286, time=400)
    MAIN_END = 238
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(6, "*")
    L.decor(10, "f")
    L.blocks(14, 13, "B?BMB")
    L.blocks(16, 9, "?")
    L.enemy(19)
    # hill with a biting plant on top
    L.fill(22, 30, 15, GROUND - 1, "#")
    L.set(26, 13, "Q")
    L.decor(23, "t")
    L.set(33, 16, "G")
    L.enemy(35)
    # small pond
    L.pit(37, 39)
    L.water(37, 39)
    L.coin_arc(36, 12, 5)
    # pipes: normal, biting plant, warp
    L.pipe(44, 3)
    L.set(47, 16, "G")
    L.set(50, GROUND - 3, "Q")
    warp_in = L.pipe(56, 2, warp=True)
    L.decor(59, "+")
    # floating ledge with coins over enemies
    L.ledge(61, 65, 13)
    L.coins(61, 12, 5)
    L.enemy(62)
    L.enemy(64)
    # stepped terrain
    L.fill(68, 71, 16, GROUND - 1, "#")
    L.fill(72, 75, 15, GROUND - 1, "#")
    L.fill(76, 79, 14, GROUND - 1, "#")
    L.set(77, 13, "G")
    L.decor(79, "f")
    # long pond with a log bridge
    L.pit(82, 89)
    L.water(82, 89)
    L.bridge(81, 90, 14)
    L.set(86, 13, "G")
    L.coins(83, 11, 6)
    # blocks + egg
    L.blocks(95, 13, "?C?")
    L.set(99, 9, "h")
    L.blocks(103, 13, "BYB")
    L.enemy(108)
    L.enemy(110)
    L.enemy(112)
    L.decor(114, "*")
    L.checkpoints.append((116, GROUND - 1))
    # ledge staircase with a star brick
    L.ledge(118, 121, 14)
    L.ledge(123, 126, 11)
    L.ledge(128, 131, 8)
    L.coins(128, 7, 4)
    L.set(124, 7, "S")
    L.enemy(120, 13)
    L.enemy(125)
    L.enemy(127)
    # pit jump with coin arc
    L.pit(134, 136)
    L.coin_arc(133, 11, 5)
    # exit pipe of the coin room + more plants
    warp_out = L.pipe(146, 2)
    L.set(152, GROUND - 3, "Q")
    L.set(156, 16, "G")
    L.set(158, 16, "G")
    L.blocks(161, 13, "BBMB")
    L.blocks(162, 9, "B?B")
    L.enemy(166)
    # double staircase
    L.stairs(178, 4, up=True)
    L.pit(182, 183)
    L.stairs(184, 4, up=False)
    # final meadow
    L.ledge(194, 199, 13)
    L.coins(194, 12, 6)
    L.set(197, 12, "G")
    L.enemy(201)
    L.enemy(203)
    L.decor(206, "*")
    finale(L, 212, 228, 232)
    L.decor(225, "t")
    B0, B1 = 244, 283
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "sunset"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 1-3  "Moonlit Heights" — night, more platforming over water, ledges
# =========================================================================
def level_1_3():
    L = Level("1-3", "MOONLIT HEIGHTS", 292, time=400)
    MAIN_END = 244
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(8, "+")
    L.blocks(11, 13, "?M?")
    # ledge crossing over a wide pond
    L.pit(19, 36)
    L.water(19, 36)
    L.ledge(20, 23, 14)
    L.set(25, 12, "~")
    L.ledge(31, 34, 14)
    L.coins(26, 11, 3)
    L.coins(20, 13, 4)
    L.set(32, 13, "G")
    # pipes
    L.set(42, GROUND - 2, "Q")
    L.pipe(48, 4)
    L.set(45, 16, "G")
    L.blocks(52, 13, "B?BB")
    L.blocks(53, 9, "M")
    L.enemy(56)
    L.enemy(58)
    # long bridge over water with walkers
    L.pit(63, 74)
    L.water(63, 74)
    L.bridge(62, 75, 15)
    L.enemy(66, 14)
    L.enemy(71, 14)
    L.coins(64, 11, 10)
    # stepped hill with a plant on the plateau
    L.fill(78, 81, 15, GROUND - 1, "#")
    L.fill(82, 85, 13, GROUND - 1, "#")
    L.fill(86, 93, 12, GROUND - 1, "#")
    L.set(89, 10, "Q")
    L.blocks(87, 8, "?")
    L.fill(94, 96, 14, GROUND - 1, "#")
    L.checkpoints.append((99, GROUND - 1))
    # brick bridge row and blocks
    L.blocks(103, 13, "BBB?BBB")
    L.blocks(106, 9, "C")
    L.enemy(104, 12)
    L.enemy(108)
    L.set(111, 16, "G")
    L.blocks(116, 13, "BYB")
    # warp pipe to the coin room
    warp_in = L.pipe(123, 3, warp=True)
    L.enemy(127)
    L.enemy(129)
    # pits and ledges
    L.pit(133, 135)
    L.ledge(137, 140, 14)
    L.pit(141, 143)
    L.set(139, 13, "G")
    L.coin_arc(132, 11, 5)
    L.coin_arc(140, 10, 5)
    L.blocks(147, 12, "? ?")
    L.set(148, 8, "h")
    L.enemy(152)
    L.enemy(154)
    # high ledges with a star
    L.ledge(158, 161, 13)
    L.ledge(164, 167, 10)
    L.set(165, 6, "S")
    L.coins(158, 12, 4)
    # exit pipe + plants
    warp_out = L.pipe(172, 2)
    L.set(178, GROUND - 3, "Q")
    L.set(183, 16, "G")
    L.enemy(186)
    L.blocks(188, 13, "B?B")
    # staircase with gap
    L.stairs(194, 4, up=True)
    L.pit(198, 200)
    L.stairs(201, 4, up=False)
    L.set(208, 16, "G")
    L.enemy(210)
    finale(L, 216, 234, 238)
    B0, B1 = 250, 289
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "night"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 2-1  "Crystal Caverns" — underground: ceiling, lava, shell turtles; the
#      way out is a pipe to a sunset meadow with the flag
# =========================================================================
def level_2_1():
    L = Level("2-1", "CRYSTAL CAVERNS", 306, time=400)
    MAIN_END = 214
    L.top = 6
    L.ground(0, MAIN_END - 1)
    L.ceiling(0, MAIN_END - 1, 3)
    # hanging rock chunks for a jagged ceiling
    for c0, c1, d in [(9, 12, 4), (30, 33, 5), (60, 64, 6), (92, 94, 4), (140, 145, 5), (182, 186, 5)]:
        L.fill(c0, c1, 3, d - 1, "#")
    L.decor(2, "*")
    L.decor(6, "f")
    L.decor(8, "t")
    L.blocks(13, 13, "B?M?B")
    L.enemy(19)
    L.enemy(22, ch="k")
    L.decor(24, "+")
    L.pipe(26, 2)
    # bricks with coins
    L.blocks(30, 12, "BBBBBB")
    L.coins(30, 11, 6)
    L.enemy(33)
    # first lava pit
    L.lava(37, 40)
    L.coin_arc(36, 11, 6)
    # hill patrolled by a red turtle
    L.fill(42, 48, 15, GROUND - 1, "#")
    L.enemy(45, ch="K")
    L.decor(43, "f")
    L.lava(50, 52)
    warp_in = L.pipe(55, 3, warp=True)
    L.decor(58, "t")
    # floating stone ledge with coins, walkers below
    L.ledge(61, 67, 12)
    L.coins(61, 11, 7)
    L.enemy(62)
    L.enemy(65)
    L.enemy(64, 11, ch="K")
    L.set(70, 14, "J")
    # lava lake with stepping pillars
    L.lava(74, 86)
    L.fill(77, 78, 14, ROWS - 1, "#")
    L.fill(81, 82, 12, ROWS - 1, "#")
    L.coins(77, 13, 2)
    L.coins(81, 11, 2)
    L.coin_arc(83, 9, 5)
    L.checkpoints.append((90, GROUND - 1))
    L.decor(92, "*")
    L.blocks(95, 13, "BBCBB")
    L.set(97, 9, "S")
    L.enemy(99)
    L.enemy(101)
    L.set(104, GROUND - 3, "Q")
    for c in (35, 70, 100, 158, 192):
        L.bat(c)
    # shell alley: one turtle, a row of walkers behind it -> shell combo
    L.enemy(110, ch="k")
    L.enemy(115)
    L.enemy(117)
    L.enemy(119)
    L.enemy(121)
    L.decor(123, "+")
    # low-ceiling passage with a hidden 1-UP
    L.fill(125, 139, 3, 8, "#")
    L.blocks(128, 13, "B?BB")
    L.set(133, 13, "h")
    L.enemy(131, GROUND - 1)
    L.enemy(136, GROUND - 1, ch="k")
    # log bridge over lava
    L.lava(142, 150)
    L.bridge(141, 151, 14)
    L.enemy(146, 13)
    L.coins(143, 11, 7)
    L.blocks(154, 13, "BYB")
    L.decor(158, "f")
    L.ledge(160, 164, 13)
    L.enemy(162, 12, ch="K")
    L.enemy(166)
    L.enemy(168, ch="k")
    warp_out = L.pipe(171, 2)
    # lava pit with stepping ledges
    L.lava(175, 183)
    L.ledge(177, 178, 14)
    L.ledge(181, 182, 12)
    L.set(181, 11, "J")
    L.coin_arc(176, 10, 8)
    L.set(186, GROUND - 3, "Q")
    L.enemy(190)
    L.enemy(192)
    L.stairs(195, 4, up=True)
    L.blocks(200, 12, "?")
    exit_pipe = L.pipe(204, 2, warp=True)
    L.coins(203, 11, 4)
    L.fill(MAIN_END - 2, MAIN_END - 1, 0, GROUND - 1, "w")
    # exit meadow (outside, sunset)
    E0, E1 = 220, 259
    L.ground(E0, E1)
    arrive = L.pipe(E0 + 3, 2)
    L.decor(E0 + 7, "*")
    L.decor(E0 + 12, "f")
    L.coins(E0 + 9, 12, 4)
    finale(L, E0 + 12, E0 + 28, E0 + 32)
    L.decor(E0 + 25, "t")
    B0, B1 = 266, 305
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "cavern"), "exit": (E0, E1, "sunset"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
        {"entry": exit_pipe, "kind": "down", "arrive": arrive, "arrive_kind": "up", "area": "exit"},
    ]
    return L


# =========================================================================
# 3-1  "Dune Drift" — desert: sand, cacti, sandstone ruins, red turtles on
#      ledges, winged turtles, an oasis
# =========================================================================
def level_3_1():
    L = Level("3-1", "DUNE DRIFT", 300, time=400)
    MAIN_END = 250
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(5, "*")
    L.decor(9, "+")
    L.blocks(12, 13, "?B?")
    L.blocks(13, 9, "M")
    L.enemy(17, ch="k")
    L.decor(20, "r")
    # dune humps
    L.fill(23, 29, 16, GROUND - 1, "#")
    L.fill(25, 27, 15, 15, "#")
    L.enemy(26, 14)
    L.decor(24, "+")
    L.pit(32, 34)
    L.coin_arc(31, 11, 5)
    # sandstone ruin: wall steps with a red turtle on top
    L.fill(38, 45, 14, GROUND - 1, "w")
    L.fill(40, 43, 11, 13, "w")
    L.enemy(41, 10, ch="K")
    L.coins(38, 13, 2)
    L.coins(44, 13, 2)
    L.blocks(41, 7, "?")
    L.decor(47, "*")
    L.pipe(50, 3)
    L.set(54, 14, "J")
    warp_in = L.pipe(58, 2, warp=True)
    L.enemy(62)
    L.enemy(64)
    L.decor(66, "f")
    # oasis
    L.pit(69, 78)
    L.water(69, 78)
    L.bridge(68, 79, 14)
    L.enemy(73, 13, ch="k")
    L.coins(70, 10, 8)
    L.decor(81, "*")
    L.blocks(84, 13, "BCB?B")
    L.enemy(88)
    L.enemy(90, ch="K")
    L.checkpoints.append((94, GROUND - 1))
    # ledge chain over pits
    L.pit(97, 110)
    L.ledge(98, 101, 14, ch="w")
    L.set(102, 12, "~")
    L.ledge(108, 110, 14, ch="w")
    L.enemy(99, 13, ch="K")
    L.coins(104, 11, 3)
    L.set(105, 8, "S")
    L.decor(113, "+")
    L.set(116, GROUND - 3, "Q")
    L.blocks(121, 13, "BYB")
    L.enemy(125, ch="k")
    L.enemy(129)
    L.enemy(131)
    L.enemy(133)
    L.set(136, 14, "J")
    # pyramid steps (sandstone) with a hidden 1-UP above
    for i in range(5):
        L.fill(140 + i, 152 - i, GROUND - 1 - i, GROUND - 1 - i, "w")
    L.coins(144, 11, 5)
    L.set(146, 8, "h")
    L.enemy(155)
    warp_out = L.pipe(159, 2)
    L.decor(163, "*")
    L.pit(166, 169)
    L.coin_arc(165, 11, 6)
    L.set(172, GROUND - 3, "Q")
    L.set(176, 13, "J")
    L.blocks(179, 13, "B?BB")
    L.enemy(181, ch="k")
    L.enemy(184)
    L.ledge(187, 191, 13, ch="w")
    L.enemy(189, 12, ch="K")
    L.coins(187, 12, 2)
    L.stairs(196, 4, up=True)
    L.pit(200, 201)
    L.stairs(202, 4, up=False)
    L.enemy(210)
    L.decor(212, "+")
    for c in (36, 82, 137, 170):
        L.enemy(c, ch="p")
    finale(L, 214, 230, 234)
    L.decor(227, "*")
    B0, B1 = 256, 295
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "desert"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 4-1  "Frosty Peaks" — snow: slippery ice blocks, frozen lake with ice
#      floes, pines, turtles
# =========================================================================
def level_4_1():
    L = Level("4-1", "FROSTY PEAKS", 300, time=400)
    MAIN_END = 250
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(4, "*")
    L.decor(8, "+")
    L.blocks(11, 13, "B?M?B")
    L.enemy(16)
    L.enemy(18, ch="k")
    L.decor(21, "*")
    # first ice patch on the ground (slippery run-up)
    L.fill(24, 31, GROUND, GROUND, "I")
    L.enemy(28)
    L.pit(33, 35)
    L.coin_arc(32, 11, 5)
    # snowy hill
    L.fill(38, 46, 15, GROUND - 1, "#")
    L.fill(40, 44, 13, 14, "#")
    L.enemy(42, 12, ch="K")
    L.decor(39, "t")
    L.pipe(49, 3)
    warp_in = L.pipe(55, 2, warp=True)
    L.set(59, 14, "G")
    L.decor(61, "*")
    # frozen lake with ice floes
    L.pit(64, 82)
    L.water(64, 82)
    L.ledge(66, 69, 15, depth=1, ch="I")
    L.set(71, 13, "~")
    L.ledge(77, 80, 15, depth=1, ch="I")
    L.enemy(67, 14)
    L.coins(72, 12, 3)
    L.coins(77, 14, 4)
    L.set(73, 9, "S")
    L.checkpoints.append((86, GROUND - 1))
    L.decor(88, "+")
    L.blocks(91, 13, "BCB")
    L.enemy(95, ch="k")
    L.enemy(99)
    L.enemy(101)
    L.set(104, GROUND - 3, "Q")
    # ice-block bridge over a pit
    L.pit(109, 118)
    L.ledge(108, 119, 14, depth=1, ch="I")
    L.enemy(112, 13, ch="k")
    L.enemy(115, 13)
    L.coins(110, 11, 8)
    L.blocks(123, 13, "BYB")
    L.decor(127, "*")
    L.set(130, 14, "J")
    L.enemy(133)
    # ice-brick ledge staircase with a hidden 1-UP
    L.ledge(137, 140, 14, ch="w")
    L.ledge(143, 146, 11, ch="w")
    L.ledge(149, 152, 8, ch="w")
    L.coins(149, 7, 4)
    L.set(144, 6, "h")
    L.enemy(145, 10, ch="K")
    L.enemy(139, 13)
    warp_out = L.pipe(156, 2)
    L.decor(160, "*")
    L.pit(163, 166)
    L.coin_arc(162, 11, 6)
    L.fill(168, 175, GROUND, GROUND, "I")
    L.enemy(171, ch="k")
    L.set(178, GROUND - 3, "Q")
    L.set(183, 14, "G")
    L.blocks(186, 13, "?B?")
    L.enemy(190)
    L.enemy(192)
    L.stairs(196, 4, up=True)
    L.pit(200, 202)
    L.stairs(203, 4, up=False)
    L.set(211, 14, "J")
    L.decor(212, "+")
    for c in (21, 59, 89, 126, 180):
        L.enemy(c, ch="q")
    finale(L, 214, 230, 234)
    L.decor(226, "*")
    B0, B1 = 256, 295
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "snow"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 2-2  "Lava Depths" — deeper cave: lava river with bridges and pillars,
#      brick ceilings to smash, red turtles on pillars; exit to a night meadow
# =========================================================================
def level_2_2():
    L = Level("2-2", "LAVA DEPTHS", 306, time=400)
    MAIN_END = 214
    L.top = 6
    L.ground(0, MAIN_END - 1)
    L.ceiling(0, MAIN_END - 1, 3)
    for c0, c1, d in [(14, 17, 5), (44, 46, 4), (98, 102, 6), (150, 153, 5), (190, 194, 4)]:
        L.fill(c0, c1, 3, d - 1, "#")
    L.decor(2, "+")
    L.decor(5, "*")
    L.blocks(8, 13, "?M?")
    L.enemy(12, ch="k")
    L.enemy(15)
    # lava river: pillars with red turtles
    L.lava(19, 34)
    L.fill(22, 23, 14, ROWS - 1, "#")
    L.fill(27, 28, 12, ROWS - 1, "#")
    L.fill(31, 32, 14, ROWS - 1, "#")
    L.enemy(27, 11, ch="K")
    L.coins(22, 13, 2)
    L.coins(31, 13, 2)
    L.coin_arc(24, 8, 3)
    L.decor(37, "f")
    L.pipe(40, 2)
    L.enemy(44)
    L.enemy(46, ch="k")
    # brick ceiling: a low roof of bricks to smash when big
    L.fill(50, 62, 3, 9, "#")
    L.blocks(50, 10, "BBBBBCBBBBBBB")
    L.blocks(54, 13, "?B?")
    L.enemy(57, GROUND - 1)
    L.enemy(60, GROUND - 1, ch="k")
    warp_in = L.pipe(66, 2, warp=True)
    L.decor(69, "t")
    # log bridges over a long lava lake
    L.lava(72, 93)
    L.bridge(71, 77, 14)
    L.fill(79, 80, 12, ROWS - 1, "#")
    L.bridge(82, 87, 13)
    L.fill(89, 90, 14, ROWS - 1, "#")
    L.enemy(74, 13)
    L.enemy(85, 12, ch="k")
    L.coins(72, 11, 5)
    L.coins(82, 10, 6)
    L.set(79, 8, "S")
    L.checkpoints.append((97, GROUND - 1))
    L.decor(99, "*")
    L.set(104, GROUND - 3, "Q")
    L.blocks(109, 13, "BYB")
    L.enemy(113)
    L.enemy(115)
    L.enemy(117, ch="K")
    # hard-block staircase over lava
    L.lava(121, 131)
    for i, h in enumerate([1, 2, 3, 4]):
        L.fill(121 + i, 121 + i, GROUND - h, ROWS - 1, "X")
    for i, h in enumerate([4, 3, 2, 1]):
        L.fill(128 + i, 128 + i, GROUND - h, ROWS - 1, "X")
    L.coin_arc(124, 8, 5)
    L.set(137, 14, "J")
    L.ledge(140, 145, 12)
    L.coins(140, 11, 6)
    L.enemy(142, 11, ch="K")
    L.enemy(141, GROUND - 1)
    L.enemy(144, GROUND - 1, ch="k")
    L.set(148, 13, "h")
    warp_out = L.pipe(156, 2)
    L.set(161, GROUND - 3, "Q")
    L.lava(165, 176)
    L.ledge(167, 169, 14)
    L.set(172, 14, "^")
    L.coin_arc(166, 10, 10)
    L.enemy(180)
    L.enemy(182)
    L.enemy(184, ch="k")
    L.stairs(193, 4, up=True)
    L.blocks(198, 12, "?")
    exit_pipe = L.pipe(204, 2, warp=True)
    L.coins(203, 11, 4)
    for c in (38, 69, 106, 136, 170, 186):
        L.bat(c)
    L.fill(MAIN_END - 2, MAIN_END - 1, 0, GROUND - 1, "w")
    E0, E1 = 220, 259
    L.ground(E0, E1)
    arrive = L.pipe(E0 + 3, 2)
    L.decor(E0 + 7, "+")
    L.decor(E0 + 10, "f")
    L.coins(E0 + 8, 12, 3)
    finale(L, E0 + 12, E0 + 28, E0 + 32)
    L.decor(E0 + 24, "t")
    B0, B1 = 266, 305
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "cavern"), "exit": (E0, E1, "night"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
        {"entry": exit_pipe, "kind": "down", "arrive": arrive, "arrive_kind": "up", "area": "exit"},
    ]
    return L


# =========================================================================
# 3-2  "Sunset Ruins" — desert at dusk: a sandstone temple with passages,
#      winged turtles over pits, a turtle row for shell combos
# =========================================================================
def level_3_2():
    L = Level("3-2", "SUNSET RUINS", 300, time=400)
    MAIN_END = 250
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(4, "*")
    L.blocks(9, 13, "B?B")
    L.blocks(10, 9, "M")
    L.enemy(14)
    L.enemy(16, ch="k")
    L.decor(19, "+")
    # winged turtles over two pits
    L.pit(22, 25)
    L.set(23, 12, "J")
    L.coin_arc(21, 11, 6)
    L.pit(29, 32)
    L.set(31, 11, "J")
    L.coin_arc(28, 11, 6)
    L.decor(35, "r")
    # sandstone temple: outer walls, roof, inner passage with coins
    L.fill(38, 60, 9, 9, "w")
    L.fill(38, 39, 10, 13, "w")
    L.fill(59, 60, 10, 13, "w")
    L.blocks(44, 13, "B?BB?B")
    L.coins(42, 16, 16)
    L.enemy(47, GROUND - 1, ch="K")
    L.enemy(53, GROUND - 1)
    L.enemy(49, 8, ch="K")
    L.coins(41, 7, 3)
    L.coins(56, 7, 3)
    L.set(50, 5, "S")
    L.decor(63, "*")
    L.pipe(66, 3)
    warp_in = L.pipe(71, 2, warp=True)
    L.set(75, 14, "J")
    L.enemy(78)
    # turtle row on a sandstone shelf -> kick one, the rest topple
    L.ledge(82, 94, 13, ch="w")
    for c in (85, 88, 91):
        L.enemy(c, 12, ch="k")
    L.enemy(93, 12, ch="K")
    L.coins(82, 10, 3)
    L.checkpoints.append((98, GROUND - 1))
    L.decor(100, "f")
    L.set(104, GROUND - 3, "Q")
    L.pit(108, 111)
    L.coin_arc(107, 11, 6)
    L.blocks(115, 13, "BYB")
    L.enemy(119)
    L.enemy(121)
    # step pyramid with a tunnel through its base
    for i in range(6):
        L.fill(126 + i, 140 - i, GROUND - 1 - i, GROUND - 1 - i, "w")
    L.fill(131, 135, GROUND - 2, GROUND - 1, ".")
    L.coins(131, 16, 5)
    L.set(133, 8, "h")
    L.coins(131, 10, 5)
    L.enemy(129, 14, ch="k")
    L.enemy(144)
    L.set(147, 14, "J")
    warp_out = L.pipe(151, 2)
    L.decor(155, "*")
    L.pit(158, 164)
    L.ledge(160, 162, 13, ch="w")
    L.enemy(161, 12, ch="K")
    L.coins(158, 9, 7)
    L.set(168, GROUND - 3, "Q")
    L.blocks(173, 13, "?C?")
    L.enemy(176, ch="k")
    L.enemy(178)
    L.enemy(180)
    L.set(184, 13, "G")
    L.stairs(196, 4, up=True)
    L.pit(200, 202)
    L.stairs(203, 4, up=False)
    L.set(209, 14, "J")
    L.decor(212, "+")
    for c in (19, 64, 96, 123, 186):
        L.enemy(c, ch="p")
    finale(L, 214, 230, 234)
    L.decor(227, "*")
    B0, B1 = 256, 295
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "desert_dusk"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 4-2  "Starlight Glacier" — snow at night: long ice runs, floes over dark
#      water, ice-brick towers, winged enemies
# =========================================================================
def level_4_2():
    L = Level("4-2", "STARLIGHT GLACIER", 300, time=400)
    MAIN_END = 250
    L.ground(0, MAIN_END - 1)
    L.decor(1, "s")
    L.decor(5, "*")
    L.blocks(9, 13, "?B?")
    L.blocks(10, 9, "M")
    L.enemy(14, ch="k")
    # long ice run with a pit at its end
    L.fill(18, 33, GROUND, GROUND, "I")
    L.enemy(22)
    L.enemy(26)
    L.enemy(30, ch="k")
    L.pit(35, 37)
    L.coin_arc(34, 11, 5)
    L.decor(40, "*")
    # ice-brick towers with a turtle on top
    L.fill(43, 45, 12, GROUND - 1, "w")
    L.fill(49, 51, 10, GROUND - 1, "w")
    L.enemy(50, 9, ch="K")
    L.coins(43, 11, 3)
    L.coins(49, 9, 3)
    L.pipe(55, 2)
    warp_in = L.pipe(60, 3, warp=True)
    L.set(64, 14, "G")
    # frozen lake: floes + ice bridge
    L.pit(67, 90)
    L.water(67, 90)
    L.ledge(69, 71, 15, depth=1, ch="I")
    L.ledge(74, 76, 13, depth=1, ch="I")
    L.ledge(79, 84, 14, depth=1, ch="I")
    L.ledge(87, 89, 12, depth=1, ch="I")
    L.enemy(81, 13, ch="k")
    L.set(77, 9, "J")
    L.coins(74, 12, 3)
    L.coins(79, 11, 6)
    L.set(88, 8, "S")
    L.checkpoints.append((94, GROUND - 1))
    L.decor(96, "+")
    L.blocks(99, 13, "BCB?")
    L.enemy(104)
    L.enemy(106, ch="k")
    L.set(110, GROUND - 3, "Q")
    L.fill(114, 124, GROUND, GROUND, "I")
    L.enemy(118)
    L.enemy(121)
    L.blocks(116, 12, "BYB")
    L.pit(126, 129)
    L.set(127, 12, "G")
    L.coin_arc(125, 10, 6)
    # ice staircase up to a high ledge with a hidden 1-UP
    L.ledge(133, 135, 14, depth=1, ch="I")
    L.ledge(137, 139, 12, depth=1, ch="I")
    L.ledge(141, 146, 10, ch="w")
    L.coins(141, 9, 6)
    L.set(143, 6, "h")
    L.enemy(144, 9, ch="K")
    warp_out = L.pipe(150, 2)
    L.decor(154, "*")
    L.pit(157, 169)
    L.water(157, 169)
    L.ledge(156, 170, 14, depth=1, ch="I")
    L.enemy(160, 13)
    L.enemy(164, 13, ch="k")
    L.enemy(167, 13)
    L.coins(158, 11, 11)
    L.set(174, GROUND - 3, "Q")
    L.set(178, 14, "J")
    L.blocks(182, 13, "?B?")
    L.enemy(186)
    L.stairs(193, 4, up=True)
    L.pit(197, 199)
    L.stairs(200, 4, up=False)
    L.fill(205, 212, GROUND, GROUND, "I")
    L.set(209, 14, "G")
    for c in (17, 41, 96, 131, 188):
        L.enemy(c, ch="q")
    finale(L, 214, 230, 234)
    L.decor(226, "*")
    B0, B1 = 256, 295
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "snow_night"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 5-1  "Cloud Kingdom" — cloud islands over a bottomless sky: falling slabs,
#      tipping planks, cloud bridges, seagulls and a spiky-throwing imp
# =========================================================================
def level_5_1():
    L = Level("5-1", "CLOUD KINGDOM", 320, time=400)
    MAIN_END = 270
    # start island
    L.ground(0, 20)
    L.decor(1, "s")
    L.decor(5, "*")
    L.decor(11, "f")
    L.decor(15, "+")
    L.blocks(8, 13, "?B?M?")
    L.blocks(10, 9, "?")
    L.enemy(17)
    # small gap, island one step higher, a gull at head height
    L.coin_arc(20, 12, 5)
    L.ground(24, 40, top=16)
    L.decor(26, "t")
    L.enemy(30)
    L.enemy(35)
    L.set(38, 13, "y")
    # a falling slab bridges the next gap
    L.set(42, 15, "D")
    L.coins(42, 13, 3)
    L.ground(47, 60, top=15)
    L.decor(49, "*")
    L.blocks(52, 11, "B?B")
    L.enemy(56, ch="J")
    # two tipping planks
    L.set(63, 14, "T")
    L.set(69, 13, "T")
    L.coins(69, 10, 4)
    # long island: the cloud imp arrives, warp pipe to a coin room
    L.ground(75, 97)
    L.set(84, 9, "u")
    L.decor(77, "f")
    L.blocks(80, 13, "?B?B?")
    L.blocks(82, 9, "M")
    warp_in = L.pipe(90, 3, warp=True)
    L.decor(95, "+")
    # one-way cloud bridge over open sky
    L.bridge(98, 105, 14)
    L.coins(99, 12, 6)
    # checkpoint island
    L.ground(106, 130)
    L.checkpoints.append((110, GROUND - 1))
    L.decor(108, "*")
    L.blocks(115, 13, "BCB")
    L.enemy(119)
    L.enemy(122, ch="k")
    L.set(126, 14, "y")
    L.decor(128, "r")
    # falling slab staircase
    for c, r in ((131, 15), (135, 13), (139, 11), (143, 13)):
        L.set(c, r, "D")
    L.coins(139, 9, 3)
    L.ground(147, 170, top=15)
    L.enemy(152)
    L.blocks(154, 11, "?")
    warp_out = L.pipe(160, 2)
    L.enemy(165, ch="x")
    # lift over a wide gap
    L.set(172, 15, "~")
    L.coins(174, 12, 4)
    L.ground(181, 206, top=16)
    L.enemy(188, ch="k")
    L.enemy(196, ch="k")
    L.blocks(192, 12, "B?B")
    L.set(190, 13, "y")
    L.set(200, 14, "y")
    L.set(204, 11, "y")
    L.decor(183, "f")
    # tipping planks, then the last stretch with spikies + a hidden 1-UP
    L.set(208, 14, "T")
    L.set(214, 13, "T")
    L.ground(220, 236)
    L.enemy(226, ch="x")
    L.enemy(231, ch="x")
    L.blocks(224, 13, "B?B")
    L.set(233, 12, "h")
    L.decor(221, "+")
    L.ground(237, MAIN_END - 1)
    finale(L, 240, 256, 260)
    L.decor(252, "*")
    B0, B1 = 280, 319
    exit_mouth = coin_room(L, B0, B1)
    L.areas = {"main": (0, MAIN_END - 1, "sky"), "bonus": (B0, B1, "cave")}
    L.warps = [
        {"entry": warp_in, "kind": "down", "arrive": (B0 + 3, 4), "arrive_kind": "drop", "area": "bonus"},
        {"entry": exit_mouth, "kind": "right", "arrive": warp_out, "arrive_kind": "up", "area": "main"},
    ]
    return L


# =========================================================================
# 5-2  "Sunset Skyway" — evening sky, harder: slab chains, lifts, a vertical
#      lift up to a cloud tower, tipping planks down again, two imps
# =========================================================================
def level_5_2():
    L = Level("5-2", "SUNSET SKYWAY", 300, time=400)
    L.ground(0, 18)
    L.decor(2, "*")
    L.decor(9, "f")
    L.decor(14, "+")
    L.blocks(7, 13, "?M?")
    L.enemy(15)
    # falling slab chain over a wide gap
    for c, r in ((20, 15), (25, 14), (30, 15)):
        L.set(c, r, "D")
    L.coins(25, 12, 3)
    L.ground(35, 50, top=16)
    L.set(38, 9, "u")
    L.enemy(42, ch="x")
    L.enemy(47)
    # two sideways lifts
    L.set(53, 15, "~")
    L.set(62, 13, "~")
    L.coins(63, 10, 3)
    L.ground(71, 84, top=15)
    L.blocks(75, 11, "B?B?B")
    L.enemy(80, ch="k")
    # three tipping planks in a row
    L.set(86, 14, "T")
    L.set(92, 13, "T")
    L.set(98, 14, "T")
    L.coins(93, 10, 4)
    L.ground(104, 125)
    L.checkpoints.append((107, GROUND - 1))
    L.blocks(112, 13, "?C?")
    L.enemy(110, ch="x")
    L.enemy(116)
    L.enemy(120, ch="k")
    L.set(114, 14, "y")
    L.set(123, 12, "y")
    # cloud bridge with a winged turtle above
    L.bridge(127, 136, 14)
    L.set(131, 11, "J")
    L.ground(138, 150, top=16)
    L.set(143, 12, "h")
    L.decor(140, "*")
    # slabs down to a vertical lift, up onto a cloud tower
    for c, r in ((152, 14), (157, 12), (162, 14)):
        L.set(c, r, "D")
    L.set(167, 15, "^")
    L.ground(172, 192, top=12)
    L.enemy(178, ch="k")
    L.enemy(186)
    L.blocks(180, 8, "?M?")
    L.decor(190, "+")
    # tipping planks back down
    L.set(194, 13, "T")
    L.set(200, 15, "T")
    L.ground(206, 228)
    L.set(210, 8, "u")
    L.enemy(215, ch="x")
    L.enemy(221, ch="x")
    L.blocks(214, 13, "B?B")
    L.bridge(229, 236, 14)
    L.set(233, 12, "y")
    L.ground(238, 250, top=16)
    L.enemy(244, ch="J")
    for c, r in ((252, 15), (256, 13)):
        L.set(c, r, "D")
    L.ground(261, 299)
    L.decor(263, "f")
    finale(L, 268, 284, 288)
    L.areas = {"main": (0, 299, "sky_dusk")}
    return L


# =========================================================================
# underwater helpers + 6-1 "Coral Reef" / 6-2 "Deep Trench"
# =========================================================================
def add_surface(L, c0, c1, row=2):
    """animated water surface along the top of an underwater area (the hero
    can't rise above it, player.gd SWIM_TOP) — call after pits are dug"""
    for c in range(c0, c1 + 1):
        if L.get(c, row) == ".":
            L.set(c, row, "v")


def beach_exit(L, E0, E1):
    """sunny beach behind the exit pipe: arrival pipe, flag pole, castle"""
    L.ground(E0, E1)
    arrive = L.pipe(E0 + 3, 2)
    L.decor(E0 + 8, "*")
    L.decor(E0 + 14, "f")
    L.coins(E0 + 9, 12, 4)
    finale(L, E0 + 12, E0 + 28, E0 + 32)
    L.decor(E0 + 26, "*")
    return arrive


def level_6_1():
    L = Level("6-1", "CORAL REEF", 260, time=400)
    MAIN_END = 210
    L.ground(0, MAIN_END - 1)
    # seaweed garden, a first power-up
    L.decor(2, "*")
    L.decor(5, "+")
    L.decor(9, "f")
    L.decor(13, "*")
    L.blocks(8, 12, "?M?")
    L.set(16, 12, "e")
    L.set(22, 15, "e")
    # reef mound with coins, first urchin
    L.fill(18, 25, 14, GROUND - 1, "#")
    L.coins(18, 11, 8)
    L.decor(24, "*")
    L.set(27, GROUND - 1, "i")
    # a pit to swim over, an urchin above it
    L.pit(30, 34)
    L.coin_arc(29, 9, 7)
    L.set(32, 7, "i")
    # coral walls: swim through the gaps
    L.fill(38, 39, 3, 9, "w")
    L.fill(44, 45, 11, GROUND - 1, "w")
    L.fill(50, 51, 3, 8, "w")
    L.set(47, 13, "j")
    L.coins(40, 12, 3)
    L.coins(46, 8, 3)
    L.enemy(55, ch="z")
    L.enemy(60, ch="z")
    L.decor(57, "+")
    # a school of fast fish
    L.coins(64, 9, 10)
    L.blocks(66, 13, "B?B")
    L.set(70, 8, "E")
    L.set(74, 13, "E")
    L.set(79, 10, "E")
    L.fill(84, 87, 15, GROUND - 1, "#")
    L.set(88, GROUND - 1, "i")
    L.checkpoints.append((92, GROUND - 1))
    L.decor(94, "*")
    # tunnel under a reef roof, urchins on floor and roof
    L.fill(97, 120, 3, 10, "#")
    L.set(103, GROUND - 1, "i")
    L.set(110, 11, "i")
    L.set(116, GROUND - 1, "i")
    L.set(113, 14, "e")
    L.coins(99, 13, 4)
    L.coins(106, 14, 3)
    # open water with jellyfish
    L.decor(124, "*")
    L.set(126, 10, "j")
    L.set(134, 13, "j")
    L.enemy(130, ch="z")
    L.blocks(128, 9, "?S?")
    L.decor(137, "+")
    # reef pillar between two pits
    L.pit(141, 144)
    L.fill(145, 147, 12, ROWS - 1, "#")
    L.pit(148, 151)
    L.coin_arc(140, 9, 13)
    L.set(146, 8, "i")
    # last stretch: crabs, fish, a hidden 1-UP
    L.enemy(158, ch="z")
    L.enemy(163, ch="z")
    L.set(160, 11, "e")
    L.set(170, 8, "e")
    L.set(175, 13, "E")
    L.set(167, 9, "h")
    L.fill(180, 184, 13, GROUND - 1, "#")
    L.decor(182, "+")
    L.set(188, 12, "j")
    L.coins(190, 13, 6)
    # exit: side pipe into the reef wall -> beach
    L.fill(MAIN_END - 4, MAIN_END - 1, 3, GROUND - 1, "w")
    exit_mouth = L.side_pipe(MAIN_END - 8, GROUND - 2)
    add_surface(L, 0, MAIN_END - 1)
    arrive = beach_exit(L, 220, 259)
    L.areas = {"main": (0, MAIN_END - 1, "sea"), "exit": (220, 259, "beach")}
    L.warps = [{"entry": exit_mouth, "kind": "right", "arrive": arrive, "arrive_kind": "up", "area": "exit"}]
    return L


def level_6_2():
    L = Level("6-2", "DEEP TRENCH", 280, time=400)
    MAIN_END = 230
    L.ground(0, MAIN_END - 1)
    L.decor(2, "*")
    L.decor(6, "r")
    L.blocks(9, 12, "?M?")
    L.set(15, 11, "j")
    # first trench with a pillar
    L.pit(20, 31)
    L.fill(24, 26, 15, ROWS - 1, "#")
    L.set(25, 14, "i")
    L.coin_arc(20, 9, 12)
    L.set(28, 7, "E")
    # coral maze
    L.fill(36, 37, 3, 12, "w")
    L.fill(42, 43, 8, GROUND - 1, "w")
    L.fill(48, 49, 3, 11, "w")
    L.fill(54, 55, 9, GROUND - 1, "w")
    L.set(39, 15, "i")
    L.set(45, 5, "i")
    L.set(51, 14, "i")
    L.coins(38, 14, 3)
    L.coins(44, 6, 3)
    L.coins(50, 12, 3)
    L.set(58, 10, "j")
    # crabs on the sea floor, a school of fish
    L.enemy(62, ch="z")
    L.enemy(66, ch="z")
    L.enemy(70, ch="z")
    L.set(68, 9, "e")
    L.set(72, 12, "e")
    L.set(76, 7, "e")
    L.blocks(64, 12, "B?BCB")
    L.checkpoints.append((84, GROUND - 1))
    L.decor(86, "*")
    # the deep trench: long pit with three pillars, jellyfish above
    L.pit(90, 120)
    for c0, top in ((95, 14), (103, 12), (111, 14)):
        L.fill(c0, c0 + 2, top, ROWS - 1, "#")
    L.set(104, 11, "i")
    L.set(99, 9, "j")
    L.set(107, 11, "j")
    L.set(116, 8, "j")
    L.coins(95, 11, 3)
    L.coins(111, 11, 3)
    L.set(118, 6, "E")
    L.set(121, 12, "E")
    # low tunnel with urchins on floor and roof
    L.fill(126, 150, 3, 11, "#")
    for c in (131, 139, 146):
        L.set(c, GROUND - 1, "i")
    L.set(135, 12, "i")
    L.set(143, 12, "i")
    L.coins(128, 14, 3)
    L.coins(136, 14, 3)
    L.coins(141, 15, 3)
    # open deep water: crabs + jellyfish, hidden 1-UP
    L.enemy(156, ch="z")
    L.enemy(161, ch="z")
    L.set(158, 10, "j")
    L.set(166, 13, "j")
    L.set(172, 9, "j")
    L.blocks(162, 11, "?")
    L.set(169, 7, "h")
    L.fill(178, 182, 14, GROUND - 1, "#")
    L.pit(184, 196)
    L.fill(189, 191, 13, ROWS - 1, "#")
    L.set(190, 12, "i")
    L.coin_arc(183, 8, 14)
    L.set(200, 10, "E")
    L.set(204, 13, "E")
    L.set(208, 8, "e")
    L.enemy(212, ch="z")
    L.decor(215, "+")
    L.fill(MAIN_END - 4, MAIN_END - 1, 3, GROUND - 1, "w")
    exit_mouth = L.side_pipe(MAIN_END - 8, GROUND - 2)
    add_surface(L, 0, MAIN_END - 1)
    arrive = beach_exit(L, 240, 279)
    L.areas = {"main": (0, MAIN_END - 1, "sea_deep"), "exit": (240, 279, "beach")}
    L.warps = [{"entry": exit_mouth, "kind": "right", "arrive": arrive, "arrive_kind": "up", "area": "exit"}]
    return L


# =========================================================================
# castles — the last course of every world: fire bars, lava bubbles,
# a power-up before the arena and the boss. Harder with every world.
# =========================================================================
CASTLE_NAMES = {1: "STONE KEEP", 2: "MAGMA FORT", 3: "SUN CITADEL", 4: "FROST BASTION", 5: "STORM CITADEL",
                6: "TIDE FORTRESS"}


# Castle sections (v0.14: every castle gets its own mix — before, 3-3 and 4-3
# were identical and 2-3/5-3/6-3 nearly so; player feedback). Column ranges:
# A 12-24, B 26-47, C 50-65, D 68-91; each section rebuilds its own floor.
def _castle_a_pillars(L, world):
    """lava pit with two stone pillars (first castle: 3 wide)"""
    L.lava(12, 23)
    if world == 1:
        L.fill(14, 16, 14, ROWS - 1, "#")
        L.fill(19, 21, 14, ROWS - 1, "#")
    else:
        L.fill(15, 16, 14, ROWS - 1, "#")
        L.fill(20, 21, 13 if world >= 3 else 14, ROWS - 1, "#")
    for c in (13, 18, 23) if world > 1 else (13, 18):
        L.set(c, GROUND + 1, "b")
    L.coin_arc(12, 10, 12)


def _castle_a_steps(L, world):
    """hard-block stepping stones going up and down over lava"""
    L.lava(12, 24)
    L.fill(14, 15, 15, ROWS - 1, "X")
    L.fill(18, 19, 13, ROWS - 1, "X")
    L.fill(22, 23, 15, ROWS - 1, "X")
    for c in (13, 17, 21):
        L.set(c, GROUND + 1, "b")
    L.coins(14, 12, 2)
    L.coins(18, 10, 2)
    L.coins(22, 12, 2)


def _castle_b_walkway(L, world):
    """walkway with fire bars on single floor blocks (jump over them)"""
    L.decor(26, "*", 3)
    L.set(29, GROUND - 1, "F")
    L.set(37, GROUND - 1, "F")
    if world >= 2:
        L.set(45, GROUND - 1, "F")
    L.fill(33, 33, 3, 8, "#")
    L.set(33, 9, "F")
    L.decor(41, "+", 12)
    L.coins(30, 12, 3)
    L.coins(38, 12, 3)


def _castle_b_brickbridge(L, world):
    """brick bridge over a lava moat, two holes, a fire bar sweeping it"""
    L.lava(27, 46)
    L.fill(27, 46, 15, 15, "w")
    for c0 in (32, 40):
        L.fill(c0, c0 + 1, 15, 15, ".")
        L.set(c0, GROUND + 1, "b")
        L.coins(c0, 12, 2)
    L.set(36, 10, "F")
    L.decor(29, "+", 14)
    L.decor(44, "+", 14)


def _castle_b_lifts(L, world):
    """two sideways lifts over a lava moat"""
    L.lava(27, 46)
    L.set(28, 14, "~")
    L.set(37, 13, "~")
    for c in (33, 44):
        L.set(c, GROUND + 1, "b")
    L.coins(33, 10, 3)
    L.coins(41, 9, 3)


def _castle_c_low(L, world):
    """low ceiling passage with ? blocks, a fire bar block in mid-air"""
    L.fill(50, 64, 3, 8, "#")
    L.blocks(52, 13, "B?B")
    L.set(58, 12, "F")
    if world >= 3:
        L.set(62, GROUND - 1, "F")
    L.decor(55, "f")


def _castle_c_slabs(L, world):
    """falling slabs over lava: keep moving"""
    L.lava(50, 64)
    for c, r in ((51, 15), (55, 14), (59, 15)):
        L.set(c, r, "D")
    L.set(63, GROUND + 1, "b")
    L.coins(55, 11, 3)


def _castle_c_tips(L, world):
    """two tipping planks over lava"""
    L.lava(50, 64)
    L.set(51, 15, "T")
    L.set(57, 14, "T")
    L.set(56, GROUND + 1, "b")
    L.coins(57, 11, 4)


def _castle_d_lake(L, world):
    """lava lake with narrow ledges, bubbles, a fire bar in the middle"""
    hard = world >= 3
    L.lava(68, 90 if hard else 87)
    L.ledge(71, 72, 14)
    L.ledge(76, 78, 12)
    if world >= 2:
        L.set(77, 11, "F")
    if hard:
        L.set(81, 14, "^")
        L.ledge(86, 87, 13)
    else:
        L.ledge(82, 83, 14)
    for c in (69, 74, 80, 85):
        L.set(c, GROUND + 1, "b")
    L.coins(76, 9, 3)


def _castle_d_bubbles(L, world):
    """stepping pillars between five leaping lava bubbles"""
    L.lava(68, 90)
    for c0, top in ((71, 15), (76, 14), (81, 15), (86, 14)):
        L.fill(c0, c0 + 1, top, ROWS - 1, "X")
        L.coins(c0, top - 3, 2)
    for c in (69, 74, 79, 84, 89):
        L.set(c, GROUND + 1, "b")


def _castle_d_vlifts(L, world):
    """four rising lifts over lava (wait for the right height)"""
    L.lava(68, 90)
    for c, r in ((70, 15), (76, 14), (82, 15), (87, 14)):
        L.set(c, r, "^")
    for c in (74, 80, 85):
        L.set(c, GROUND + 1, "b")
    L.coins(77, 8, 3)


CASTLE_PLAN = {
    # world: (A, B, C, D, area theme)
    1: (_castle_a_pillars, _castle_b_walkway, _castle_c_low, _castle_d_lake, "fortress"),
    2: (_castle_a_steps, _castle_b_brickbridge, _castle_c_low, _castle_d_bubbles, "fortress_magma"),
    3: (_castle_a_pillars, _castle_b_lifts, _castle_c_tips, _castle_d_lake, "fortress_sun"),
    4: (_castle_a_steps, _castle_b_walkway, _castle_c_slabs, _castle_d_bubbles, "fortress_ice"),
    5: (_castle_a_steps, _castle_b_lifts, _castle_c_tips, _castle_d_vlifts, "fortress_storm"),
    6: (_castle_a_pillars, _castle_b_brickbridge, _castle_c_slabs, _castle_d_vlifts, "fortress_tide"),
}


def castle_level(world, lid):
    L = Level(lid, CASTLE_NAMES[world], 160, time=300)
    L.top = 6
    A0 = 120
    A1 = A0 + 37
    L.ground(0, 159)
    L.ceiling(0, 159, 3)
    sec_a, sec_b, sec_c, sec_d, theme = CASTLE_PLAN[world]
    # entrance hall
    for c in (2, 9):
        L.decor(c, "+", 12)
    L.decor(5, "*", 3)
    L.blocks(6, 13, "?M?")
    sec_a(L, world)
    sec_b(L, world)
    sec_c(L, world)
    sec_d(L, world)
    # E: last stretch — power-up + coins before the boss, a world touch
    L.decor(94, "*", 3)
    L.blocks(98, 13, "?M?")
    L.coins(104, 13, 6)
    L.decor(96, "+", 12)
    L.decor(110, "+", 12)
    L.decor(116, "f")
    if world >= 2:
        L.set(107, GROUND - 1, "F")
    if world == 2:
        L.enemy(103, ch="k")
    elif world == 3:
        L.enemy(103, ch="p")
    elif world == 4:
        L.fill(94, 105, GROUND, GROUND, "I")      # icy floor
        L.enemy(102, ch="q")
    elif world == 5:
        L.enemy(103, ch="x")
    elif world == 6:
        L.enemy(101, ch="z")
        L.enemy(105, ch="z")
    # arena (38 columns) with a lava moat near the right wall
    L.decor(A0 + 6, "*", 3)
    L.decor(A0 + 18, "*", 3)
    L.decor(A0 + 30, "*", 3)
    for c in (A0 + 4, A0 + 14, A0 + 24):
        L.decor(c, "+", 12)
    L.fill(A1 - 1, 159, 3, GROUND - 1, "w")
    L.set(A1 - 8, GROUND - 1, "Z")
    L.arena = (A0, A1)
    L.start = (3, GROUND - 1)
    L.checkpoints.append((96, GROUND - 1))
    # boss checkpoint + guaranteed fire flower right before the arena; a
    # restart here always begins with fire power (game.gd _is_boss_spawn)
    L.checkpoints.append((A0 - 7, GROUND - 1))
    L.set(A0 - 4, 13, "N")
    L.areas = {"main": (0, 159, theme)}
    return L


# =========================================================================
# preview rendering (uses the real generated art)
# =========================================================================
def render_preview(L, path):
    from PIL import Image
    gfx = os.path.join(ROOT, "assets", "graphics")
    tiles = Image.open(os.path.join(gfx, "tiles.png")).convert("RGBA")
    blocks = Image.open(os.path.join(gfx, "blocks.png")).convert("RGBA")
    shroom = Image.open(os.path.join(gfx, "enemy_shroom.png")).convert("RGBA").crop((0, 0, 26, 18))
    turtle = Image.open(os.path.join(gfx, "enemy_turtle.png")).convert("RGBA").crop((0, 0, 28, 26))
    turtle_r = Image.open(os.path.join(gfx, "enemy_turtle_red.png")).convert("RGBA").crop((0, 0, 28, 26))
    boss_im = Image.open(os.path.join(gfx, "boss_1.png")).convert("RGBA").crop((0, 0, 32, 34))
    bubble = Image.open(os.path.join(gfx, "lava_bubble.png")).convert("RGBA")
    lift_im = Image.open(os.path.join(gfx, "lift.png")).convert("RGBA")
    bat_im = Image.open(os.path.join(gfx, "enemy_bat.png")).convert("RGBA").crop((0, 0, 18, 12))
    pen_im = Image.open(os.path.join(gfx, "enemy_penguin.png")).convert("RGBA").crop((0, 0, 18, 18))
    cac_seg = Image.open(os.path.join(gfx, "enemy_cactus.png")).convert("RGBA").crop((0, 0, 16, 17))
    cac_head = Image.open(os.path.join(gfx, "enemy_cactus.png")).convert("RGBA").crop((16, 0, 32, 17))
    coin = Image.open(os.path.join(gfx, "coin.png")).convert("RGBA").crop((0, 0, 12, 16))
    decor = Image.open(os.path.join(gfx, "decor.png")).convert("RGBA")
    hero = Image.open(os.path.join(gfx, "hero_small.png")).convert("RGBA").crop((0, 0, 20, 20))
    drop_im = Image.open(os.path.join(gfx, "drop.png")).convert("RGBA")
    tip_im = Image.open(os.path.join(gfx, "tipper.png")).convert("RGBA")
    imp_im = Image.open(os.path.join(gfx, "enemy_imp.png")).convert("RGBA").crop((0, 0, 24, 28))
    spiky_im = Image.open(os.path.join(gfx, "enemy_spiky.png")).convert("RGBA").crop((0, 0, 18, 16))
    gull_im = Image.open(os.path.join(gfx, "enemy_gull.png")).convert("RGBA").crop((0, 0, 22, 12))
    fish_im = Image.open(os.path.join(gfx, "enemy_fish.png")).convert("RGBA").crop((0, 0, 16, 10))
    fishr_im = Image.open(os.path.join(gfx, "enemy_fish_red.png")).convert("RGBA").crop((0, 0, 16, 10))
    jelly_im = Image.open(os.path.join(gfx, "enemy_jelly.png")).convert("RGBA").crop((0, 0, 16, 15))
    crab_im = Image.open(os.path.join(gfx, "enemy_crab.png")).convert("RGBA").crop((0, 0, 14, 13))
    urch_im = Image.open(os.path.join(gfx, "enemy_urchin.png")).convert("RGBA").crop((0, 0, 18, 18))
    import re
    idx = {}
    for line in open(os.path.join(ROOT, "decor_index.gd")):
        m = re.match(r'\s*"(\w+)": Rect2\((\d+), (\d+), (\d+), (\d+)\)', line)
        if m:
            n, x, y, w, h = m.group(1), *map(int, m.groups()[1:])
            idx[n] = decor.crop((x, y, x + w, y + h))
    T = 16
    W, H = L.cols * T, ROWS * T
    img = Image.new("RGBA", (W, H), (110, 170, 240, 255))

    def tile(ax, ay):
        return tiles.crop((ax * T, ay * T, ax * T + T, ay * T + T))

    def blk(i):
        return blocks.crop((i * T, 0, i * T + T, T))

    def solid_ground(c, r, ch):
        if c < 0 or c >= L.cols or r >= ROWS:
            return True
        if r < 0:
            return False
        return L.g[r][c] == ch

    deco_map = {"*": "bush_l", "+": "bush_s", "f": "flower_a", "t": "tuft", "r": "rock", "s": "sign", "n": "fence"}
    biome_deco = {
        "sand": {"*": "cactus_l", "+": "cactus_s", "f": "dflower", "t": "tuft_sand", "r": "rock_sand"},
        "snow": {"*": "pine", "+": "bush_snow", "f": "frost", "t": "tuft_snow", "r": "rock_snow"},
        "cave": {"*": "crystal_l", "+": "crystal_s", "f": "glowshroom", "t": "tuft_cave", "r": "rock_cave"},
        "castle": {"*": "banner", "+": "torch", "f": "skull", "t": "torch", "r": "rock_castle"},
        "sky": {"*": "sky_bush_l", "+": "sky_bush_s", "f": "sky_flower", "t": "tuft_sky", "r": "rock_sky"},
        "sea": {"*": "seaweed", "+": "coral", "f": "starfish", "t": "tuft_sea", "r": "rock_sea"},
        "beach": {"*": "palm", "+": "palm", "f": "starfish", "t": "tuft_sand", "r": "rock_sand"},
    }
    col_biome = ["grass"] * L.cols
    for c0, c1, theme in L.areas.values():
        for c in range(c0, min(c1 + 1, L.cols)):
            col_biome[c] = THEME_BIOME.get(theme, "grass")
    later = []
    for r in range(ROWS):
        for c in range(L.cols):
            ch = L.g[r][c]
            x, y = c * T, r * T
            bio = col_biome[c]
            if ch in "#c":
                m = 0
                if not solid_ground(c, r - 1, ch):
                    m |= 1
                if not solid_ground(c, r + 1, ch):
                    m |= 2
                if not solid_ground(c - 1, r, ch):
                    m |= 4
                if not solid_ground(c + 1, r, ch):
                    m |= 8
                row = {"grass": 0, "cave": 3, "sand": 4, "snow": 5, "castle": 7, "sky": 9, "sea": 11,
                       "beach": 4}[bio] if ch == "#" else 3
                img.alpha_composite(tile(m, row), (x, y))
            elif ch == "I":
                img.alpha_composite(tile(8, 6), (x, y))
            elif ch in "Lb":
                later.append((tile(13 if L.get(c, r - 1) in "Lb" else 9, 6), x, y))
                if ch == "b":
                    later.append((bubble, x + 1, y - 40))
            elif ch == "F":
                img.alpha_composite(blk(7), (x, y))
                later.append((bubble.resize((6, 6)), x + 5, y - 30))
            elif ch == "Z":
                later.append((boss_im, x - 8, y - 18))
            elif ch in "~^":
                later.append((lift_im, x - 1, y - 1))
            elif ch == "D":
                later.append((drop_im, x - 1, y - 1))
            elif ch == "T":
                later.append((tip_im, x - 1, y - 1))
            elif ch == "u":
                later.append((imp_im, x - 4, y - 12))
            elif ch == "x":
                later.append((spiky_im, x - 1, y))
            elif ch == "y":
                later.append((gull_im, x - 3, y + 4))
            elif ch in "eE":
                later.append((fishr_im if ch == "E" else fish_im, x, y + 6))
            elif ch == "j":
                later.append((jelly_im, x, y + 1))
            elif ch == "z":
                later.append((crab_im, x + 1, y + 3))
            elif ch == "i":
                later.append((urch_im, x - 1, y - 2))
            elif ch == "a":
                later.append((bat_im, x - 1, y))
            elif ch == "q":
                later.append((pen_im, x - 1, y - 2))
            elif ch == "p":
                for i in range(3):
                    later.append((cac_head if i == 2 else cac_seg, x, y - 1 - i * 11))
            elif ch == "X":
                img.alpha_composite(blk(7), (x, y))
            elif ch == "w":
                if bio == "castle":
                    img.alpha_composite(tile(2, 8), (x, y))
                elif bio in ("sand", "snow"):
                    img.alpha_composite(tile(14 if bio == "sand" else 15, 6), (x, y))
                elif bio == "sky":
                    img.alpha_composite(tile(3, 10), (x, y))
                elif bio == "sea":
                    img.alpha_composite(tile(6, 10), (x, y))
                elif bio == "beach":
                    img.alpha_composite(tile(14, 6), (x, y))
                else:
                    img.alpha_composite(blk(6), (x, y))
            elif ch == "=":
                img.alpha_composite(tile(1, 10) if bio == "sky" else tile(6, 1), (x, y))
            elif ch == "v":
                later.append((tile(15 if L.get(c, r - 1) == "v" else 11, 1), x, y))
            elif ch in "?MYN":
                img.alpha_composite(blk(0), (x, y))
            elif ch in "BSCU":
                img.alpha_composite(blk(5), (x, y))
            elif ch == "h":
                pass
            elif ch in "PWQ":
                img.alpha_composite(tile(0, 2), (x, y))
                img.alpha_composite(tile(1, 2), (x + T, y))
                rr = r + 1
                while rr < ROWS and L.g[rr][c] not in "#cXwI":
                    img.alpha_composite(tile(2, 2), (c * T, rr * T))
                    img.alpha_composite(tile(3, 2), (c * T + T, rr * T))
                    rr += 1
            elif ch == ">":
                img.alpha_composite(tile(4, 2), (x, y))
                img.alpha_composite(tile(5, 2), (x, y + T))
                cc = c + 1
                while cc < L.cols and L.g[r][cc] == ".":
                    img.alpha_composite(tile(6, 2), (cc * T, y))
                    img.alpha_composite(tile(7, 2), (cc * T, y + T))
                    cc += 1
            elif ch == "o":
                later.append((coin, x + 2, y))
            elif ch in "gG":
                later.append((shroom, x - 5, y - 2))
            elif ch in "kKJ":
                later.append((turtle_r if ch == "K" else turtle, x - 6, y - 10))
            elif ch in deco_map:
                d = idx[biome_deco.get(bio, {}).get(ch, deco_map[ch])]
                later.append((d, x + (T - d.size[0]) // 2, y + T - d.size[1]))
    for im, x, y in later:
        img.alpha_composite(im, (x, y))
    if L.flag and L.flag[0] >= 0:
        c, r = L.flag
        pole = idx["pole"]
        for k in range(1, 10):
            img.alpha_composite(pole, (c * T + 6, (r - k) * T))
        img.alpha_composite(idx["pole_ball"], (c * T + 4, (r - 10) * T + 8))
        img.alpha_composite(idx["flag"], (c * T - 9, (r - 9) * T + 2))
    if L.castle and L.castle[0] >= 0:
        c, r = L.castle
        cs = idx["castle"]
        img.alpha_composite(cs, (c * T, (r + 1) * T - cs.size[1]))
    sc, sr = L.start
    img.alpha_composite(hero, (sc * T - 2, (sr + 1) * T - 20))
    # split into strips so it stays readable
    strip_w = 64 * T
    n = (W + strip_w - 1) // strip_w
    out = Image.new("RGBA", (strip_w, n * (H + 8)), (30, 30, 30, 255))
    for i in range(n):
        out.paste(img.crop((i * strip_w, 0, min(W, (i + 1) * strip_w), H)), (0, i * (H + 8)))
    out.save(path)


if __name__ == "__main__":
    os.makedirs(LEVEL_DIR, exist_ok=True)
    level_1_1().emit()
    level_1_2().emit()
    level_1_3().emit()
    castle_level(1, "1-4").emit()
    level_2_1().emit()
    level_2_2().emit()
    castle_level(2, "2-3").emit()
    level_3_1().emit()
    level_3_2().emit()
    castle_level(3, "3-3").emit()
    level_4_1().emit()
    level_4_2().emit()
    castle_level(4, "4-3").emit()
    level_5_1().emit()
    level_5_2().emit()
    castle_level(5, "5-3").emit()
    level_6_1().emit()
    level_6_2().emit()
    castle_level(6, "6-3").emit()
