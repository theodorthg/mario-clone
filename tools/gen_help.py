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
    text(d, (x + 4, y + 3), "jump (hold = higher)")
    y += 17
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
    text(d, (264, 64), "A B: jump")
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
    text(d, (240, 86), "A: jump", fill=GOLD)
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
    text(d, (230, 114), "WORLD 1  meadows", fill=DIM)
    text(d, (230, 124), "WORLD 2  caverns", fill=DIM)
    text(d, (230, 134), "WORLD 3  desert", fill=DIM)
    text(d, (230, 144), "WORLD 4  snow", fill=DIM)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    pages = {"controls": page_controls, "touch": page_touch, "items": page_items,
             "dragon": page_dragon, "goal": page_goal, "worlds": page_worlds}
    for n, fn in pages.items():
        fn().save(os.path.join(OUT, n + ".png"))
    print("  help pages:", ", ".join(pages))


if __name__ == "__main__":
    main()
