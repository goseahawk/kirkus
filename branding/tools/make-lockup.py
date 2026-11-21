#!/usr/bin/env python3
"""Build the kirkus lockup (mark + "kirkus" wordmark) and its screen-size layers.

usage: make-lockup.py FONT.ttf BRANDING_DIR [--weight W] [--track EM] [--height PX] [--max-width PX]
                      [--gap PX] [--out DIR]

Renders the mark from BRANDING_DIR/build/mark.svg (with rsvg-convert): its "base" group (the stem)
and its "accent" group (the chevron) as separate layers, sets "kirkus" in the given font, and
writes to BRANDING_DIR/build (or --out):
  lockup.png, lockup-base.png                          full size, 308px tall
  screen-lockup.png, screen-lockup-base.png,           132px tall, what every screen draws
  screen-accent.png                                    (the accent layer is the same size as the
                                                       lockup, so it lines up when drawn on top)
  screen-mark.png                                      the K on its own (GRUB, login, Plasma splash)
  screen-wordmark.png                                  "kirkus" on its own (boot splash, live USB)
Every screen draws its image centred at x = W/2, y = H/2 - 50, and these have even sizes, so the
K on the login screen and on the Plasma splash land on exactly the same pixels.

--weight     for variable fonts (default 680)
--track      letter spacing in em, negative is tighter (default -0.04)
--height     height of the word's ink, ascender to baseline (default 148)
--max-width  the word is scaled down to fit this width if needed (default 640)
--gap        space between the mark and the word (default 110)
"""
import argparse, os, re, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("font"); ap.add_argument("root")
ap.add_argument("--weight", type=float, default=680)
ap.add_argument("--track", type=float, default=-0.04)
ap.add_argument("--height", type=int, default=148)
ap.add_argument("--max-width", type=int, default=640)
ap.add_argument("--gap", type=int, default=110)
ap.add_argument("--out")
a = ap.parse_args()
b = os.path.join(a.root, "build")
out = a.out or b
os.makedirs(out, exist_ok=True)
CREAM = (0xff, 0xf8, 0xec)
H, SCREEN_H = 308, 132                     # 308 * 3/7 = 132

# ---- the mark's two layers, each rendered on its own at full size ----
svg = open(os.path.join(b, "mark.svg")).read()
def layer(keep, height=None):
    hide = {"base": ["accent"], "accent": ["base"], "both": []}[keep]
    body = svg
    for g in hide:
        body = re.sub(r'(<g id="%s")' % g, r'\1 display="none"', body)
    with tempfile.TemporaryDirectory() as t:
        p = os.path.join(t, "m.svg"); open(p, "w").write(body)
        subprocess.run(["rsvg-convert", "-h", str(height or H), p, "-o", p + ".png"], check=True)
        return Image.open(p + ".png").convert("RGBA")
base, accent = layer("base"), layer("accent")
mark = base.copy(); mark.alpha_composite(accent)
# trim the empty space left of the mark (keep 4px), so the lockup is centred on what you see
x0 = max(int(np.nonzero(np.array(mark)[..., 3].max(axis=0) > 0)[0].min()) - 4, 0)
base, accent, mark = (im.crop((x0, 0, im.width, H)) for im in (base, accent, mark))
GAP_X = int(np.nonzero(np.array(mark)[..., 3].max(axis=0) > 20)[0].max()) + 1 + a.gap

# ---- wordmark coverage, 4x supersampled ----
S = 4
def ink(size):
    f = ImageFont.truetype(a.font, int(size))
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

probe = ink(200 * S)
scale = min(a.height * S / probe.shape[0], a.max_width * S / probe.shape[1])
c = ink(200 * S * scale)
tw, th = (c.shape[1] + S - 1) // S, (c.shape[0] + S - 1) // S
pad = np.zeros((th * S, tw * S), np.uint8)
pad[:c.shape[0], :c.shape[1]] = c
word = pad.reshape(th, S, tw, S).mean(axis=(1, 3)).round().astype(np.uint8)

