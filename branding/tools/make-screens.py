#!/usr/bin/env python3
"""Builds every screen image of kirkus from the logo files in branding/build.

usage: make-screens.py [PROJECT_DIR]        (default: the project this script is in)

Needs rsvg-convert (librsvg), Pillow and numpy. Writes straight into overlay/:
  sddm/themes/kirkus/mark.png, plasma splash images/mark.png   the bird for dark screens
  plymouth/themes/kirkus/wordmark.png, live/wordmark.png       the word "kirkus" for dark screens
  grub/themes/kirkus/background.png                            Ink, with the bird
  sddm preview.png, plasma splash preview.png                  previews shown in System Settings
  look-and-feel previews/preview.png, fullscreenpreview.jpg    the Global Theme's previews
  backgrounds/kirkus.svg                                       the wallpaper
  icons/.../kirkus-logo.svg                                    the app icon
  icons/.../kirkus-mark.svg                                    the bird alone (launcher button)

Every screen centres its image at x = W/2, y = H/2 - 50, and the images have even sizes, so the
bird on the login screen and on the Plasma splash land on exactly the same pixels.
"""
import os, re, subprocess, sys, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                       os.path.join(os.path.dirname(__file__), "..", ".."))
BUILD = os.path.join(ROOT, "branding", "build")
INST = os.path.join(ROOT, "overlay", "installed")
LIVE = os.path.join(ROOT, "overlay", "airootfs", "usr", "share", "kirkus", "live")
FONTS = os.path.join(INST, "usr", "share", "fonts", "kirkus")

INK, BONE, MARIGOLD = (0x16, 0x17, 0x1b), (0xf3, 0xef, 0xe6), (0xf2, 0xa9, 0x3b)
DIM, FIELD, FIELD_LINE, HINT = (0x8f, 0x8b, 0x83), (0x1f, 0x20, 0x25), (0x2e, 0x2f, 0x35), (0x77, 0x73, 0x6b)
SCREEN = (1440, 900)
MARK_INK = 140          # the bird's height on screen, px
WORD_INK = 64           # the word's height on screen, top of the k to the baseline, px


def render(svg_text, height):
    """SVG text -> RGBA image, height px tall."""
    with tempfile.TemporaryDirectory() as t:
        p = os.path.join(t, "in.svg")
        open(p, "w").write(svg_text)
        subprocess.run(["rsvg-convert", "-h", str(height), p, "-o", p + ".png"], check=True)
        return Image.open(p + ".png").convert("RGBA")


def ink_box(im, threshold=0):
    al = np.array(im)[..., 3]
    ys, xs = np.nonzero(al > threshold)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def tidy(im, margin=4):
    """crop to the ink plus a margin, then pad to even width and height"""
    x0, y0, x1, y1 = ink_box(im)
    im = im.crop((x0 - margin, y0 - margin, x1 + margin, y1 + margin))
    out = Image.new("RGBA", (im.width + im.width % 2, im.height + im.height % 2))
    out.alpha_composite(im, (0, 0))
    return out


def at_ink_height(svg_text, target):
    """render so the ink comes out `target` px tall"""
    probe = render(svg_text, 2000)
    x0, y0, x1, y1 = ink_box(probe)
    return tidy(render(svg_text, round(2000 * target / (y1 - y0))))


def centred(canvas, im, opacity=1.0):
    W, H = canvas.size
    x, y = W // 2 - im.width // 2, H // 2 - im.height // 2 - 50
    if opacity < 1:
        im = im.copy()
        im.putalpha(Image.fromarray((np.array(im)[..., 3] * opacity).round().astype(np.uint8)))
    canvas.alpha_composite(im, (x, y))
    return x, y


def save(im, *path):
    p = os.path.join(*path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p)
    print("wrote", os.path.relpath(p, ROOT), f"{im.width}x{im.height}")


# ---- the bird, for dark screens ----
mark_dark = open(os.path.join(BUILD, "mark-dark.svg")).read()
mark = at_ink_height(mark_dark, MARK_INK)
save(mark, INST, "usr/share/sddm/themes/kirkus/mark.png")
save(mark, INST, "usr/share/plasma/look-and-feel/org.kirkus.splash/contents/splash/images/mark.png")

# ---- the word, for dark screens: the lockup's second group on its own ----
logo_dark = open(os.path.join(BUILD, "logo-dark.svg")).read()
groups = re.findall(r"<g [^>]*>.*?</g>", logo_dark, re.S)
word_svg = logo_dark.replace(groups[0], "")
word = at_ink_height(word_svg, WORD_INK)
save(word, INST, "usr/share/plymouth/themes/kirkus/wordmark.png")
save(word, LIVE, "wordmark.png")

# ---- GRUB background: Ink and the bird ----
bg = Image.new("RGBA", SCREEN, INK + (255,))
centred(bg, mark)
save(bg.convert("RGB"), INST, "boot/grub/themes/kirkus/background.png")

# ---- Plasma splash preview: the bird at full strength ----
save(bg.convert("RGB"), INST, "usr/share/plasma/look-and-feel/org.kirkus.splash/contents/previews/splash.png")

# ---- login screen preview: the faded bird, password field, clock and bottom bar ----
def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, f"DMSans-{name}.ttf"), size)

