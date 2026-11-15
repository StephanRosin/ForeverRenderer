"""forever-render diff [<szenario> ...] [--threshold T] [--update]

Vergleicht Szenarien mit eigenen Referenz-Renderings in references/<szenario>.png
(nie Screenshots aus dem Spiel, nie Blizzard-Grafik). Abweichung = Anteil der
Pixel, deren Farbe um mehr als 8/255 abweicht. Ueber der Schwelle: Exit 1 und
ein Differenzbild in out/diff/. --update schreibt die Referenzen neu.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image

import cli

PIXEL_TOLERANCE = 8
DEFAULT_THRESHOLD = 0.002


def compare(ref, cur):
    if ref.size != cur.size:
        return 1.0, None
    a = np.asarray(ref, dtype=np.int16)
    b = np.asarray(cur, dtype=np.int16)
    bad = np.abs(a - b).max(axis=2) > PIXEL_TOLERANCE
    vis = (np.asarray(cur, dtype=np.float32) * 0.35).astype(np.uint8)
    vis[bad] = (255, 0, 255)
    return float(bad.mean()), Image.fromarray(vis)


def main(argv):
    ap = argparse.ArgumentParser(prog="forever-render diff")
    ap.add_argument("scenarios", nargs="*")
    ap.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD)
    ap.add_argument("--update", action="store_true")
    a = ap.parse_args(argv)
    names = a.scenarios
    if not names:
        names = []
        for base, _, files in os.walk(cli.REFERENCES):
            for f in files:
                if f.endswith(".png"):
                    names.append(os.path.relpath(os.path.join(base, f), cli.REFERENCES)[:-4])
        names.sort()
    if not names:
        sys.exit("keine Referenzen in references/ (erst mit --update anlegen)")
    failed = 0
    for name in names:
        path = cli.scenario_path(name)
        if "/compare/" in path:
            print("%s: Vergleichsszenarien lesen Kontodaten und bekommen keine Referenz" % name)
            continue
        data = cli.run_client(path)
        im, _ = cli.render_data(data)
        ref_path = os.path.join(cli.REFERENCES, name + ".png")
        if a.update or not os.path.exists(ref_path):
            os.makedirs(os.path.dirname(ref_path), exist_ok=True)
            im.save(ref_path)
            print("%s: Referenz geschrieben" % name)
            continue
        share, vis = compare(Image.open(ref_path).convert("RGB"), im)
        ok = share <= a.threshold
        print("%s: %.3f %% abweichend %s" % (name, share * 100, "ok" if ok else "UEBER SCHWELLE"))
        if not ok:
            failed += 1
            if vis:
                out = os.path.join(cli.OUT, "diff", name + ".png")
                os.makedirs(os.path.dirname(out), exist_ok=True)
                vis.save(out)
                print("  Differenzbild:", out)
    return 1 if failed else 0