# centre the word's ink on the mark's ink, vertically
mys = np.nonzero(np.array(mark)[..., 3].max(axis=1) > 20)[0]
top = int(round((mys.min() + mys.max()) / 2 - th / 2))

# full width chosen so the 132px-tall version comes out an even number of pixels wide
need = GAP_X + tw + 4
sw = -(-need * 3 // 7)
sw += sw % 2
while (sw * 7) % 3:
    sw += 2
W = sw * 7 // 3

def canvas(with_base=True, with_accent=True, with_word=True):
    im = Image.new("RGBA", (W, H))
    if with_base:
        im.alpha_composite(base, (0, 0))
    if with_accent:
        im.alpha_composite(accent, (0, 0))
    if with_word:
        l = Image.new("RGBA", (tw, th), CREAM + (0,))
        l.putalpha(Image.fromarray(word))
        im.alpha_composite(l, (GAP_X, top))
    return im

def shrink(im):
    # resize premultiplied so edges don't pick up dark fringes
    p = np.array(im).astype(np.float64)
    p[..., :3] *= p[..., 3:4] / 255
    r = Image.fromarray(p.round().astype(np.uint8), "RGBA").resize((sw, SCREEN_H), Image.LANCZOS)
    q = np.array(r).astype(np.float64)
    al = q[..., 3:4]
    q[..., :3] = np.where(al > 0, np.clip(q[..., :3] * 255 / np.maximum(al, 1), 0, 255), 0)
    return Image.fromarray(q.round().astype(np.uint8), "RGBA")

full, still = canvas(), canvas(with_accent=False)
full.save(os.path.join(out, "lockup.png"))
still.save(os.path.join(out, "lockup-base.png"))
shrink(full).save(os.path.join(out, "screen-lockup.png"))
shrink(still).save(os.path.join(out, "screen-lockup-base.png"))
shrink(canvas(with_base=False, with_word=False)).save(os.path.join(out, "screen-accent.png"))
print(f"lockup {W}x{H}, screen {sw}x{SCREEN_H}, word {tw}x{th} at ({GAP_X},{top})")

# ---- the K and the word on their own, at screen size ----
def tidy(im, margin=4):
    """crop to the ink plus a margin, then pad to even width and height"""
    al = np.array(im)[..., 3]
    ys, xs = np.nonzero(al > 0)
    im = im.crop((xs.min() - margin, ys.min() - margin, xs.max() + 1 + margin, ys.max() + 1 + margin))
    w, h = im.width + im.width % 2, im.height + im.height % 2
    out_im = Image.new("RGBA", (w, h)); out_im.alpha_composite(im, (0, 0)); return out_im

MARK_INK = 120                              # the K's height on screen, px
svg_ink = 256 / 300                         # the K's ink is 256 of mark.svg's 300 units
k = tidy(layer("both", round(MARK_INK / svg_ink)))
k.save(os.path.join(out, "screen-mark.png"))

WORD_INK = 64                               # the word's height on screen, ascender to baseline
probe = ink(200 * S)
c = ink(200 * S * WORD_INK * S / probe.shape[0])
ww, wh = (c.shape[1] + S - 1) // S, (c.shape[0] + S - 1) // S
pad = np.zeros((wh * S, ww * S), np.uint8); pad[:c.shape[0], :c.shape[1]] = c
cov = pad.reshape(wh, S, ww, S).mean(axis=(1, 3)).round().astype(np.uint8)
wl = Image.new("RGBA", (ww + 8, wh + 8), CREAM + (0,))
al = Image.new("L", (ww + 8, wh + 8)); al.paste(Image.fromarray(cov), (4, 4)); wl.putalpha(al)
tidy(wl).save(os.path.join(out, "screen-wordmark.png"))
print(f"mark {k.width}x{k.height}, wordmark {tidy(wl).width}x{tidy(wl).height}")
