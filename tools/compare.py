"""Pflichtvergleich: Elemente aus Stephans Screenshots gegen das Rendering.

  .venv/bin/python -I tools/compare.py [--out <ordner>]

Je Situation werden zwei Ecken des Elements (oben links, unten rechts) einzeln
ausgerichtet. Der Versatz der oberen linken Ecke ist der Lagefehler, die
Differenz der beiden Versaetze der Groessenfehler. Dazu die mittlere Farbe des
Elements in beiden Bildern. Die Screenshots sind 3433 px breit (rechts
beschnitten); gerendert wird 3440 px, x = 0 liegt in beiden gleich.
"""
import argparse
import os
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SCREENS = os.path.expanduser("~/Downloads/screens")
CORNER = (90, 36)
SEARCH = 24

# (Name, Szenario, Screenshot, Element x y w h im Screenshot)
SITUATIONS = [
    ("Player-Frame unter Pitwall", "compare/pitwall", "Pitwall.png", (1025, 985, 340, 30)),
    ("Quest Log unter Frost", "compare/frost", "frost.png", (3012, 462, 421, 150)),
    ("Combat Meter unter Runestone", "compare/runestone", "Runestone.png", (3012, 1074, 421, 110)),
    ("InfoPanel-Medaillon unter Pitwall", "compare/pitwall", "Pitwall.png", (3012, 1262, 421, 170)),
    ("Data Bar unter Comic", "compare/comic", "comic.png", (0, 0, 160, 36)),
]


def arr(im, box):
    x, y, w, h = box
    return np.asarray(im.crop((x, y, x + w, y + h)), dtype=np.float32)


def best_offset(game, ours, box):
    g = arr(game, box)
    best = None
    for dy in range(-SEARCH, SEARCH + 1):
        for dx in range(-SEARCH, SEARCH + 1):
            x, y = box[0] + dx, box[1] + dy
            if x < 0 or y < 0 or x + box[2] > ours.width or y + box[3] > ours.height:
                continue
            err = np.abs(arr(ours, (x, y, box[2], box[3])) - g).mean()
            if best is None or err < best[0]:
                best = (err, dx, dy)
    return best


def measure(game, ours, box):
    x, y, w, h = box
    cw, ch = min(CORNER[0], w), min(CORNER[1], h)
    tl = best_offset(game, ours, (x, y, cw, ch))
    br = best_offset(game, ours, (x + w - cw, y + h - ch, cw, ch))
    dx, dy = tl[1], tl[2]
    gm = arr(game, box).reshape(-1, 3).mean(axis=0)
    om = arr(ours, (x + dx, y + dy, w, h)).reshape(-1, 3).mean(axis=0)
    return {"dx": dx, "dy": dy, "dw": br[1] - tl[1], "dh": br[2] - tl[2], "err_tl": tl[0], "err_br": br[0],
            "color_game": gm.round().astype(int).tolist(), "color_ours": om.round().astype(int).tolist()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "out", "compare"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    rendered = {}
    print("| Situation | Lage dx/dy | Groesse dw/dh | Farbe Spiel | Farbe Rendering | Restfehler TL/BR |")
    print("|---|---|---|---|---|---|")
    for name, scn, shot, box in SITUATIONS:
        if scn not in rendered:
            out = os.path.join(a.out, scn.replace("/", "_") + ".png")
            subprocess.run([os.path.join(ROOT, "forever-render"), scn, "-o", out], check=True, capture_output=True)
            rendered[scn] = out
        game = Image.open(os.path.join(SCREENS, shot)).convert("RGB")
        ours = Image.open(rendered[scn]).convert("RGB")
        m = measure(game, ours, box)
        print("| %s | %+d / %+d px | %+d / %+d px | %s | %s | %.1f / %.1f |" % (
            name, m["dx"], m["dy"], m["dw"], m["dh"], tuple(m["color_game"]), tuple(m["color_ours"]), m["err_tl"], m["err_br"]))
        x, y, w, h = box
        pair = Image.new("RGB", (w, 2 * h + 4), (255, 0, 255))
        pair.paste(game.crop((x, y, x + w, y + h)), (0, 0))
        pair.paste(ours.crop((x + m["dx"], y + m["dy"], x + m["dx"] + w, y + m["dy"] + h)), (0, h + 4))
        pair.save(os.path.join(a.out, name.replace(" ", "_") + ".png"))


if __name__ == "__main__":
    sys.exit(main())
