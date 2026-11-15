# forever-render

Zeichnet die eigenen WoW-Forever-Addons ausserhalb des Spiels als PNG. Ausführliche Doku, Abgleich
mit dem Spiel und Grenzen: Vault `10-Projekte/WoW/forever-render.md`.

```sh
python3 -m venv --system-site-packages .venv && .venv/bin/pip install freetype-py   # einmalig
python3 -I tools/extract-art          # Grafik-Archiv nach ~/Dokumente/wow-ui-source/art/<build>/
./forever-render list
./forever-render ForeverUnitFrames/full
./forever-render sheet ForeverDataBar --themes PITWALL,FROST
./forever-render diff --update        # Referenzen anlegen, danach ohne --update vergleichen
tests/run
```

Blizzards Grafik, Schriften und Tabellen liegen nur im Archiv ausserhalb des Repos und kommen nie hinein.
