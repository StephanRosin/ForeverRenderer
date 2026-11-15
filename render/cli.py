"""forever-render: Addon-Szenarien ohne Spiel zeichnen.

  forever-render <szenario> [-o out.png] [--scale S] [--bg checker|#rrggbb|bild.png] [--full]
  forever-render sheet <addon|all> [-o bogen.png]
  forever-render diff [<szenario> ...] [--threshold T] [--update]
  forever-render list
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)

import render  # noqa: E402

SCENARIOS = os.path.join(ROOT, "scenarios")
REFERENCES = os.path.join(ROOT, "references")
OUT = os.path.join(ROOT, "out")
CLIENT = os.path.join(ROOT, "client", "main.lua")
LUAJIT = "luajit"


def scenario_path(name):
    """Name ohne Endung relativ zu scenarios/, oder ein Pfad."""
    if os.path.exists(name):
        return os.path.realpath(name)
    p = os.path.join(SCENARIOS, name if name.endswith(".lua") else name + ".lua")
    if not os.path.exists(p):
        sys.exit("Szenario fehlt: %s" % name)
    return p


def scenario_name(path):
    rel = os.path.relpath(path, SCENARIOS)
    return rel[:-4] if rel.endswith(".lua") else rel


def run_client(path, extra_env=None):
    """Lua-Client laufen lassen; liefert die Zeichenliste samt Bericht."""
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tmp:
        out = tmp.name
    env = dict(os.environ, **(extra_env or {}))
    proc = subprocess.run([LUAJIT, CLIENT, path, out], capture_output=True, text=True, env=env)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        sys.exit("Lua-Client abgebrochen (%d) bei %s" % (proc.returncode, path))
    with open(out) as f:
        data = json.load(f)
    os.unlink(out)
    return data


def parse_bg(s):
    if s is None:
        return "checker"
    if s.startswith("#") and len(s) == 7:
        return [int(s[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return s


AUTO_PAD = 16


def auto_crop(data):
    """Huelle aller gezeichneten Elemente samt Rand."""
    x0 = y0 = float("inf")
    x1 = y1 = float("-inf")
    for it in data["items"]:
        r = it.get("rect")
        if it["k"] == "text":
            for line in it["lines"]:
                r2 = [line["x"], line["y"], 1 + max([g[1] for g in line["glyphs"]] or [0]) + it["px"], it["lineH"]]
                x0, y0 = min(x0, r2[0]), min(y0, r2[1])
                x1, y1 = max(x1, r2[0] + r2[2]), max(y1, r2[1] + r2[3])
            continue
        if it["k"] == "line":
            r = [min(it["p0"][0], it["p1"][0]), min(it["p0"][1], it["p1"][1]), abs(it["p1"][0] - it["p0"][0]), abs(it["p1"][1] - it["p0"][1])]
        if r:
            x0, y0 = min(x0, r[0]), min(y0, r[1])
            x1, y1 = max(x1, r[0] + r[2]), max(y1, r[1] + r[3])
    if x0 == float("inf"):
        return None
    sw, sh = data["screen"]
    x0, y0 = max(0, int(x0) - AUTO_PAD), max(0, int(y0) - AUTO_PAD)
    x1, y1 = min(sw, int(x1) + AUTO_PAD), min(sh, int(y1) + AUTO_PAD)
    return [x0, y0, x1 - x0, y1 - y0]


def render_data(data, full=False, scale=1.0, bg=None):
    crop = None if full else data.get("crop")
    if crop == "auto":
        crop = auto_crop(data)
    bg = parse_bg(bg) if bg else (data.get("background") or "checker")
    r = render.Renderer(data, crop=crop, bg=bg)
    problems = r.run()
    return r.image(scale), problems


def print_report(data, problems, verbose=False):
    rep = data["report"]
    errs = [e for e in rep["errors"] if e.get("phase") != "blizzard"]
    blizz = [e for e in rep["errors"] if e.get("phase") == "blizzard"]
    print("Lua-Fehler: %d (dazu %d beim Laden von Blizzards Code)" % (len(errs), len(blizz)))
    for e in errs[: (100 if verbose else 8)]:
        print("  %dx %s" % (e["count"], e["message"][:240]))
        if verbose and e.get("stack"):
            print("    " + "\n    ".join(l for l in e["stack"].splitlines()[1:6]))
    missing = rep.get("missing") or {}
    for owner in sorted(missing):
        if owner.startswith("(Blizzard") and not verbose:
            continue
        lst = missing[owner]
        print("Nicht nachgebaut (%s): %d" % (owner, len(lst)))
        for m in lst[: (200 if verbose else 6)]:
            print("  %s (%dx)" % (m["api"], m["calls"]))
    if problems:
        print("Zeichenfehler: %d" % len(problems))
        for p in problems[:8]:
            print("  " + p)
    if verbose:
        for n in rep.get("notes") or []:
            print("Hinweis: " + n)


def cmd_render(args):
    path = scenario_path(args.scenario)
    data = run_client(path)
    im, problems = render_data(data, full=args.full, scale=args.scale, bg=args.bg)
    out = args.output or os.path.join(OUT, scenario_name(path) + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)
    print(out, "%dx%d" % im.size)
    print_report(data, problems, args.verbose)
    if args.json:
        with open(args.json, "w") as f:
            json.dump(data, f)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "sheet":
        import sheet
        return sheet.main(sys.argv[2:])
    if len(sys.argv) > 1 and sys.argv[1] == "diff":
        import diff
        return diff.main(sys.argv[2:])
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        for base, _, files in sorted(os.walk(SCENARIOS)):
            for f in sorted(files):
                if f.endswith(".lua") and not f.startswith("_"):
                    print(scenario_name(os.path.join(base, f)))
        return
    ap = argparse.ArgumentParser(prog="forever-render", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scenario")
    ap.add_argument("-o", "--output")
    ap.add_argument("--scale", type=float, default=1.0)
    ap.add_argument("--bg", help="checker, #rrggbb oder Bilddatei (Bildschirmgroesse)")
    ap.add_argument("--full", action="store_true", help="ganzer Bildschirm statt Ausschnitt")
    ap.add_argument("--json", help="Zeichenliste samt Bericht zusaetzlich speichern")
    ap.add_argument("-v", "--verbose", action="store_true")
    cmd_render(ap.parse_args())


if __name__ == "__main__":
    sys.exit(main())
