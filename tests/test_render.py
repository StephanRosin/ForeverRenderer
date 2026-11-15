"""Tests des Zeichners (render/render.py) gegen bekannte Pixelwerte."""
import os
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "render"))
import render  # noqa: E402

FONT = os.path.expanduser("~/Dokumente/wow-ui-source/art/1.60.1.70938/fonts/frizqt__.ttf")


def scene(items, w=40, h=40):
    r = render.Renderer({"screen": [w, h], "items": items}, bg=[0, 0, 0])
    assert not r.run()
    return np.asarray(r.image(), dtype=np.int32)


class Render(unittest.TestCase):
    def test_colour_rect_exact_pixels(self):
        a = scene([{"k": "tex", "rect": [10, 5, 4, 3], "color": [1, 0, 0, 1]}])
        self.assertEqual(tuple(a[5, 10]), (255, 0, 0))
        self.assertEqual(tuple(a[7, 13]), (255, 0, 0))
        self.assertEqual(tuple(a[8, 13]), (0, 0, 0))  # unter dem Rechteck
        self.assertEqual(tuple(a[5, 14]), (0, 0, 0))  # rechts daneben

    def test_order_and_alpha_blend(self):
        a = scene([{"k": "tex", "rect": [0, 0, 10, 10], "color": [1, 0, 0, 1]},
                   {"k": "tex", "rect": [0, 0, 10, 10], "color": [0, 0, 1, 0.5]}])
        self.assertEqual(tuple(a[3, 3]), (128, 0, 128))

    def test_add_and_mod(self):
        add = scene([{"k": "tex", "rect": [0, 0, 5, 5], "color": [0.5, 0, 0, 1]},
                     {"k": "tex", "rect": [0, 0, 5, 5], "color": [0.25, 0.5, 0, 1], "blend": "ADD"}])
        self.assertEqual(tuple(add[2, 2]), (191, 128, 0))
        mod = scene([{"k": "tex", "rect": [0, 0, 5, 5], "color": [1, 1, 1, 1]},
                     {"k": "tex", "rect": [0, 0, 5, 5], "color": [0.5, 0.25, 1, 1], "blend": "MOD"}])
        self.assertEqual(tuple(mod[2, 2]), (128, 64, 255))

    def test_texcoords_and_vertex_colour(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "t.png")
            img = np.zeros((2, 2, 4), dtype=np.uint8)
            img[:, 0] = (255, 0, 0, 255)  # linke Haelfte rot
            img[:, 1] = (0, 255, 0, 255)  # rechte Haelfte gruen
            Image.fromarray(img, "RGBA").save(p)
            render.load_texture.cache_clear()
            # Nur die rechte Haelfte der Textur, mit halber Vertexfarbe.
            a = scene([{"k": "tex", "rect": [0, 0, 8, 8], "file": p, "uv": [0.75, 0, 0.75, 1, 1, 0, 1, 1],
                        "vertex": [1, 0.5, 1, 1]}])
            self.assertEqual(tuple(a[4, 4]), (0, 128, 0))

    def test_clip(self):
        a = scene([{"k": "tex", "rect": [0, 0, 20, 20], "color": [1, 1, 1, 1], "clip": [5, 5, 5, 5]}])
        self.assertEqual(int(a[:, :, 0].sum() / 255), 25)

    def test_crop_offset(self):
        r = render.Renderer({"screen": [40, 40], "items": [{"k": "tex", "rect": [20, 20, 2, 2], "color": [1, 1, 1, 1]}]},
                            crop=[18, 18, 6, 6], bg=[0, 0, 0])
        r.run()
        a = np.asarray(r.image())
        self.assertEqual(a.shape[:2], (6, 6))
        self.assertEqual(int(a[2, 2, 0]), 255)
        self.assertEqual(int(a[1, 1, 0]), 0)

    @unittest.skipUnless(os.path.exists(FONT), "Schrift aus dem Grafik-Archiv fehlt")
    def test_text_outline_and_shadow(self):
        line = {"x": 2, "y": 2, "glyphs": [[ord("I"), 0, 1, 1, 1, 1]], "textures": []}
        base = {"k": "text", "font": FONT, "px": 20, "asc": 16, "desc": -4, "lineH": 20, "lines": [line]}
        plain = scene([dict(base, flags="")])
        outline = scene([dict(base, flags="OUTLINE")])
        thick = scene([dict(base, flags="THICKOUTLINE")])
        # Die Kontur ist schwarz: sichtbar nur gegen Grau, also Flaeche der Fuellung vergleichen.
        lit = lambda a: int((a.max(axis=2) > 128).sum())
        self.assertGreater(lit(plain), 10)
        self.assertEqual(lit(plain), lit(outline))
        grey = lambda flags: render.Renderer({"screen": [40, 40], "items": [dict(base, flags=flags)]}, bg=[0.5, 0.5, 0.5])
        dark = []
        for f in ("OUTLINE", "THICKOUTLINE"):
            r = grey(f)
            r.run()
            dark.append(int((np.asarray(r.image()).max(axis=2) < 40).sum()))
        self.assertGreater(dark[1], dark[0])  # THICK = 2 px statt 1 px
        shadow = scene([dict(base, flags="", shadow={"dx": 1, "dy": 1, "color": [1, 0, 0, 1]})])
        self.assertGreater(int(((shadow[:, :, 0] > 200) & (shadow[:, :, 1] < 50)).sum()), 0)


if __name__ == "__main__":
    unittest.main()
