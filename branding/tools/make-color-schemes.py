#!/usr/bin/env python3
"""Writes the kirkus desktop colour schemes, and makes the dark one the default.

usage: make-color-schemes.py [PROJECT_DIR]        (default: the project this script is in)

  overlay/installed/usr/share/color-schemes/KirkusDark.colors    Ink, Bone and Marigold (default)
  overlay/installed/usr/share/color-schemes/KirkusLight.colors   Bone, Ink and Marigold
  overlay/installed/etc/xdg/kdeglobals                           the dark scheme as everyone's default

Selected items are Marigold with Ink text, as everywhere else in kirkus.
"""
import os, re, sys

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                       os.path.join(os.path.dirname(__file__), "..", ".."))
INST = os.path.join(ROOT, "overlay", "installed")

INK, BONE, MARIGOLD = (22, 23, 27), (243, 239, 230), (242, 169, 59)


def group(bg, bg_alt, fg, fg_dim, active, link, visited, neg, neutral, pos, focus=MARIGOLD):
    return {"BackgroundNormal": bg, "BackgroundAlternate": bg_alt, "ForegroundNormal": fg,
            "ForegroundInactive": fg_dim, "ForegroundActive": active, "ForegroundLink": link,
            "ForegroundVisited": visited, "ForegroundNegative": neg, "ForegroundNeutral": neutral,
            "ForegroundPositive": pos, "DecorationFocus": focus, "DecorationHover": focus}


def scheme(dark):
    if dark:
        fg, dim = BONE, (162, 158, 149)
        accent_text, link, visited = MARIGOLD, (245, 186, 96), (214, 150, 110)
        neg, neutral, pos = (240, 112, 102), MARIGOLD, (120, 190, 130)
        view, view_alt = INK, (28, 29, 34)
        window, window_alt = (31, 32, 37), (36, 37, 42)
        button, button_alt = (41, 42, 48), (46, 47, 53)
        comp_fg, comp_dim, comp = BONE, (162, 158, 149), (16, 17, 20)
        wm_active, wm_inactive, wm_fg_inactive = (31, 32, 37), (26, 27, 32), (120, 117, 110)
        icons = "breeze-dark"
    else:
        fg, dim = INK, (95, 91, 82)
        accent_text, link, visited = (140, 86, 10), (140, 86, 10), (130, 80, 50)
        neg, neutral, pos = (176, 48, 38), (140, 86, 10), (40, 110, 45)
        view, view_alt = (250, 248, 243), BONE
        window, window_alt = BONE, (236, 231, 220)
        button, button_alt = (236, 231, 220), (229, 223, 211)
        comp_fg, comp_dim, comp = BONE, (162, 158, 149), INK
        wm_active, wm_inactive, wm_fg_inactive = (236, 231, 220), BONE, (120, 117, 110)
        icons = "breeze"
    common = dict(fg=fg, fg_dim=dim, active=accent_text, link=link, visited=visited,
                  neg=neg, neutral=neutral, pos=pos)
    groups = {
        "Colors:View": group(view, view_alt, **common),
        "Colors:Window": group(window, window_alt, **common),
        "Colors:Header": group(window, window_alt, **common),
        "Colors:Header][Inactive": group(window, window_alt, **common),
        "Colors:Button": group(button, button_alt, **common),
        "Colors:Tooltip": group(window, window_alt, **common),
        "Colors:Complementary": group(comp, (28, 29, 34), comp_fg, comp_dim, MARIGOLD,
                                      (245, 186, 96), (214, 150, 110), (232, 98, 90),
                                      MARIGOLD, (120, 190, 130)),
        "Colors:Selection": group(MARIGOLD, (214, 146, 45), INK, (60, 55, 45), INK, INK,
                                  (60, 40, 20), (120, 20, 10), INK, (20, 70, 30)),
        "WM": {"activeBackground": wm_active, "activeBlend": wm_active, "activeForeground": fg,
               "inactiveBackground": wm_inactive, "inactiveBlend": wm_inactive,
               "inactiveForeground": wm_fg_inactive},
    }
    effects = ("[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\n"
               "ContrastAmount=0.65\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n"
               "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\n"
               "ColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\n"
               "Enable=false\nIntensityAmount=0\nIntensityEffect=0\n\n")
    body = ""
    for name, keys in groups.items():
        body += f"[{name}]\n" + "".join(f"{k}={','.join(map(str, v))}\n" for k, v in sorted(keys.items())) + "\n"
    return effects + body, icons


for dark, file, name in ((True, "KirkusDark", "kirkus Dark"), (False, "KirkusLight", "kirkus Light")):
    colours, _ = scheme(dark)
    p = os.path.join(INST, "usr/share/color-schemes", file + ".colors")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(colours + f"[General]\nColorScheme={file}\nName={name}\nshadeSortColumn=true\n\n"
                       "[KDE]\ncontrast=4\n")
    print("wrote", os.path.relpath(p, ROOT))

# ---- the default for every account: /etc/xdg/kdeglobals, keeping its other sections ----
p = os.path.join(INST, "etc/xdg/kdeglobals")
old = open(p).read() if os.path.exists(p) else ""
start = "# ---- kirkus colours: written by branding/tools/make-color-schemes.py ----\n"
end = "# ---- end of kirkus colours ----\n"
old = re.sub(re.escape(start) + r".*?" + re.escape(end), "", old, flags=re.S).rstrip("\n")
colours, icons = scheme(True)
block = (start + "[General]\nColorScheme=KirkusDark\n\n[Icons]\nTheme=" + icons + "\n\n" + colours
         + "[KDE]\ncontrast=4\n" + end)
open(p, "w").write((old + "\n\n" if old else "") + block)
print("wrote", os.path.relpath(p, ROOT))
