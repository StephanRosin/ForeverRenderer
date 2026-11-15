"""forever-render sheet <addon|all> [-o bogen.png] [--themes A,B] [--scenario NAME] [--tile 520] [--jobs N]

Beschrifteter Bilderbogen: jedes Szenario des Addons (scenarios/<addon>/*.lua)
einmal, das Szenario "classic" zusaetzlich in jedem Theme mal jeder Farbe,
die das Addon selbst meldet (_G.ForeverThemes[addon].Colors).
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

from PIL import Image, ImageDraw, ImageFont

import cli

LABEL_H = 22
GAP = 8
SHEET_BG = (24, 24, 28)
LABEL_FONT = "/usr/share/fonts/TTF/DejaVuSans.ttf"
LUAJIT = "luajit"


def addons_with_scenarios():
    return sorted(d for d in os.listdir(cli.SCENARIOS)
                  if os.path.isdir(os.path.join(cli.SCENARIOS, d)) and d not in ("compare", "smoke", "all"))


def run(path, theme=None, color=None):
    env = {}
    if theme:
        env["FOREVER_THEME"] = theme
    if color:
        env["FOREVER_COLOR"] = color
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        out = tmp.name
    proc = subprocess.run([LUAJIT, cli.CLIENT, path, out], capture_output=True, text=True, env=dict(os.environ, **env))
    if proc.returncode != 0:
        return None, (proc.stdout + proc.stderr)[-400:]
    with open(out) as f:
        data = json.load(f)
    os.unlink(out)
    return data, None


def tile(data, label, size):
    if data.get("crop") is None:
        data["crop"] = "auto"
    im, problems = cli.render_data(data)
    im.thumbnail((size, size * 2))
    errors = [e for e in data["report"]["errors"] if e.get("phase") != "blizzard"]
    return im, label, len(errors) + len(problems)


def main(argv):
    ap = argparse.ArgumentParser(prog="forever-render sheet")
    ap.add_argument("addon")
    ap.add_argument("-o", "--output")
    ap.add_argument("--themes", help="nur diese Themes, z. B. PITWALL,FROST")
    ap.add_argument("--scenario", default="classic", help="Szenario fuer die Theme-Reihen")
    ap.add_argument("--tile", type=int, default=520)
    ap.add_argument("--jobs", type=int, default=4)
    a = ap.parse_args(argv)
    addons = addons_with_scenarios() if a.addon == "all" else [a.addon]
    wanted = set(a.themes.split(",")) if a.themes else None

    jobs = []  # (addon, label, path, theme, color)
    for addon in addons:
        folder = os.path.join(cli.SCENARIOS, addon)
        if not os.path.isdir(folder):
            sys.exit("keine Szenarien fuer %s" % addon)
        for f in sorted(os.listdir(folder)):
            if f.endswith(".lua") and not f.startswith("_"):
                jobs.append((addon, f[:-4], os.path.join(folder, f), None, None))
        base = os.path.join(folder, a.scenario + ".lua")
        if not os.path.exists(base):
            continue
        data, err = run(base)
        info = data and (data.get("themes") or {}).get(addon)
        if not info:
            print("%s: meldet keine Themes%s" % (addon, (" (" + err + ")") if err else ""))
            continue
        for theme, colors in sorted(info["colors"].items()):
            if theme == "CLASSIC" or (wanted and theme not in wanted):
                continue
            for color in (colors or [None]):
                jobs.append((addon, "%s %s" % (theme, color or ""), base, theme, color))

    def work(job):
        addon, label, path, theme, color = job
        data, err = run(path, theme, color)
        if data is None:
            return addon, Image.new("RGB", (a.tile, 60), (90, 20, 20)), label + " (Abbruch)", 1
        im, lab, nerr = tile(data, label, a.tile)
        return addon, im, lab, nerr

    with ThreadPoolExecutor(a.jobs) as pool:
        tiles = list(pool.map(work, jobs))

    font = ImageFont.truetype(LABEL_FONT, 14)
    cols = max(1, min(4, len(tiles)))
    rows = []
    for i in range(0, len(tiles), cols):
        rows.append(tiles[i:i + cols])
    width = cols * (a.tile + GAP) + GAP
    height = GAP + sum(max(t[1].height for t in r) + LABEL_H + GAP for r in rows)
    sheet = Image.new("RGB", (width, height), SHEET_BG)
    draw = ImageDraw.Draw(sheet)
    y = GAP
    for r in rows:
        x = GAP
        for addon, im, label, nerr in r:
            text = "%s · %s" % (addon, label) + ("  [%d Fehler]" % nerr if nerr else "")
            draw.text((x, y + 3), text, fill=(255, 120, 120) if nerr else (220, 220, 220), font=font)
            sheet.paste(im, (x, y + LABEL_H))
            x += a.tile + GAP
        y += max(t[1].height for t in r) + LABEL_H + GAP
    out = a.output or os.path.join(cli.OUT, "sheet-%s.png" % a.addon)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(out, "%dx%d" % sheet.size, "%d Bilder" % len(tiles))
