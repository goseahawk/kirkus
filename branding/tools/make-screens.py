#!/usr/bin/env python3
"""Builds every screen image of kirkus from the logo files in branding/build.

usage: make-screens.py [PROJECT_DIR]        (default: the project this script is in)

Needs rsvg-convert (librsvg), Pillow and numpy. Writes straight into overlay/:
  sddm/themes/kirkus/mark.png, plasma splash images/mark.png   the bird for dark screens
  plymouth/themes/kirkus/wordmark.png, live/wordmark.png       the word "kirkus" for dark screens
  grub/themes/kirkus/background.png                            Ink, with the bird
  plasma splash preview.png                                    the splash's preview in System Settings
  wallpapers/kirkus/                                           the wallpaper ("Quiet"), dark and light
  backgrounds/kirkus.svg                                       the same wallpaper, where older accounts look
  icons/.../kirkus-logo.svg                                    the app icon
  icons/.../kirkus-mark.svg                                    the bird alone (launcher button)
  icons/kirkus/, icons/kirkus-light/                           the icon themes: Breeze, bird as start icon

The Global Themes' previews and the login screen's preview are real screenshots, not drawn here;
DEVELOPMENT.md says how to retake them.

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
                    fill=FIELD, outline=MARIGOLD, width=S)      # focused, as the real screen starts
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

# ---- the bird's parts, as Qt-safe SVG (self-closing elements: Qt's SVG reader rejects anything
#      it thinks is nested wrongly, and then shows nothing) ----
def element(colour):
    m = re.search(r'<(path|circle)\b([^>]*?fill="%s"[^>]*?)\s*/?>(?:\s*</\1>)?' % colour, mark_dark)
    return f"<{m.group(1)}{re.sub(r' fill=\"[^\"]*\"', '', m.group(2))}"
BODY, HEAD, EYE = element("#f3efe6"), element("#f2a93b"), element("#16171b")
vb = [float(v) for v in re.search(r'viewBox="([^"]*)"', mark_dark).group(1).split()]
probe = render(mark_dark, 2000)
_k = vb[3] / 2000
_x0, _y0, _x1, _y1 = ink_box(probe)
INK_X, INK_Y = vb[0] + _x0 * _k, vb[1] + _y0 * _k          # the bird's ink box, in its own units
INK_W, INK_H = (_x1 - _x0) * _k, (_y1 - _y0) * _k

def bird(cx, top, height, body, head, eye, body_extra=""):
    """the bird, ink box `height` tall, centred on x = cx, its top at y = top"""
    k = height / INK_H
    return (f'<g transform="translate({cx - (INK_X + INK_W / 2) * k:.2f} {top - INK_Y * k:.2f}) '
            f'scale({k:.5f})">{BODY}{body_extra} fill="{body}"/>{HEAD} fill="{head}"/>'
            f'{EYE} fill="{eye}"/></g>')

# ---- wallpaper "Quiet": flat colour, and a large bird one shade off it, lower right ----
WALL = (2880, 1800)
def quiet(bg, tone):
    W, H = WALL
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="{bg}"/>'
            + bird(0.70 * W, 0.15 * H, 1.0 * H, tone, tone, bg) + "</svg>\n")
QUIET_DARK = quiet("#16171b", "#222327")        # Ink, and Bone at about 5% over it
QUIET_LIGHT = quiet("#f3efe6", "#e4e0d8")       # Bone, and Ink at about 7% over it

def write(text, *path):
    p = os.path.join(*path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(text)
    print("wrote", os.path.relpath(p, ROOT))

# A wallpaper package, like KDE's own: the Global Themes name it ("Image=kirkus"), so it's there
# from the first frame of a new account and on the lock screen. Plasma shows images_dark/ with a dark
# colour scheme and images/ with a light one.
WP = os.path.join(INST, "usr/share/wallpapers/kirkus")
write('{\n    "KPlugin": {\n        "Authors": [ { "Name": "kirkus" } ],\n        "Id": "kirkus",\n'
      '        "Name": "kirkus"\n    }\n}\n', WP, "metadata.json")
write(QUIET_DARK, WP, "contents/images_dark/2880x1800.svg")
write(QUIET_LIGHT, WP, "contents/images/2880x1800.svg")
save(render(QUIET_DARK, 250).convert("RGB"), WP, "contents/screenshot.png")
# the same picture at the path older accounts already point at
write(QUIET_DARK, INST, "usr/share/backgrounds/kirkus.svg")

# ---- the bird on its own, square, for the Application Launcher button. Its body takes the
#      theme's text colour (KDE recolours "ColorScheme-Text"), so it's Bone on a dark panel and Ink
#      on a light one; the head stays Marigold. ----
side = max(INK_W, INK_H) * 1.06
icon = (f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" '
        f'viewBox="{INK_X + INK_W / 2 - side / 2:.2f} {INK_Y + INK_H / 2 - side / 2:.2f} {side:.2f} {side:.2f}">'
        '<defs><style type="text/css" id="current-color-scheme">.ColorScheme-Text { color:#f3efe6; }</style></defs>'
        f'{BODY} class="ColorScheme-Text" style="fill:currentColor"/>{HEAD} fill="#f2a93b"/>{EYE} fill="#16171b"/>'
        '</svg>\n')
write(icon, INST, "usr/share/icons/hicolor/scalable/apps/kirkus-mark.svg")

# ---- icon themes "kirkus" (Breeze Dark underneath) and "kirkus Light" (Breeze underneath). They
#      replace KDE's own logo, a "K" that looks like the old kirkus mark, with the bird wherever KDE
#      uses it as the start icon: the Application Launcher's default icon, its menu entries and the
#      like. Everything else comes from Breeze. ----
START_ICONS = ("start-here", "start-here-symbolic", "start-here-kde", "start-here-kde-symbolic",
               "start-here-kde-plasma", "start-here-kde-plasma-symbolic")
for theme, name, base in (("kirkus", "kirkus", "breeze-dark"), ("kirkus-light", "kirkus Light", "breeze")):
    write("[Icon Theme]\n"
          f"Name={name}\n"
          f"Comment=Breeze icons with the kirkus bird as the start icon\n"
          f"Inherits={base},hicolor\n"
          "Example=start-here-kde\n"
          "DisplayDepth=32\n"
          # like Breeze: icons take the colour scheme's colours (Marigold folders, the bird's body)
          "FollowsColorScheme=true\n"
          "KDE-Extensions=.svg\n"
          "DesktopDefault=48\nDesktopSizes=16,22,32,48,64,128,256\n"
          "ToolbarDefault=22\nToolbarSizes=16,22,32,48\n"
          "MainToolbarDefault=22\nMainToolbarSizes=16,22,32,48\n"
          "SmallDefault=16\nSmallSizes=16,22,32,48\n"
          "PanelDefault=48\nPanelSizes=16,22,32,48,64,128,256\n"
          "DialogDefault=32\nDialogSizes=16,22,32,48,64,128,256\n"
          "Directories=places/scalable\n\n"
          "[places/scalable]\nSize=48\nMinSize=8\nMaxSize=512\nType=Scalable\nContext=Places\n",
          INST, f"usr/share/icons/{theme}/index.theme")
    for n in START_ICONS:
        write(icon, INST, f"usr/share/icons/{theme}/places/scalable/{n}.svg")

# ---- app icon ----
p = os.path.join(INST, "usr/share/icons/hicolor/scalable/apps/kirkus-logo.svg")
open(p, "w").write(open(os.path.join(BUILD, "icon.svg")).read())
print("wrote", os.path.relpath(p, ROOT))
