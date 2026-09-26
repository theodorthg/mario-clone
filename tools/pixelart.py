#!/usr/bin/env python3
"""Tiny pixel-art toolkit shared by the asset generators in tools/.

Every sprite is authored as a list of equal-length strings ("pixel maps"),
one character per pixel, looked up in a palette dict (char -> "#rrggbb").
'.' and ' ' are always transparent.

Consistency guarantees this gives us (the reason PixelLab output was
replaced, see CLAUDE.md "Grafik"):
  * one shared palette per character family -> colors never drift
  * every frame of a set uses the SAME grid size and the feet sit on the
    SAME bottom row -> no size jumps, feet always land on the tile top
  * transparent background by construction
  * outline added programmatically (outline()) -> identical line weight
"""
from PIL import Image
import colorsys

TRANSPARENT = (0, 0, 0, 0)


def hex_rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def parse(rows, palette, name="?"):
    w = len(rows[0])
    for i, r in enumerate(rows):
        if len(r) != w:
            raise ValueError("%s: row %d has width %d, expected %d: %r" % (name, i, len(r), w, r))
    img = Image.new("RGBA", (w, len(rows)), TRANSPARENT)
    px = img.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in ". ":
                continue
            if ch not in palette:
                raise ValueError("%s: unknown palette char %r at (%d,%d)" % (name, ch, x, y))
            px[x, y] = hex_rgba(palette[ch]) if isinstance(palette[ch], str) else palette[ch]
    return img


def darken(rgba, v_mul=0.32, s_mul=1.1):
    r, g, b, a = rgba
    h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    s = min(1.0, s * s_mul)
    v = v * v_mul
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), 255)


def outline(img, color=None, diagonal=False, selective=True):
    """Return a copy grown by 1px on every side with an outline around the
    opaque silhouette. selective=True colors each outline pixel with a very
    dark version of the neighboring fill (SNES-style colored line art);
    otherwise `color` (default near-black) is used everywhere."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), TRANSPARENT)
    out.paste(img, (1, 1))
    src = out.load()
    res = out.copy()
    dst = res.load()
    base = hex_rgba(color) if isinstance(color, str) else (color or (26, 16, 24, 255))
    n4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    n8 = n4 + [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3] != 0:
                continue
            nb = None
            for dx, dy in (n8 if diagonal else n4):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w + 2 and 0 <= yy < h + 2 and src[xx, yy][3] != 0:
                    nb = src[xx, yy]
                    break
            if nb is not None:
                dst[x, y] = darken(nb) if selective else base
    return res


def recolor(img, mapping):
    """mapping: {"#rrggbb": "#rrggbb"} exact-color swap (palette swaps such as
    fire-hero or the green 1-UP mushroom)."""
    m = {hex_rgba(k)[:3]: hex_rgba(v)[:3] for k, v in mapping.items()}
    out = img.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and (r, g, b) in m:
                px[x, y] = m[(r, g, b)] + (a,)
    return out


def recolor_outline_aware(img_fill, mapping, **outline_kw):
    """Palette-swap the FILL, then re-outline, so selective outline colors
    follow the swap too."""
    return outline(recolor(img_fill, mapping), **outline_kw)


def flip_h(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def strip(frames, frame_w=None, frame_h=None, align="bottom"):
    """Pack frames horizontally into one sheet, each cell frame_w x frame_h,
    frames bottom-aligned and horizontally centered in their cell."""
    fw = frame_w or max(f.size[0] for f in frames)
    fh = frame_h or max(f.size[1] for f in frames)
    sheet = Image.new("RGBA", (fw * len(frames), fh), TRANSPARENT)
    for i, f in enumerate(frames):
        x = i * fw + (fw - f.size[0]) // 2
        y = fh - f.size[1] if align == "bottom" else (fh - f.size[1]) // 2
        sheet.paste(f, (x, y), f)
    return sheet, fw, fh


def grid(frames, cols, frame_w, frame_h):
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", (frame_w * cols, frame_h * rows), TRANSPARENT)
    for i, f in enumerate(frames):
        sheet.paste(f, ((i % cols) * frame_w, (i // cols) * frame_h), f)
    return sheet


def preview(img, scale=8, bg=(92, 148, 252, 255), path=None, checker=False):
    """Upscaled preview on a flat background (sky blue by default) for visual
    review — NOT shipped with the game."""
    w, h = img.size
    base = Image.new("RGBA", (w, h), bg)
    if checker:
        p = base.load()
        for y in range(h):
            for x in range(w):
                if (x // 8 + y // 8) % 2:
                    p[x, y] = (bg[0] - 20, bg[1] - 20, bg[2] - 20, 255)
    base.alpha_composite(img)
    big = base.resize((w * scale, h * scale), Image.NEAREST)
    if path:
        big.save(path)
    return big
