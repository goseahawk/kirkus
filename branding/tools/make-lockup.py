#!/usr/bin/env python3
"""Build the kirkus lockup (mark + "kirkus" wordmark) and its screen-size layers.

usage: make-lockup.py FONT.ttf BRANDING_DIR [--weight W] [--track EM] [--height PX] [--max-width PX]
                      [--out DIR]

Takes the mark (the K and its dot) from branding/build/mark-src.png and dot-src.png, sets "kirkus"
in the given font and writes, to BRANDING_DIR/build (or --out):
  lockup.png, lockup-nodot.png                      full size, 308px tall
  screen-lockup.png, screen-lockup-nodot.png,       132px tall, what every screen draws
  screen-dot.png                                    (dot layer is the same size as the lockup)

--weight   for variable fonts (default 680)
--track    letter spacing in em, negative is tighter (default -0.04)
--height   height of the word's ink, ascender to baseline (default 148, as the original "kirk")
--max-width  the word is scaled down to fit this width if needed (default 640)
"""
import sys, os, argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("font"); ap.add_argument("root")
ap.add_argument("--weight", type=float, default=680)
ap.add_argument("--track", type=float, default=-0.04)
ap.add_argument("--height", type=int, default=148)
ap.add_argument("--max-width", type=int, default=640)
ap.add_argument("--out")
a = ap.parse_args()
font_path, root = a.font, a.root
b = os.path.join(root, "build")
out = a.out or b
os.makedirs(out, exist_ok=True)
CREAM = (0xff, 0xf8, 0xec)
H, SCREEN_H = 308, 132                     # 308 * 3/7 = 132
GAP_X = 376                                # where the wordmark starts (as in the original)

mark = Image.open(os.path.join(b, "mark-src.png")).convert("RGBA")       # 330 x 308, no dot
dot = Image.open(os.path.join(b, "dot-src.png")).convert("RGBA")
dx, dy = (int(v) for v in open(os.path.join(b, "dot-offset.txt")).read().split())

S = 4                                      # 4x supersampling

def ink(size):
    """'kirkus' set at size (supersampled px); returns the cropped coverage array."""
    f = ImageFont.truetype(font_path, int(size))
    try:
        axes = f.get_variation_axes()
        f.set_variation_by_axes([min(max(a.weight, ax["minimum"]), ax["maximum"]) if i == 0
                                 else ax["default"] for i, ax in enumerate(axes)])
    except (OSError, AttributeError):
        pass                               # not a variable font
    cov = Image.new("L", (int(size * 9), int(size * 2)))
    d = ImageDraw.Draw(cov)
    x = size * 0.2
    for ch in "kirkus":
        d.text((x, size * 0.3), ch, font=f, fill=255)
        x += f.getlength(ch) + a.track * size
    c = np.array(cov)
    ys, xs = np.nonzero(c > 0)
    return c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]

# pick the size that gives the requested ink height, within the maximum width
probe = ink(200 * S)
scale = min(a.height * S / probe.shape[0], a.max_width * S / probe.shape[1])
c = ink(200 * S * scale)
tw, th = (c.shape[1] + S - 1) // S, (c.shape[0] + S - 1) // S
pad = np.zeros((th * S, tw * S), np.uint8)
pad[:c.shape[0], :c.shape[1]] = c
word = pad.reshape(th, S, tw, S).mean(axis=(1, 3)).round().astype(np.uint8)

# centre the word's ink on the mark's ink, vertically
ma = np.array(mark)[..., 3]
mys = np.nonzero(ma.max(axis=1) > 20)[0]
top = int(round((mys.min() + mys.max()) / 2 - th / 2))

# full width chosen so the 132px-tall version comes out an even number of pixels wide
need = GAP_X + tw + 4
sw = -(-need * 3 // 7)
sw += sw % 2
while (sw * 7) % 3:
    sw += 2
W = sw * 7 // 3

def canvas(with_dot, with_word=True, with_mark=True):
    im = Image.new("RGBA", (W, H))
    if with_mark:
        im.alpha_composite(mark, (0, 0))
    if with_dot:
        im.alpha_composite(dot, (dx, dy))
    if with_word:
        layer = Image.new("RGBA", (tw, th), CREAM + (0,))
        layer.putalpha(Image.fromarray(word))
        im.alpha_composite(layer, (GAP_X, top))
    return im

def shrink(im):
    # resize premultiplied so edges don't pick up dark fringes
    a = np.array(im).astype(np.float64)
    a[..., :3] *= a[..., 3:4] / 255
    p = Image.fromarray(a.round().astype(np.uint8), "RGBA").resize((sw, SCREEN_H), Image.LANCZOS)
    q = np.array(p).astype(np.float64)
    al = q[..., 3:4]
    q[..., :3] = np.where(al > 0, np.clip(q[..., :3] * 255 / np.maximum(al, 1), 0, 255), 0)
    return Image.fromarray(q.round().astype(np.uint8), "RGBA")

full, nodot = canvas(True), canvas(False)
dotonly = canvas(True, with_word=False, with_mark=False)
full.save(os.path.join(out, "lockup.png"))
nodot.save(os.path.join(out, "lockup-nodot.png"))
shrink(full).save(os.path.join(out, "screen-lockup.png"))
shrink(nodot).save(os.path.join(out, "screen-lockup-nodot.png"))
shrink(dotonly).save(os.path.join(out, "screen-dot.png"))
print(f"lockup {W}x{H}, screen {sw}x{SCREEN_H}, word {tw}x{th} at ({GAP_X},{top})")
