"""Nicht nachgebaute APIs je Addon ueber alle Szenarien (ohne compare/).

  .venv/bin/python -I tools/missing.py
"""
import json
import os
import subprocess
import tempfile
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
SKIP = {"compare", "smoke"}


def main():
    calls = defaultdict(lambda: defaultdict(int))
    errors = defaultdict(set)
    for base, _, files in sorted(os.walk(os.path.join(ROOT, "scenarios"))):
        if os.path.relpath(base, os.path.join(ROOT, "scenarios")).split(os.sep)[0] in SKIP:
            continue
        for f in sorted(files):
            if not f.endswith(".lua") or f.startswith("_"):
                continue
            with tempfile.NamedTemporaryFile(suffix=".json") as tmp:
                subprocess.run(["luajit", os.path.join(ROOT, "client/main.lua"), os.path.join(base, f), tmp.name],
                               capture_output=True, check=True)
                rep = json.load(open(tmp.name))["report"]
            for owner, lst in rep["missing"].items():
                for m in lst:
                    calls[owner][m["api"]] += m["calls"]
            for e in rep["errors"]:
                if e.get("phase") != "blizzard":
                    errors[e.get("owner") or "?"].add(e["message"][:160])
    for owner in sorted(calls):
        print("## %s" % owner)
        for api, n in sorted(calls[owner].items()):
            print("- %s (%d)" % (api, n))
    print("## Fehler ausserhalb von Blizzards Ladevorgang")
    for owner in sorted(errors):
        for msg in sorted(errors[owner]):
            print("- %s: %s" % (owner, msg))


if __name__ == "__main__":
    main()
