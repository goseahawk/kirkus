#!/usr/bin/env python3
"""Build the kirkus lockup (mark + "kirkus" wordmark) and its screen-size layers.

usage: make-lockup.py SPACE_GROTESK_VARIABLE_TTF BRANDING_DIR

Takes the mark (the K and its dot) from branding/build/mark-src.png and dot-src.png, sets
"kirkus" in Space Grotesk (wght 680, 208px, -8px tracking: the settings that reproduce the
original "kirk" artwork), and writes:
  build/lockup.png, build/lockup-nodot.png            full size, 308px tall
  build/screen-lockup.png, screen-lockup-nodot.png,   132px tall, what every screen draws
  build/screen-dot.png                                (dot layer is the same size as the lockup)
"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

font_path, root = sys.argv[1], sys.argv[2]
b = os.path.join(root, "build")
CREAM = (0xff, 0xf8, 0xec)
H, SCREEN_H = 308, 132                     # 308 * 3/7 = 132
GAP_X = 376                                # where the wordmark starts (as in the original)

mark = Image.open(os.path.join(b, "mark-src.png")).convert("RGBA")       # 330 x 308, no dot
dot = Image.open(os.path.join(b, "dot-src.png")).convert("RGBA")
dx, dy = (int(v) for v in open(os.path.join(b, "dot-offset.txt")).read().split())

# ---- wordmark coverage, 4x supersampled ----
S = 4
f = ImageFont.truetype(font_path, 208 * S)
f.set_variation_by_axes([680])
cov = Image.new("L", (1400 * S, 400 * S))
d = ImageDraw.Draw(cov)
x = 20 * S
for ch in "kirkus":
    d.text((x, 20 * S), ch, font=f, fill=255)
    x += f.getlength(ch) - 8 * S
c = np.array(cov)
ys, xs = np.nonzero(c > 0)
c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
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
full.save(os.path.join(b, "lockup.png"))
nodot.save(os.path.join(b, "lockup-nodot.png"))
shrink(full).save(os.path.join(b, "screen-lockup.png"))
shrink(nodot).save(os.path.join(b, "screen-lockup-nodot.png"))
shrink(dotonly).save(os.path.join(b, "screen-dot.png"))
print(f"lockup {W}x{H}, screen {sw}x{SCREEN_H}, word {tw}x{th} at ({GAP_X},{top})")
