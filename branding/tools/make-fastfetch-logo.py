#!/usr/bin/env python3
"""Turns branding/build/mark.svg into fastfetch's text logo (half-block characters, colour $1).
usage: make-fastfetch-logo.py BRANDING_DIR OUTPUT.txt [ROWS]"""
import sys, subprocess, tempfile, os
import numpy as np
from PIL import Image
root, outp = sys.argv[1], sys.argv[2]
rows = int(sys.argv[3]) if len(sys.argv) > 3 else 18
with tempfile.TemporaryDirectory() as t:
    p = os.path.join(t, "m.png")
    subprocess.run(["rsvg-convert", "-h", str(rows * 2 * 4), os.path.join(root, "build/mark.svg"), "-o", p], check=True)
    a = np.array(Image.open(p).convert("RGBA"))[..., 3]
# crop to the ink, then 4x downsample with a coverage threshold
ys, xs = np.nonzero(a > 0); a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
h, w = -(-a.shape[0] // 4) * 4, -(-a.shape[1] // 4) * 4
pad = np.zeros((h, w)); pad[:a.shape[0], :a.shape[1]] = a
px = pad.reshape(h // 4, 4, w // 4, 4).mean(axis=(1, 3)) > 110
if px.shape[0] % 2: px = np.vstack([px, np.zeros((1, px.shape[1]), bool)])
lines = []
for r in range(0, px.shape[0], 2):
    s = "".join({(1, 1): "█", (1, 0): "▀", (0, 1): "▄", (0, 0): " "}[(int(t), int(b))]
                for t, b in zip(px[r], px[r + 1])).rstrip()
    lead = len(s) - len(s.lstrip())
    lines.append(" " * lead + "$1" + s.lstrip() if s.strip() else "")
open(outp, "w").write("\n".join(lines) + "\n")
print("\n".join(l.replace("$1", "") for l in lines))
