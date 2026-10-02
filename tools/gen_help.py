#!/usr/bin/env python3
"""Illustrated How-to-Play pages (global CLAUDE.md #15: pictures, not just
words — incl. D-pad/buttons and the mute button).

    python3 tools/gen_help.py

Rendered at 1:1 design pixels (340x170, shown with NEAREST filtering in the
help panel) using the game's own sprites and pixel font, so the pages look
like part of the game. Output: assets/graphics/help/<page>.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GFX = os.path.join(ROOT, "assets", "graphics")
OUT = os.path.join(GFX, "help")
FONT = os.path.join(ROOT, "assets", "ui", "pixel_font.ttf")
W, H = 340, 170
BG = (14, 18, 40, 255)
INK = (26, 16, 24, 255)
WHITE = (255, 255, 255, 255)
GOLD = (255, 216, 60, 255)
DIM = (170, 180, 210, 255)
KEY = (52, 60, 98, 255)
KEY_EDGE = (120, 132, 190, 255)

f8 = ImageFont.truetype(FONT, 8)
f16 = ImageFont.truetype(FONT, 16)


def sheet_frame(name, cell_w, cell_h, idx=0):
    im = Image.open(os.path.join(GFX, name + ".png")).convert("RGBA")
    return im.crop((idx * cell_w, 0, idx * cell_w + cell_w, cell_h))


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def new_page():
    img = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(img)
    return img, d


def text(d, xy, s, font=f8, fill=WHITE, anchor="la"):
    x, y = xy
    d.text((x + 1, y + 1), s, font=font, fill=INK, anchor=anchor)
    d.text((x, y), s, font=font, fill=fill, anchor=anchor)


def key(d, x, y, label, w=None):
    w = w or max(14, int(d.textlength(label, font=f8)) + 7)
    d.rounded_rectangle((x, y, x + w, y + 13), 2, fill=KEY, outline=KEY_EDGE)
    d.line((x + 2, y + 12, x + w - 2, y + 12), fill=(30, 34, 60, 255))
    d.text((x + w / 2, y + 3), label, font=f8, fill=WHITE, anchor="ma")
    return x + w + 3


def arrow_key(d, x, y, direction):
    d.rounded_rectangle((x, y, x + 14, y + 13), 2, fill=KEY, outline=KEY_EDGE)
    cx, cy = x + 7, y + 6
    pts = {"left": [(cx - 3, cy), (cx + 2, cy - 3), (cx + 2, cy + 3)],
           "right": [(cx + 3, cy), (cx - 2, cy - 3), (cx - 2, cy + 3)],
           "up": [(cx, cy - 3), (cx - 3, cy + 2), (cx + 3, cy + 2)],
           "down": [(cx, cy + 3), (cx - 3, cy - 2), (cx + 3, cy - 2)]}[direction]
    d.polygon(pts, fill=WHITE)
    return x + 17


def round_btn(d, x, y, label, col):
    d.ellipse((x, y, x + 13, y + 13), fill=col, outline=INK)
    d.text((x + 7, y + 3), label, font=f8, fill=WHITE, anchor="ma")


def dpad(d, x, y):
    s = 7
    body = (60, 66, 96, 255)
    d.rectangle((x + s, y, x + 2 * s, y + 3 * s), fill=body, outline=KEY_EDGE)
    d.rectangle((x, y + s, x + 3 * s, y + 2 * s), fill=body, outline=KEY_EDGE)
    d.rectangle((x + s + 1, y + s, x + 2 * s - 1, y + 2 * s), fill=body)
    for (px, py, dirn) in ((x + 10, y + 2, "u"), (x + 10, y + 18, "d"), (x + 2, y + 10, "l"), (x + 18, y + 10, "r")):
        if dirn == "u":
            d.polygon([(px, py), (px - 2, py + 2), (px + 2, py + 2)], fill=WHITE)
        elif dirn == "d":
            d.polygon([(px, py + 2), (px - 2, py), (px + 2, py)], fill=WHITE)
        elif dirn == "l":
            d.polygon([(px, py), (px + 2, py - 2), (px + 2, py + 2)], fill=WHITE)
        else:
            d.polygon([(px + 2, py), (px, py - 2), (px, py + 2)], fill=WHITE)


def speaker(d, x, y, col=WHITE):
    d.polygon([(x, y + 4), (x + 3, y + 4), (x + 7, y), (x + 7, y + 12), (x + 3, y + 8), (x, y + 8)], fill=col)
    d.arc((x + 5, y + 1, x + 13, y + 11), -50, 50, fill=col)


def glass_btn(d, x, y, content):
    d.rounded_rectangle((x, y, x + 18, y + 18), 4, fill=(40, 46, 80, 255), outline=GOLD)
    if content == "pause":
        d.rectangle((x + 6, y + 5, x + 7, y + 13), fill=WHITE)
        d.rectangle((x + 11, y + 5, x + 12, y + 13), fill=WHITE)
    else:
        speaker(d, x + 3, y + 3)


# --------------------------------------------------------------------- pages
def page_controls():
    img, d = new_page()
    text(d, (8, 6), "KEYBOARD", f8, GOLD)
    y = 20
    x = arrow_key(d, 8, y, "left")
    x = arrow_key(d, x, y, "right")
    x = key(d, x + 2, y, "A")
    x = key(d, x, y, "D")
    text(d, (x + 4, y + 3), "move")
    y += 17
    x = key(d, 8, y, "Space")
    x = key(d, x, y, "Z")
    x = arrow_key(d, x, y, "up")
    text(d, (x + 4, y + 1), "jump (hold = higher,")
    text(d, (x + 4, y + 10), "again in the air = double)", fill=DIM)
    y += 23
    x = key(d, 8, y, "Shift")
    x = key(d, x, y, "X")
    x = key(d, x, y, "J")
    text(d, (x + 4, y + 3), "run / fireball / tongue")
    y += 17
    x = arrow_key(d, 8, y, "down")
    x = key(d, x, y, "S")
    text(d, (x + 4, y + 3), "duck / enter pipe")
    y += 17
    x = key(d, 8, y, "Esc")
    x = key(d, x, y, "P")
    text(d, (x + 4, y + 3), "pause")
    x = key(d, 118, y, "M")
    text(d, (x + 4, y + 3), "mute")
    y += 17
    x = key(d, 8, y, "F12")
    text(d, (x + 4, y + 3), "screenshot")
    # divider
    d.line((200, 8, 200, 162), fill=(60, 70, 110, 255))
    text(d, (210, 6), "GAMEPAD", f8, GOLD)
    dpad(d, 212, 22)
    text(d, (240, 30), "move, duck")
    round_btn(d, 230, 58, "Y", (60, 150, 60, 255))
    round_btn(d, 216, 72, "X", (60, 90, 200, 255))
    round_btn(d, 244, 72, "B", (200, 60, 60, 255))
    round_btn(d, 230, 86, "A", (220, 170, 40, 255))
    text(d, (264, 56), "A B: jump,")
    text(d, (264, 66), "2x = double", fill=DIM)
    text(d, (264, 76), "X Y: run,")
    text(d, (264, 86), "fire, tongue")
    d.rounded_rectangle((212, 110, 234, 118), 4, fill=(60, 66, 96, 255), outline=KEY_EDGE)
    text(d, (240, 110), "Start: pause")
    d.rounded_rectangle((212, 124, 234, 132), 4, fill=(60, 66, 96, 255), outline=KEY_EDGE)
    text(d, (240, 124), "Select: mute")
    glass_btn(d, 212, 142, "speaker")
    glass_btn(d, 234, 142, "pause")
    text(d, (258, 147), "or click", fill=DIM)
    text(d, (8, 158), "Change keys + buttons: Settings > Controls", fill=GOLD)
    return img


def page_touch():
    img, d = new_page()
    # mock phone screen
    d.rounded_rectangle((20, 18, 320, 150), 8, fill=(90, 150, 230, 255), outline=WHITE)
    d.rectangle((22, 126, 318, 148), fill=(120, 80, 40, 255))
    d.rectangle((22, 122, 318, 126), fill=(90, 190, 60, 255))
    hero = trim(sheet_frame("hero_small", 20, 20))
    img.alpha_composite(hero.resize((hero.width * 2, hero.height * 2), Image.NEAREST), (150, 122 - hero.height * 2))
    btn = {}
    for n in ("left", "right", "down", "b", "a"):
        b = Image.open(os.path.join(ROOT, "assets", "ui", "touch_%s.png" % n)).convert("RGBA").resize((24, 24), Image.LANCZOS)
        btn[n] = b
    img.alpha_composite(btn["left"], (28, 118))
    img.alpha_composite(btn["down"], (54, 121))
    img.alpha_composite(btn["right"], (80, 118))
    img.alpha_composite(btn["b"], (262, 120))
    img.alpha_composite(btn["a"], (290, 110))
    glass_btn(d, 272, 24, "speaker")
    glass_btn(d, 294, 24, "pause")
    text(d, (28, 96), "move, down = duck", fill=GOLD)
    text(d, (28, 106), "/ enter pipe", fill=GOLD)
    text(d, (240, 96), "X: run / fire", fill=GOLD)
    text(d, (240, 76), "A: jump,", fill=GOLD)
    text(d, (240, 86), "2x = double", fill=GOLD)
    text(d, (212, 28), "mute  pause", fill=GOLD)
    text(d, (34, 24), "Use both thumbs:", fill=WHITE)
    text(d, (34, 34), "hold X while moving to run.", fill=WHITE)
    text(d, (20, 156), "Riding the dragon? Down + A: hop off.", fill=DIM)
    return img


def item_row(img, d, y, sprite, label, x=10):
    img.alpha_composite(sprite, (x + (18 - sprite.width) // 2, y + (18 - sprite.height) // 2))
    text(d, (x + 24, y + 5), label)


def page_items():
    img, d = new_page()
    text(d, (8, 6), "HIT BLOCKS FROM BELOW", f8, GOLD)
    q = sheet_frame("blocks", 16, 16, 0)
    brick = sheet_frame("blocks", 16, 16, 5)
    coin = trim(sheet_frame("coin", 12, 16, 0))
    mush = trim(sheet_frame("powerups", 18, 17, 0))
    oneup = trim(sheet_frame("powerups", 18, 17, 1))
    flower = trim(sheet_frame("powerups", 18, 17, 2))
    star = trim(sheet_frame("powerups", 18, 17, 6))
    item_row(img, d, 20, q, "? block: coin or item")
    item_row(img, d, 40, brick, "brick: breaks when big")
    item_row(img, d, 60, coin, "coin: points, 100 = 1UP")
    item_row(img, d, 80, mush, "mushroom: grow big")
    item_row(img, d, 100, flower, "fire flower: fireballs")
    item_row(img, d, 120, star, "star: invincible")
    item_row(img, d, 140, oneup, "green: extra life")
    # right side: grow sequence
    small = trim(sheet_frame("hero_small", 20, 20, 0))
    big = trim(sheet_frame("hero_big", 20, 32, 0))
    fire = trim(sheet_frame("hero_fire", 20, 32, 0))
    x0 = 196
    img.alpha_composite(small, (x0, 80 - small.height))
    text(d, (x0 + 18, 66), ">", fill=GOLD)
    img.alpha_composite(big, (x0 + 30, 80 - big.height))
    text(d, (x0 + 50, 66), ">", fill=GOLD)
    img.alpha_composite(fire, (x0 + 62, 80 - fire.height))
    fb = trim(sheet_frame("fireball", 8, 8, 0))
    img.alpha_composite(fb, (x0 + 84, 64))
    img.alpha_composite(fb, (x0 + 100, 70))
    text(d, (x0, 88), "A hit makes you", fill=DIM)
    text(d, (x0, 98), "one size smaller.", fill=DIM)
    text(d, (x0, 116), "Hidden blocks exist -", fill=DIM)
    text(d, (x0, 126), "jump where it looks", fill=DIM)
    text(d, (x0, 136), "suspicious!", fill=DIM)
    return img


def page_dragon():
    img, d = new_page()
    text(d, (8, 6), "YOUR DRAGON FRIEND", f8, GOLD)
    egg = trim(sheet_frame("egg", 16, 16, 0))
    dino = trim(sheet_frame("dino", 28, 32, 0))
    q = sheet_frame("blocks", 16, 16, 0)
    img.alpha_composite(q, (14, 40))
    img.alpha_composite(egg, (14 + (16 - egg.width) // 2, 40 - egg.height))
    text(d, (36, 38), ">", fill=GOLD)
    img.alpha_composite(dino, (46, 58 - dino.height))
    text(d, (10, 64), "An egg hides in a", fill=WHITE)
    text(d, (10, 74), "? block. It hatches!", fill=WHITE)
    # riding
    rider = trim(sheet_frame("hero_small", 20, 20, 8))
    comp = Image.new("RGBA", (40, 40), (0, 0, 0, 0))
    comp.alpha_composite(dino, (6, 40 - dino.height))
    comp.alpha_composite(rider, (6 + dino.width // 2 - rider.width // 2 - 4, 40 - 13 - rider.height))
    img.alpha_composite(comp, (130, 20))
    text(d, (176, 26), "Jump onto its saddle", fill=WHITE)
    text(d, (176, 36), "to ride it.", fill=WHITE)
    # tongue
    eat = trim(sheet_frame("dino", 28, 32, 5))
    img.alpha_composite(eat, (130, 110 - eat.height))
    d.rectangle((130 + eat.width - 4, 110 - 22, 130 + eat.width + 26, 110 - 20), fill=(255, 106, 138, 255))
    d.rectangle((130 + eat.width + 24, 110 - 24, 130 + eat.width + 29, 110 - 19), fill=(255, 106, 138, 255), outline=INK)
    shroom = trim(sheet_frame("enemy_shroom", 18, 17, 0))
    img.alpha_composite(shroom, (130 + eat.width + 32, 110 - shroom.height))
    text(d, (176, 66), "Run button (B / X / Shift):", fill=WHITE)
    text(d, (176, 76), "tongue eats enemies.", fill=WHITE)
    text(d, (10, 124), "Down + jump: hop off.", fill=WHITE)
    text(d, (10, 136), "Hit while riding? You fall off and the", fill=DIM)
    text(d, (10, 146), "dragon runs away - catch it again!", fill=DIM)
    text(d, (10, 158), "It stays with you into the next course.", fill=DIM)
    return img


def page_goal():
    img, d = new_page()
    text(d, (8, 6), "GOAL & POINTS", f8, GOLD)
    shroom = trim(sheet_frame("enemy_shroom", 18, 17, 0))
    squish = trim(sheet_frame("enemy_shroom", 18, 17, 2))
    jump = trim(sheet_frame("hero_small", 20, 20, 4))
    img.alpha_composite(jump, (12, 20))
    img.alpha_composite(shroom, (14, 42))
    text(d, (36, 22), "Stomp enemies from above.")
    text(d, (36, 32), "Chain stomps without landing:")
    text(d, (36, 42), "100 200 400 800 ... 1UP", fill=GOLD)
    text(d, (10, 64), "Enemies hurt you from the side.")
    pipe = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    top = Image.new("RGBA", (32, 24), (0, 0, 0, 0))
    top.alpha_composite(pipe.crop((0, 32, 32, 48)), (0, 0))
    top.alpha_composite(pipe.crop((32, 32, 64, 40)), (0, 16))
    img.alpha_composite(top, (12, 84))
    text(d, (50, 86), "Some pipes lead to secret")
    text(d, (50, 96), "coin rooms: stand on top, press down.")
    text(d, (10, 122), "Midway flag = restart point.")
    text(d, (10, 140), "Extra lives for points?", fill=DIM)
    text(d, (10, 150), "Settings > 1-UP points", fill=GOLD)
    # flag pole table
    x0 = 232
    d.line((x0 + 2, 18, x0 + 2, 150), fill=(122, 200, 112, 255), width=2)
    d.ellipse((x0 - 1, 14, x0 + 5, 20), fill=(60, 196, 60, 255), outline=INK)
    d.rectangle((x0 - 5, 150, x0 + 9, 162), fill=(200, 146, 90, 255), outline=INK)
    rows = [("5000", 22), ("2000", 50), ("800", 78), ("400", 106), ("100", 134)]
    for pts, y in rows:
        d.line((x0 + 6, y + 4, x0 + 14, y + 4), fill=DIM)
        text(d, (x0 + 18, y), pts, fill=GOLD)
    text(d, (x0 + 46, 22), "Grab the", fill=WHITE)
    text(d, (x0 + 46, 32), "pole high!", fill=WHITE)
    text(d, (x0 + 46, 60), "Time left", fill=WHITE)
    text(d, (x0 + 46, 70), "x 50 bonus", fill=WHITE)
    return img


def page_worlds():
    img, d = new_page()
    text(d, (8, 6), "TURTLES & WORLDS", f8, GOLD)
    walk = trim(sheet_frame("enemy_turtle", 28, 26, 0))
    shell = trim(sheet_frame("enemy_turtle", 28, 26, 2))
    red = trim(sheet_frame("enemy_turtle_red", 28, 26, 0))
    fly = trim(sheet_frame("enemy_turtle", 28, 26, 7))
    jump = trim(sheet_frame("hero_small", 20, 20, 4))
    img.alpha_composite(walk, (12, 26))
    text(d, (32, 34), ">", fill=GOLD)
    img.alpha_composite(jump, (42, 16))
    img.alpha_composite(shell, (42, 38))
    text(d, (64, 34), ">", fill=GOLD)
    img.alpha_composite(shell, (74, 38))
    for i in range(3):
        d.line((94 + i * 4, 40 + i * 3, 100 + i * 4, 40 + i * 3), fill=DIM)
    text(d, (116, 20), "Stomp a turtle: it hides.")
    text(d, (116, 30), "Touch the shell to kick it -")
    text(d, (116, 40), "it knocks out every enemy", fill=GOLD)
    text(d, (116, 50), "in its way. Watch out when", fill=GOLD)
    text(d, (116, 60), "it bounces back!", fill=GOLD)
    img.alpha_composite(red, (12, 76))
    text(d, (32, 82), "Red turtles turn at edges.")
    img.alpha_composite(fly, (170, 74))
    text(d, (196, 82), "Winged: stomp twice.")
    tiles = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    img.alpha_composite(tiles.crop((8 * 16, 6 * 16, 9 * 16, 7 * 16)), (12, 110))
    text(d, (34, 114), "Ice is slippery - brake early.")
    img.alpha_composite(tiles.crop((9 * 16, 6 * 16, 10 * 16, 7 * 16)), (12, 134))
    text(d, (34, 138), "Lava and water: don't fall in!")
    bat = trim(sheet_frame("enemy_bat", 18, 12, 1))
    cac = Image.open(os.path.join(GFX, "enemy_cactus.png")).convert("RGBA")
    seg, head = trim(cac.crop((0, 0, 16, 17))), trim(cac.crop((16, 0, 32, 17)))
    pen = trim(sheet_frame("enemy_penguin", 18, 18, 0))
    img.alpha_composite(bat, (232, 99))
    text(d, (254, 94), "bats swoop:", fill=DIM)
    text(d, (254, 103), "duck or walk", fill=DIM)
    text(d, (254, 112), "under them", fill=DIM)
    img.alpha_composite(seg, (234, 136))
    img.alpha_composite(head, (234, 122))
    text(d, (254, 124), "cactus: spiky!", fill=DIM)
    text(d, (254, 134), "burn it (fire)", fill=DIM)
    img.alpha_composite(pen, (234, 148))
    text(d, (254, 152), "penguins slide", fill=DIM)
    return img


def page_sky():
    img, d = new_page()
    text(d, (8, 6), "SKY WORLD", f8, GOLD)
    tiles = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    drop = Image.open(os.path.join(GFX, "drop.png")).convert("RGBA")
    tip = Image.open(os.path.join(GFX, "tipper.png")).convert("RGBA")
    img.alpha_composite(drop, (8, 24))
    text(d, (62, 20), "Falling slab: it shakes,")
    text(d, (62, 30), "then drops - jump off in time!", fill=DIM)
    img.alpha_composite(tip.rotate(12, resample=Image.NEAREST, expand=True), (4, 44))
    text(d, (74, 46), "Tipping plank: tips toward")
    text(d, (74, 56), "your side - keep moving.", fill=DIM)
    for i in range(3):
        img.alpha_composite(tiles.crop((i * 16, 10 * 16, i * 16 + 16, 10 * 16 + 8)), (10 + i * 16, 76))
    text(d, (62, 76), "Clouds: jump up through them.")
    d.line((8, 92, 332, 92), fill=(60, 70, 110, 255))
    imp = trim(sheet_frame("enemy_imp", 24, 28, 2))
    spiky = trim(sheet_frame("enemy_spiky", 18, 16, 0))
    gull = trim(sheet_frame("enemy_gull", 22, 12, 0))
    bolt = trim(sheet_frame("bolt", 10, 16, 0))
    img.alpha_composite(imp, (8, 98))
    text(d, (36, 100), "Cloud imp throws spikies.")
    text(d, (36, 110), "Stomp it from up high!", fill=DIM)
    img.alpha_composite(spiky, (10, 132))
    text(d, (32, 130), "Spiky: never stomp!")
    text(d, (32, 140), "Fire, shells or a star.", fill=DIM)
    img.alpha_composite(gull, (186, 100))
    text(d, (212, 98), "Gulls glide at you:")
    text(d, (212, 108), "stomp or duck.", fill=DIM)
    img.alpha_composite(bolt, (192, 128))
    text(d, (212, 128), "Storm boss: lightning")
    text(d, (212, 138), "flashes first - step aside!", fill=DIM)
    text(d, (8, 157), "Fell off? The double jump helps (Settings).", fill=GOLD)
    return img


def page_sea():
    img, d = new_page()
    text(d, (8, 6), "SEA WORLD", f8, GOLD)
    hero = trim(sheet_frame("hero_small", 20, 20, 7))
    img.alpha_composite(hero, (12, 22))
    for i, (bx, by) in enumerate(((31, 32), (34, 26), (32, 20))):
        d.ellipse((bx, by, bx + 3 - (i == 2), by + 3 - (i == 2)), outline=(200, 235, 255, 255))
    text(d, (46, 20), "Underwater you swim: every press of")
    text(d, (46, 30), "jump is one stroke up. Tap it again", fill=DIM)
    text(d, (46, 40), "and again - slowly you sink.", fill=DIM)
    tl = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    for (tx, ty), (px_, py_) in (((4, 2), (12, 56)), ((5, 2), (12, 72)), ((6, 2), (28, 56)), ((7, 2), (28, 72))):
        img.alpha_composite(tl.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16)), (px_, py_))
    text(d, (50, 60), "The side pipe at the end leads")
    text(d, (50, 70), "to the beach with the flag pole.", fill=DIM)
    d.line((8, 90, 332, 90), fill=(60, 70, 110, 255))
    fish = trim(sheet_frame("enemy_fish", 16, 10, 0))
    fish_r = trim(sheet_frame("enemy_fish_red", 16, 10, 0))
    jelly = trim(sheet_frame("enemy_jelly", 16, 15, 0))
    crab = trim(sheet_frame("enemy_crab", 14, 13, 0))
    urch = trim(sheet_frame("enemy_urchin", 18, 18, 0))
    img.alpha_composite(fish, (8, 98))
    img.alpha_composite(fish_r, (8, 110))
    text(d, (30, 98), "Fish: can't be stomped")
    text(d, (30, 108), "while swimming - dodge", fill=DIM)
    text(d, (30, 118), "or use fire. Red = fast.", fill=DIM)
    img.alpha_composite(jelly, (180, 96))
    text(d, (200, 96), "Jellyfish pulse")
    text(d, (200, 106), "toward you.", fill=DIM)
    img.alpha_composite(crab, (180, 120))
    text(d, (200, 122), "Crabs: stomp them.")
    img.alpha_composite(urch, (8, 134))
    text(d, (30, 138), "Sea urchins can't be beaten: swim around them!")
    text(d, (8, 157), "The tide king knows every trick. Good luck!", fill=GOLD)
    return img


def page_water():
    """v1.3: castle pools (leap out at the surface) and currents"""
    img, d = new_page()
    text(d, (8, 6), "POOLS & CURRENTS", f8, GOLD)
    tl = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")

    def tile(tx, ty):
        return tl.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16))

    def water(x, y, top):
        w = tile(11 if top else 15, 1)
        a = w.getchannel("A").point(lambda v: v * 55 // 100)
        w.putalpha(a)
        img.alpha_composite(w, (x, y))

    # a pool between two rims, the hero leaping out onto the right one
    for y in (52, 68):
        img.alpha_composite(tile(2, 8), (10, y))
        img.alpha_composite(tile(2, 8), (90, y))
    for x in range(10, 106, 16):
        img.alpha_composite(tile(1, 7), (x, 84))
    for x in range(26, 90, 16):
        for y in (52, 68):
            water(x, y, y == 52)
    swim = trim(sheet_frame("hero_small", 20, 20, 7))
    img.alpha_composite(swim, (40, 60))
    jump = trim(sheet_frame("hero_small", 20, 20, 4))
    img.alpha_composite(jump, (86, 24))
    for k in range(11):                     # dotted leap arc: surface -> rim
        t = k / 10.0
        x = 52 + 36 * t
        y = 56 - 34 * t * (2 - t) + 6 * t * t
        d.rectangle((x, y, x + 1, y + 1), fill=GOLD)
    text(d, (120, 22), "Castle pools: you swim in them.")
    text(d, (120, 32), "Press jump at the surface to", fill=GOLD)
    text(d, (120, 42), "leap out onto the rim.", fill=GOLD)
    text(d, (120, 56), "Stone teeth reach into the", fill=DIM)
    text(d, (120, 66), "water: dive under them.", fill=DIM)
    d.line((8, 100, 332, 100), fill=(60, 70, 110, 255))
    # a current: streaks flowing left, the hero swimming against it
    for x in range(10, 122, 16):
        for y in (112, 128):
            water(x, y, y == 112)
    for row, y in enumerate((118, 126, 134)):
        for k in range(4):
            x = 16 + k * 26 + (12 if row % 2 else 0)
            d.line((x, y, x + 10, y), fill=(255, 255, 255, 230))
            d.line((x, y, x + 3, y - 2), fill=WHITE)       # flowing left
            d.line((x, y, x + 3, y + 2), fill=WHITE)
    img.alpha_composite(swim, (96, 116))
    text(d, (130, 108), "Currents (moving streaks) push you.")
    text(d, (130, 118), "Hold run and swim hard against them,", fill=GOLD)
    text(d, (130, 128), "or let one carry you along!", fill=GOLD)
    text(d, (8, 152), "Tip: the dragon can't swim - it waits on dry land.", fill=DIM)
    return img


def page_ghost():
    """v1.4: doors, ghosts, bone turtles, the phantom king"""
    img, d = new_page()
    text(d, (8, 6), "GHOST HOUSE", f8, GOLD)
    door = Image.open(os.path.join(GFX, "door.png")).convert("RGBA")
    closed, opened = door.crop((0, 0, 16, 32)), door.crop((16, 0, 32, 32))
    img.alpha_composite(closed, (10, 20))
    img.alpha_composite(opened, (32, 20))
    hero = trim(sheet_frame("hero_small", 20, 20, 0))
    img.alpha_composite(hero, (33, 52 - hero.height))
    arrow_key(d, 56, 36, "down")
    text(d, (76, 24), "Doors: press down in front of one")
    text(d, (76, 34), "(or up) to go through. Doors lead")
    text(d, (76, 44), "past walls - try another if you", fill=DIM)
    text(d, (76, 54), "end up where you were. Coins mark", fill=DIM)
    text(d, (76, 64), "the right one. Crypts work the same.", fill=DIM)
    d.line((8, 78, 332, 78), fill=(60, 70, 110, 255))
    gh = Image.open(os.path.join(GFX, "enemy_ghost.png")).convert("RGBA")
    chase, shy = trim(gh.crop((0, 0, 18, 18))), trim(gh.crop((36, 0, 54, 18)))
    img.alpha_composite(chase, (10, 86))
    shy2 = shy.copy()
    shy2.putalpha(shy2.getchannel("A").point(lambda v: v * 6 // 10))
    img.alpha_composite(shy2, (32, 86))
    text(d, (56, 84), "Ghosts come closer while you look away")
    text(d, (56, 94), "and freeze, shy, when you face them. Fire", fill=DIM)
    text(d, (56, 104), "can't hurt them - a star or a shell can.", fill=DIM)
    bones = Image.open(os.path.join(GFX, "enemy_bones.png")).convert("RGBA")
    walk, pile = trim(bones.crop((0, 0, 28, 26))), trim(bones.crop((56, 0, 84, 26)))
    img.alpha_composite(walk, (10, 142 - walk.height))
    img.alpha_composite(pile, (30, 142 - pile.height))
    text(d, (56, 120), "Bone turtles fall apart when stomped (or")
    text(d, (56, 130), "hit by fire) - and stand up again soon.", fill=DIM)
    text(d, (8, 152), "The phantom king fades out and appears elsewhere.", fill=GOLD)
    return img


def page_volcano():
    """v1.5: magma blobs (rock to stand on), salamanders, meteor fields,
    the final boss"""
    img, d = new_page()
    text(d, (8, 6), "VOLCANO", f8, GOLD)
    tl = Image.open(os.path.join(GFX, "tiles.png")).convert("RGBA")
    lava = tl.crop((9 * 16, 6 * 16, 10 * 16, 7 * 16))
    blob = Image.open(os.path.join(GFX, "enemy_magma.png")).convert("RGBA")
    hop, rock = trim(blob.crop((0, 0, 18, 13))), trim(blob.crop((36, 0, 54, 13)))
    img.alpha_composite(hop, (10, 44 - hop.height))
    d.polygon([(32, 34), (38, 38), (32, 42)], fill=GOLD)
    for x in (44, 60):
        img.alpha_composite(lava, (x, 40))
    img.alpha_composite(rock, (52, 44 - rock.height))
    hero = trim(sheet_frame("hero_small", 20, 20, 0))
    img.alpha_composite(hero, (54, 44 - rock.height - hero.height + 1))
    text(d, (86, 20), "Magma blobs hop at you. Stomp one: it")
    text(d, (86, 30), "cools into a rock you can stand on for", fill=DIM)
    text(d, (86, 40), "a while - it even floats on lava. Fire", fill=DIM)
    text(d, (86, 50), "can't hurt it; a star or a shell can.", fill=DIM)
    d.line((8, 64, 332, 64), fill=(60, 70, 110, 255))
    sala = Image.open(os.path.join(GFX, "enemy_salamander.png")).convert("RGBA")
    spit = trim(sala.crop((40, 0, 60, 11)))
    img.alpha_composite(spit, (22, 90 - spit.height))
    fl = Image.open(os.path.join(GFX, "boss_flame.png")).convert("RGBA").crop((0, 0, 18, 9))
    fl = trim(fl.resize((12, 6), Image.NEAREST))
    img.alpha_composite(fl, (8, 80))
    text(d, (56, 70), "Salamanders spit fire along the ground")
    text(d, (56, 80), "when you are ahead of them - jump over", fill=DIM)
    text(d, (56, 90), "it. Stomp them or use fire.", fill=DIM)
    d.line((8, 102, 332, 102), fill=(60, 70, 110, 255))
    met = trim(Image.open(os.path.join(GFX, "meteor.png")).convert("RGBA").crop((0, 0, 16, 13)))
    img.alpha_composite(met, (22, 108))
    ring = (255, 110, 40, 255)
    d.ellipse((12, 132, 30, 142), outline=ring, width=2)
    d.line((17, 137, 25, 137), fill=ring, width=2)
    text(d, (56, 110), "Meteor fields: burning rocks rain down.")
    text(d, (56, 120), "A blinking ring on the ground shows", fill=DIM)
    text(d, (56, 130), "where one will land - keep moving!", fill=DIM)
    text(d, (8, 152), "The volcano lord is the final boss. Good luck!", fill=GOLD)
    return img


def page_map():
    img, d = new_page()
    text(d, (8, 6), "WORLD MAP", f8, GOLD)
    import gen_map
    world = Image.open(os.path.join(GFX, "world_map.png")).convert("RGBA")
    nodes = Image.open(os.path.join(GFX, "map_nodes.png")).convert("RGBA")
    castles = Image.open(os.path.join(GFX, "map_castles.png")).convert("RGBA")
    nw, nh = nodes.width // 3, nodes.height
    cw, ch = castles.width // 3, castles.height
    view = world.copy()
    rds = gen_map.roads()
    for i in range(2):                       # 1-1 .. 1-3 reached
        gen_map.draw_road(view, rds[i], gen_map.road_kind(i))
    for i in range(5):
        x, y = gen_map.NODES[i]
        frame = 1 if i < 2 else (0 if i == 2 else 2)
        if i in gen_map.CASTLES:
            spr = castles.crop((frame * cw, 0, frame * cw + cw, ch))
            view.alpha_composite(spr, (x - cw // 2, y - ch + 6))
        else:
            spr = nodes.crop((frame * nw, 0, frame * nw + nw, nh))
            view.alpha_composite(spr, (x - nw // 2, y - nh + 5))
    hero = trim(sheet_frame("hero_small", 20, 20, 9))
    x, y = gen_map.NODES[2]
    view.alpha_composite(hero, (x - hero.width // 2, y - hero.height + 2))
    crop = view.crop((24, 112, 222, 232))
    img.alpha_composite(crop, (6, 20))
    d.rectangle((5, 19, 6 + crop.width, 20 + crop.height), outline=KEY_EDGE)
    tx = 216
    for i, (s, col) in enumerate((("Walk: D-pad or", WHITE), ("arrow keys", WHITE), ("A / Space:", GOLD),
                                  ("play the course", GOLD), ("", WHITE), ("Touch: tap a", WHITE),
                                  ("course to walk", WHITE), ("there, tap again", WHITE), ("to play it", WHITE),
                                  ("", WHITE), ("Saved all along:", GOLD), ("quit any time,", GOLD),
                                  ("Continue on title", GOLD))):
        text(d, (tx, 22 + i * 9), s, fill=col)
    ny = 146
    img.alpha_composite(nodes.crop((nw, 0, 2 * nw, nh)), (8, ny))
    text(d, (30, ny + 2), "cleared", fill=DIM)
    img.alpha_composite(nodes.crop((0, 0, nw, nh)), (80, ny))
    text(d, (102, ny + 2), "open", fill=DIM)
    img.alpha_composite(nodes.crop((2 * nw, 0, 3 * nw, nh)), (140, ny))
    text(d, (162, ny + 2), "locked", fill=DIM)
    text(d, (216, ny - 4), "A cleared course", fill=DIM)
    text(d, (216, ny + 5), "opens the road on.", fill=DIM)
    text(d, (216, ny + 14), "Replay any you reached.", fill=DIM)
    return img


def page_castles():
    img, d = new_page()
    text(d, (8, 6), "CASTLES & SECRETS", f8, GOLD)
    blocks = Image.open(os.path.join(GFX, "blocks.png")).convert("RGBA")
    hard = blocks.crop((7 * 16, 0, 8 * 16, 16))
    fb = trim(sheet_frame("fireball", 8, 8, 0))
    img.alpha_composite(hard, (12, 34))
    for i in range(1, 5):
        img.alpha_composite(fb, (12 + 4 + i * 7, 38 - i * 5))
    text(d, (52, 24), "Fire bars spin around their block:")
    text(d, (52, 34), "time your jump.")
    bub = trim(sheet_frame("lava_bubble", 14, 14, 0))
    img.alpha_composite(bub, (16, 62))
    text(d, (52, 62), "Lava bubbles leap out of the lava.")
    boss = trim(sheet_frame("boss_2", 32, 34, 0))
    img.alpha_composite(boss, (8, 88))
    text(d, (52, 90), "The boss waits at the end of every")
    text(d, (52, 100), "world: stomp its head 3-6 times", fill=GOLD)
    text(d, (52, 110), "(5 fireballs = 1 hit). Win = extra life!", fill=GOLD)
    text(d, (52, 120), "Boss Easy/Normal: no fire? It drops a flower.", fill=DIM)
    d.line((8, 131, 332, 131), fill=DIM)
    text(d, (8, 135), "LEVEL SELECT on the title screen:", fill=WHITE)
    text(d, (8, 146), "pad B Y X A - keys L E V E L S - tap title 5x", fill=GOLD)
    text(d, (8, 157), "\"Boss\" = straight to the arena. Practice: no high score.", fill=DIM)
    return img


def page_players():
    img, d = new_page()
    text(d, (8, 5), "TWO PLAYERS", f8, GOLD)
    red, green = (255, 106, 90, 255), (106, 226, 106, 255)
    mario = trim(sheet_frame("hero_big", 20, 32, 0))
    luigi = trim(sheet_frame("luigi_big", 20, 32, 4))
    img.alpha_composite(mario, (10, 22))
    img.alpha_composite(luigi, (36, 18))
    text(d, (6, 56), "MARIO", fill=red)
    text(d, (36, 56), "LUIGI", fill=green)
    # a hero in a bubble
    small = trim(sheet_frame("luigi_small", 20, 20, 4))
    cx, cy = 34, 92
    d.ellipse((cx - 13, cy - 13, cx + 13, cy + 13), fill=(180, 230, 255, 60), outline=(215, 240, 255, 255))
    img.alpha_composite(small, (cx - small.width // 2, cy - small.height // 2))
    d.arc((cx - 10, cy - 10, cx + 10, cy + 10), 200, 250, fill=WHITE)
    text(d, (14, 110), "bubble", fill=DIM)
    x = 72
    rows = (("TAKE TURNS", GOLD),
            ("Mario plays until he loses a life, then", WHITE),
            ("Luigi. Own lives, score and world map.", WHITE),
            ("TOGETHER (co-op)", GOLD),
            ("Both at once. Join in: each one presses", WHITE),
            ("jump on his own pad (A) - or share a", WHITE),
            ("keyboard. Shared score, own lives.", WHITE),
            ("Fall behind or lose a life: you float to", WHITE),
            ("your partner in a bubble. Stand on each", WHITE),
            ("other - you can't hurt your partner.", WHITE))
    for k, (s_, col) in enumerate(rows):
        text(d, (x, 18 + k * 10 + (4 if k >= 3 else 0)), s_, fill=col)
    d.line((8, 128, 332, 128), fill=DIM)
    text(d, (8, 133), "MARIO", fill=red)
    kx = 40
    for lab in ("A", "D", "S"):
        key(d, kx, 131, lab)
        kx += 16
    text(d, (kx + 2, 133), "move", fill=DIM)
    key(d, kx + 30, 131, "W")
    key(d, kx + 46, 131, "Space")
    text(d, (kx + 82, 133), "jump", fill=DIM)
    key(d, kx + 106, 131, "Shift")
    text(d, (kx + 140, 133), "run", fill=DIM)
    text(d, (8, 152), "LUIGI", fill=green)
    kx = 40
    for dirn in ("left", "right", "down"):
        arrow_key(d, kx, 150, dirn)
        kx += 16
    text(d, (kx + 2, 152), "move", fill=DIM)
    arrow_key(d, kx + 30, 150, "up")
    key(d, kx + 46, 150, "K")
    text(d, (kx + 82, 152), "jump", fill=DIM)
    key(d, kx + 106, 150, "L")
    text(d, (kx + 140, 152), "run", fill=DIM)
    return img


def page_wifi():
    img, d = new_page()
    text(d, (8, 5), "TWO PLAYERS - WI-FI", f8, GOLD)
    red, green = (255, 106, 90, 255), (106, 226, 106, 255)

    def device(x, y, hero, name, col, role):
        d.rounded_rectangle((x, y, x + 70, y + 44), 4, fill=(30, 36, 70, 255), outline=KEY_EDGE)
        d.rectangle((x + 6, y + 5, x + 64, y + 37), fill=(92, 148, 252, 255))
        d.rectangle((x + 6, y + 31, x + 64, y + 37), fill=(110, 70, 40, 255))
        spr = trim(sheet_frame(hero, 20, 20, 0))
        img.alpha_composite(spr, (x + 35 - spr.width // 2, y + 31 - spr.height))
        text(d, (x + 35, y + 48), name, fill=col, anchor="ma")
        text(d, (x + 35, y + 58), role, fill=DIM, anchor="ma")

    device(14, 24, "hero_small", "MARIO", red, "hosts the game")
    device(126, 24, "luigi_small", "LUIGI", green, "joins")
    # radio waves between them
    for k in range(3):
        r = 6 + k * 6
        d.arc((112 - r, 46 - r, 112 + r, 46 + r), 140, 220, fill=GOLD)
        d.arc((96 - r, 46 - r, 96 + r, 46 + r), -40, 40, fill=GOLD)
    x = 212
    rows = (("Both devices in the", WHITE), ("same Wi-Fi.", WHITE), ("", WHITE),
            ("Mario: Play >", GOLD), ("2 Players - Wi-Fi >", GOLD), ("Host a game", GOLD), ("", WHITE),
            ("Luigi: ... > Join a", GOLD), ("game, pick Mario's", GOLD), ("(or type the address", WHITE),
            ("Mario's screen shows).", WHITE))
    for k, (s_, col) in enumerate(rows):
        text(d, (x, 20 + k * 10), s_, fill=col)
    d.line((8, 132, 332, 132), fill=DIM)
    text(d, (8, 137), "Mario's device runs the game, Luigi's shows it. Same game", fill=DIM)
    text(d, (8, 147), "version on both. Pause from either side. Not in the browser.", fill=DIM)
    text(d, (8, 157), "Luigi can leave and join again any time.", fill=DIM)
    return img


def page_online():
    img, d = new_page()
    text(d, (8, 5), "TWO PLAYERS - ONLINE", f8, GOLD)
    red, green = (255, 106, 90, 255), (106, 226, 106, 255)

    def device(x, y, hero, name, col, role):
        d.rounded_rectangle((x, y, x + 64, y + 40), 4, fill=(30, 36, 70, 255), outline=KEY_EDGE)
        d.rectangle((x + 5, y + 5, x + 59, y + 33), fill=(92, 148, 252, 255))
        d.rectangle((x + 5, y + 28, x + 59, y + 33), fill=(110, 70, 40, 255))
        spr = trim(sheet_frame(hero, 20, 20, 0))
        img.alpha_composite(spr, (x + 32 - spr.width // 2, y + 28 - spr.height))
        text(d, (x + 32, y + 44), name, fill=col, anchor="ma")
        text(d, (x + 32, y + 54), role, fill=DIM, anchor="ma")

    device(8, 22, "hero_small", "MARIO", red, "gets a code")
    device(140, 22, "luigi_small", "LUIGI", green, "types it")
    # the internet between them, the room code on it
    d.ellipse((80, 26, 132, 58), fill=(40, 48, 90, 255), outline=KEY_EDGE)
    text(d, (106, 30), "internet", fill=DIM, anchor="ma")
    for k, ch in enumerate("K7QM"):
        key(d, 84 + k * 11, 40, ch, w=10)
    d.line((72, 42, 80, 42), fill=GOLD)
    d.line((132, 42, 140, 42), fill=GOLD)
    x = 216
    rows = (("Play from anywhere:", WHITE), ("", WHITE),
            ("Mario: Play >", GOLD), ("2 Players - Online >", GOLD), ("Host a game", GOLD), ("", WHITE),
            ("Luigi: ... > Join a", GOLD), ("game, type Mario's", GOLD), ("4-letter room code.", GOLD))
    for k, (s_, col) in enumerate(rows):
        text(d, (x, 20 + k * 10), s_, fill=col)
    d.line((8, 122, 332, 122), fill=DIM)
    text(d, (8, 127), "Works on PC, phone and in the browser - mixed, too.", fill=DIM)
    text(d, (8, 137), "Mario's device runs the game. Same game version on both.", fill=DIM)
    text(d, (8, 147), "A slow connection makes Luigi a little late - in the", fill=DIM)
    text(d, (8, 157), "same Wi-Fi, 2 Players - Wi-Fi is quicker.", fill=DIM)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    pages = {"controls": page_controls, "touch": page_touch, "map": page_map, "items": page_items,
             "dragon": page_dragon, "goal": page_goal, "worlds": page_worlds,
             "sky": page_sky, "sea": page_sea, "water": page_water, "ghost": page_ghost,
             "volcano": page_volcano, "castles": page_castles, "players": page_players,
             "wifi": page_wifi, "online": page_online}
    for n, fn in pages.items():
        fn().save(os.path.join(OUT, n + ".png"))
    print("  help pages:", ", ".join(pages))


if __name__ == "__main__":
    main()
