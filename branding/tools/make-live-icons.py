#!/usr/bin/env python3
"""Draws the live USB launcher's two icons: make-live-icons.py OUTPUT_DIR"""
import sys, os
from PIL import Image, ImageDraw
out = sys.argv[1]
S, N = 4, 112                                  # 4x supersampling, 112px icons
CREAM, BLUE = (0xf3, 0xef, 0xe6, 255), (0xf2, 0xa9, 0x3b, 255)   # Bone, Marigold

def canvas():
    im = Image.new("RGBA", (N * S, N * S)); return im, ImageDraw.Draw(im)

def save(im, name):
    im.resize((N, N), Image.LANCZOS).save(os.path.join(out, name))

# Wi-Fi: three arcs and a dot
im, d = canvas(); cx, cy = N * S / 2, N * S * 0.76; w = int(8.5 * S)
for r, col in ((52, CREAM), (36, CREAM), (20, CREAM)):
    r *= S
    d.arc([cx - r, cy - r, cx + r, cy + r], 222, 318, fill=col, width=w)
r = 6.5 * S; d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BLUE)
save(im, "wifi.png")

# Install: an arrow down into a tray
im, d = canvas(); u = S
d.rounded_rectangle([18 * u, 64 * u, 94 * u, 92 * u], radius=9 * u, outline=CREAM, width=int(8.5 * S))
d.rectangle([40 * u, 56 * u, 72 * u, 72 * u], fill=(0, 0, 0, 0))               # gap in the tray's lid
d.line([56 * u, 14 * u, 56 * u, 60 * u], fill=BLUE, width=int(9 * S))
d.polygon([(38 * u, 46 * u), (74 * u, 46 * u), (56 * u, 68 * u)], fill=BLUE)
save(im, "install.png")
