"""Vergleicht ein Element zwischen Spiel-Screenshot und Rendering.

  measure.py <screenshot.png> <rendering.png> x y w h [--color r,g,b] [--tol 60]

Sucht im Ausschnitt die Pixel nahe der Farbe (Standard: Pitwall-Rot) und
gibt deren Begrenzungsrechteck in beiden Bildern samt Abweichung aus, dazu
die mittlere Farbe der Treffer.
"""
import argparse

import numpy as np
from PIL import Image


def bbox(path, rect, color, tol):
    x, y, w, h = rect
    arr = np.asarray(Image.open(path).convert("RGB").crop((x, y, x + w, y + h)), dtype=np.int32)
    hit = (np.abs(arr - np.array(color)).sum(axis=2) <= tol)
    if not hit.any():
        return None
    ys, xs = np.nonzero(hit)
    mean = arr[hit].mean(axis=0)
    return (x + xs.min(), y + ys.min(), xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, tuple(int(round(c)) for c in mean), int(hit.sum()))


def load(path, rect):
    x, y, w, h = rect
    return np.asarray(Image.open(path).convert("RGB").crop((x, y, x + w, y + h)), dtype=np.float32)


def align(game, ours, rect, search):
    """Versatz (dx, dy) des Renderings, bei dem der Ausschnitt am besten passt."""
    x, y, w, h = rect
    g = load(game, rect)
    best = None
    full = np.asarray(Image.open(ours).convert("RGB"), dtype=np.float32)
    for dy in range(-search, search + 1):
        for dx in range(-search, search + 1):
            if y + dy < 0 or x + dx < 0 or y + dy + h > full.shape[0] or x + dx + w > full.shape[1]:
                continue
            o = full[y + dy:y + dy + h, x + dx:x + dx + w]
            err = np.abs(o - g).mean()
            if best is None or err < best[0]:
                best = (err, dx, dy)
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game")
    ap.add_argument("ours")
    ap.add_argument("rect", nargs=4, type=int)
    ap.add_argument("--color", default="230,0,0")
    ap.add_argument("--tol", type=int, default=90)
    ap.add_argument("--align", type=int, default=0, help="Versatz bis +-N px suchen")
    a = ap.parse_args()
    if a.align:
        err, dx, dy = align(a.game, a.ours, a.rect, a.align)
        print("Bester Versatz des Renderings: dx %+d dy %+d (mittlere Abweichung %.1f/255)" % (dx, dy, err))
    color = [int(c) for c in a.color.split(",")]
    g = bbox(a.game, a.rect, color, a.tol)
    o = bbox(a.ours, a.rect, color, a.tol)
    print("Spiel     ", g)
    print("Rendering ", o)
    if g and o:
        print("Abweichung x %+d  y %+d  w %+d  h %+d  Farbe %s" % (o[0] - g[0], o[1] - g[1], o[2] - g[2], o[3] - g[3],
              tuple(oc - gc for oc, gc in zip(o[4], g[4]))))


if __name__ == "__main__":
    main()