S = 2                                              # draw at 2x, then shrink, for smooth edges
pv = Image.new("RGBA", SCREEN, INK + (255,))
mx, my = centred(pv, mark, 0.3)
big = Image.new("RGBA", (SCREEN[0] * S, SCREEN[1] * S))
d = ImageDraw.Draw(big)
def text(xy, s, size, fill, anchor="la", weight="Regular"):
    d.text((xy[0] * S, xy[1] * S), s, font=font(weight, size * S), fill=fill, anchor=anchor)
text((SCREEN[0] / 2, 44), "Tuesday, November 25     9:41 AM", 15, DIM, "ma")
fx, fy = SCREEN[0] / 2 - 140, my + mark.height + 84
d.rounded_rectangle([fx * S, fy * S, (fx + 280) * S, (fy + 42) * S], radius=21 * S,
                    fill=FIELD, outline=FIELD_LINE, width=S)
text((fx + 18, fy + 21), "Password for kirkus", 15, HINT, "lm")
gx, gy = fx + 280 - 5 - 32, fy + 5
go = Image.new("RGBA", big.size)
ImageDraw.Draw(go).ellipse([gx * S, gy * S, (gx + 32) * S, (gy + 32) * S], fill=MARIGOLD + (89,))
big.alpha_composite(go)
text((gx + 16, gy + 16), "→", 17, INK + (89,), "mm")
text((28, SCREEN[1] - 22), "Plasma (Wayland)", 13, DIM, "ls")
x = SCREEN[0] - 28
for label in ("Shut Down", "Restart", "Sleep"):
    text((x, SCREEN[1] - 22), label, 13, DIM, "rs")
    x -= font("Regular", 13).getlength(label) + 24
pv.alpha_composite(big.resize(SCREEN, Image.LANCZOS))
save(pv.convert("RGB"), INST, "usr/share/sddm/themes/kirkus/preview.png")

# ---- wallpaper: Ink, a soft glow, and a large faint bird lower right ----
paths = re.search(r"<svg[^>]*>(.*)</svg>", mark_dark, re.S).group(1)
vb = [float(v) for v in re.search(r'viewBox="([^"]*)"', mark_dark).group(1).split()]
scale = 1100 / vb[3]
wall = f'''<svg xmlns="http://www.w3.org/2000/svg" width="2880" height="1800" viewBox="0 0 2880 1800">
  <defs>
    <radialGradient id="glow" cx="0.70" cy="0.60" r="0.80">
      <stop offset="0" stop-color="#22232a"/>
      <stop offset="0.55" stop-color="#16171b"/>
      <stop offset="1" stop-color="#0e0f12"/>
    </radialGradient>
  </defs>
  <rect width="2880" height="1800" fill="url(#glow)"/>
  <g opacity="0.12" transform="translate({1980 - (vb[0] + vb[2] / 2) * scale:.2f} {440 - vb[1] * scale:.2f}) scale({scale:.5f})">{paths}</g>
</svg>
'''
p = os.path.join(INST, "usr/share/backgrounds/kirkus.svg")
open(p, "w").write(wall)
print("wrote", os.path.relpath(p, ROOT))

# ---- the bird on its own, square, for the Application Launcher button (bone body, for dark panels) ----
x, y, w, h = vb
side = max(w, h)
square = re.sub(r'width="[^"]*" height="[^"]*" viewBox="[^"]*"',
                f'width="512" height="512" viewBox="{x - (side - w) / 2:.2f} {y - (side - h) / 2:.2f} {side:.2f} {side:.2f}"',
                mark_dark, count=1)
p = os.path.join(INST, "usr/share/icons/hicolor/scalable/apps/kirkus-mark.svg")
open(p, "w").write(square)
print("wrote", os.path.relpath(p, ROOT))

# ---- Global Theme previews: the wallpaper with a kirkus Dark panel and the launcher bird ----
def lnf_preview(W, H):
    wp = render(open(os.path.join(INST, "usr/share/backgrounds/kirkus.svg")).read(), H)
    wp = wp.resize((W, H), Image.LANCZOS) if wp.size != (W, H) else wp
    ph = round(H * 0.045)
    d = ImageDraw.Draw(wp)
    d.rectangle([0, H - ph, W, H], fill=(31, 32, 37, 255))
    bird = render(square, round(ph * 0.8))
    wp.alpha_composite(bird, (round(ph * 0.4), H - ph + round(ph * 0.1)))
    buttons = Image.new("RGBA", (W, H))
    bd = ImageDraw.Draw(buttons)
    for i in range(3):                          # a few app buttons, faint
        x = round(ph * 2.0 + i * ph * 1.1)
        bd.rounded_rectangle([x, H - ph + round(ph * .2), x + round(ph * .6), H - round(ph * .2)],
                             radius=round(ph * .12), fill=BONE + (70 if i else 140,))
    wp.alpha_composite(buttons)
    f = ImageFont.truetype(os.path.join(FONTS, "DMSans-Regular.ttf"), round(ph * 0.36))
    d.text((W - round(ph * .5), H - ph / 2), "9:41 AM", font=f, fill=BONE, anchor="rm")
    return wp.convert("RGB")
LNF = os.path.join(INST, "usr/share/plasma/look-and-feel/org.kirkus.splash/contents/previews")
save(lnf_preview(640, 360), LNF, "preview.png")
save(lnf_preview(1920, 1080), LNF, "fullscreenpreview.jpg")

# ---- app icon ----
p = os.path.join(INST, "usr/share/icons/hicolor/scalable/apps/kirkus-logo.svg")
open(p, "w").write(open(os.path.join(BUILD, "icon.svg")).read())
print("wrote", os.path.relpath(p, ROOT))
