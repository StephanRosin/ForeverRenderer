"""Zeichnet die Zeichenliste des Lua-Clients als Bild.

Gerechnet wird in float32 (RGB, deckender Hintergrund). Texturen werden
bilinear gefiltert wie im Client, Texturkoordinaten pro Ecke (UL, LL, UR, LR)
bilinear ueber das Rechteck verteilt. Text: dieselbe FreeType-Bibliothek wie
die Messung im Client, Kontur ueber den FreeType-Stroker (1 px, THICK 2 px),
Schatten als versetzte Kopie.
"""
import math
from functools import lru_cache

import freetype
import numpy as np
from PIL import Image, ImageDraw

# Kontur wie der Client: Glyph-Umriss in Pixeln.
OUTLINE_PX = 1
THICK_OUTLINE_PX = 2
FIXED_26_6 = 64
CHECKER_CELL = 16
CHECKER_COLORS = ((0.30, 0.30, 0.30), (0.22, 0.22, 0.22))
MODEL_GREY = (0.35, 0.35, 0.38, 0.9)
LUMA = np.array([0.299, 0.587, 0.114], dtype=np.float32)
FALLBACK_FONT = "/usr/share/fonts/TTF/DejaVuSans.ttf"


@lru_cache(maxsize=512)
def load_texture(path):
    """Textur als float32 RGBA (gerade, nicht vormultipliziert)."""
    im = Image.open(path).convert("RGBA")
    return np.asarray(im, dtype=np.float32) / 255.0


def background(kind, w, h, offset=(0, 0)):
    if isinstance(kind, (list, tuple)):
        return np.tile(np.array(kind[:3], dtype=np.float32), (h, w, 1))
    if isinstance(kind, str) and kind not in ("checker", ""):
        im = Image.open(kind).convert("RGB")
        arr = np.asarray(im, dtype=np.float32) / 255.0
        ox, oy = offset
        out = np.zeros((h, w, 3), dtype=np.float32)
        sub = arr[max(oy, 0):oy + h, max(ox, 0):ox + w]
        out[:sub.shape[0], :sub.shape[1]] = sub
        return out
    ys, xs = np.mgrid[0:h, 0:w]
    cell = ((xs + offset[0]) // CHECKER_CELL + (ys + offset[1]) // CHECKER_CELL) % 2
    a, b = (np.array(c, dtype=np.float32) for c in CHECKER_COLORS)
    return np.where(cell[..., None] == 0, a, b).astype(np.float32)


def sample(tex, u, v, wrap_u, wrap_v):
    """Bilinear wie GL_LINEAR; wrap: Wiederholen statt Klemmen."""
    th, tw = tex.shape[:2]
    x = u * tw - 0.5
    y = v * th - 0.5
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = (x - x0)[..., None]
    fy = (y - y0)[..., None]

    def idx(i, n, wrap):
        return np.mod(i, n) if wrap else np.clip(i, 0, n - 1)

    xa, xb = idx(x0, tw, wrap_u), idx(x0 + 1, tw, wrap_u)
    ya, yb = idx(y0, th, wrap_v), idx(y0 + 1, th, wrap_v)
    top = tex[ya, xa] * (1 - fx) + tex[ya, xb] * fx
    bot = tex[yb, xa] * (1 - fx) + tex[yb, xb] * fx
    return top * (1 - fy) + bot * fy


def blend(canvas, region, x0, y0, rgb, alpha, mode):
    """Mischt Farbe+Alpha in den Ausschnitt [y0:, x0:] des Bildes."""
    h, w = alpha.shape
    dst = canvas[y0:y0 + h, x0:x0 + w]
    a = alpha[..., None]
    if mode == "ADD":
        dst += rgb * a
        np.clip(dst, 0, 1, out=dst)
    elif mode == "MOD":
        dst *= 1 - a + rgb * a
    elif mode == "DISABLE":
        dst[:] = rgb
    else:
        dst *= 1 - a
        dst += rgb * a


class Renderer:
    def __init__(self, data, crop=None, bg="checker"):
        self.data = data
        sw, sh = data["screen"]
        self.crop = crop or [0, 0, sw, sh]
        cx, cy, cw, ch = (int(round(c)) for c in self.crop)
        self.ox, self.oy, self.w, self.h = cx, cy, cw, ch
        self.canvas = background(bg, cw, ch, (cx, cy))
        self.faces = {}
        self.glyphs = {}

    # Hilfen -----------------------------------------------------------------

    def window(self, x, y, w, h, clip):
        """Sichtbarer Teil eines Rechtecks (Bildkoordinaten) oder None."""
        x0, y0, x1, y1 = x - self.ox, y - self.oy, x + w - self.ox, y + h - self.oy
        if clip:
            cx0, cy0 = clip[0] - self.ox, clip[1] - self.oy
            x0, y0 = max(x0, cx0), max(y0, cy0)
            x1, y1 = min(x1, cx0 + clip[2]), min(y1, cy0 + clip[3])
        x0, y0 = max(int(math.floor(x0)), 0), max(int(math.floor(y0)), 0)
        x1, y1 = min(int(math.ceil(x1)), self.w), min(int(math.ceil(y1)), self.h)
        if x1 <= x0 or y1 <= y0:
            return None
        return x0, y0, x1, y1

    # Texturen ----------------------------------------------------------------

    def draw_texture(self, it):
        x, y, w, h = it["rect"]
        if w <= 0 or h <= 0:
            return
        win = self.window(x, y, w, h, it.get("clip"))
        if not win:
            return
        x0, y0, x1, y1 = win
        # Pixelzentren relativ zum Rechteck (0..1).
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        s = (xs + self.ox + 0.5 - x) / w
        t = (ys + self.oy + 0.5 - y) / h
        rot = it.get("rotation")
        if rot:
            c = it.get("rotCenter") or [0.5, 0.5]
            # Drehung des Inhalts um den Mittelpunkt (in Pixeln, damit nicht verzerrt).
            px, py = (s - c[0]) * w, (t - c[1]) * h
            cr, sr = math.cos(rot), math.sin(rot)
            s = (px * cr - py * sr) / w + c[0]
            t = (px * sr + py * cr) / h + c[1]
        color = it.get("color")
        if color is not None:
            rgba = np.empty(s.shape + (4,), dtype=np.float32)
            rgba[:] = color[:4] if len(color) >= 4 else list(color) + [1]
            outside = (s < 0) | (s > 1) | (t < 0) | (t > 1)
            if rot:
                rgba[outside, 3] = 0
        else:
            tex = load_texture(it["file"])
            uv = it.get("uv") or [0, 0, 0, 1, 1, 0, 1, 1]
            ulx, uly, llx, lly, urx, ury, lrx, lry = uv
            if it.get("tileH") or it.get("tileV"):
                th, tw = tex.shape[:2]
                scale = it.get("tileScale") or 1
                su = w / (tw * scale) if it.get("tileH") else 1
                sv = h / (th * scale) if it.get("tileV") else 1
                u = ulx + (urx - ulx) * s * su
                v = uly + (lly - uly) * t * sv
            else:
                u = (ulx * (1 - s) * (1 - t) + urx * s * (1 - t) + llx * (1 - s) * t + lrx * s * t)
                v = (uly * (1 - s) * (1 - t) + ury * s * (1 - t) + lly * (1 - s) * t + lry * s * t)
            rgba = sample(tex, u, v, bool(it.get("tileH")), bool(it.get("tileV")))
            if rot:
                rgba[(s < 0) | (s > 1) | (t < 0) | (t > 1), 3] = 0
        vertex = it.get("vertex")
        if vertex:
            rgba = rgba * np.array(vertex[:4], dtype=np.float32)
        grad = it.get("gradient")
        if grad:
            orient, cmin, cmax = grad
            f = (1 - t) if orient == "VERTICAL" else s
            f = np.clip(f, 0, 1)[..., None]
            rgba = rgba * (np.array(cmin, dtype=np.float32) * (1 - f) + np.array(cmax, dtype=np.float32) * f)
        desat = it.get("desat")
        if desat:
            lum = (rgba[..., :3] @ LUMA)[..., None]
            rgba[..., :3] = rgba[..., :3] * (1 - desat) + lum * desat
        alpha = rgba[..., 3] * it.get("alpha", 1)
        for m in it.get("masks") or []:
            alpha = alpha * self.mask_alpha(m, xs, ys)
        blend(self.canvas, None, x0, y0, rgba[..., :3], alpha, it.get("blend") or "BLEND")

    def mask_alpha(self, m, xs, ys):
        mx, my, mw, mh = m["rect"]
        if mw <= 0 or mh <= 0:
            return np.zeros_like(xs)
        s = (xs + self.ox + 0.5 - mx) / mw
        t = (ys + self.oy + 0.5 - my) / mh
        ulx, uly, llx, lly, urx, ury, lrx, lry = m.get("uv") or [0, 0, 0, 1, 1, 0, 1, 1]
        u = ulx * (1 - s) * (1 - t) + urx * s * (1 - t) + llx * (1 - s) * t + lrx * s * t
        v = uly * (1 - s) * (1 - t) + ury * s * (1 - t) + lly * (1 - s) * t + lry * s * t
        a = sample(load_texture(m["file"]), u, v, False, False)[..., 3]
        # Ausserhalb der Maske ist nichts sichtbar.
        a[(s < 0) | (s > 1) | (t < 0) | (t > 1)] = 0
        return a

    def draw_line(self, it):
        (ax, ay), (bx, by) = it["p0"], it["p1"]
        half = max(it.get("thickness", 1), 1) / 2
        x0, x1 = min(ax, bx) - half - 1, max(ax, bx) + half + 1
        y0, y1 = min(ay, by) - half - 1, max(ay, by) + half + 1
        win = self.window(x0, y0, x1 - x0, y1 - y0, it.get("clip"))
        if not win:
            return
        wx0, wy0, wx1, wy1 = win
        ys, xs = np.mgrid[wy0:wy1, wx0:wx1].astype(np.float32)
        px, py = xs + self.ox + 0.5, ys + self.oy + 0.5
        dx, dy = bx - ax, by - ay
        length2 = dx * dx + dy * dy or 1.0
        tt = np.clip(((px - ax) * dx + (py - ay) * dy) / length2, 0, 1)
        dist = np.hypot(px - (ax + tt * dx), py - (ay + tt * dy))
        cover = np.clip(half + 0.5 - dist, 0, 1)
        color = list(it.get("color") or [1, 1, 1, 1]) + [1] * 4
        rgb = np.array(color[:3], dtype=np.float32)
        a = color[3]
        if it.get("vertex"):
            rgb = rgb * np.array(it["vertex"][:3], dtype=np.float32)
            a *= it["vertex"][3] if len(it["vertex"]) > 3 else 1
        rgbs = np.broadcast_to(rgb, cover.shape + (3,))
        blend(self.canvas, None, wx0, wy0, rgbs, cover * a * it.get("alpha", 1), it.get("blend") or "BLEND")

    def draw_swipe(self, it):
        x, y, w, h = it["rect"]
        win = self.window(x, y, w, h, it.get("clip"))
        if not win:
            return
        x0, y0, x1, y1 = win
        ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        cx, cy = x + w / 2, y + h / 2
        # Winkel ab 12 Uhr im Uhrzeigersinn (0..1).
        ang = (np.arctan2(xs + self.ox + 0.5 - cx, -(ys + self.oy + 0.5 - cy)) / (2 * math.pi)) % 1.0
        done = 1 - it["remain"]
        dark = ang < it["remain"] if it.get("reverse") else ang >= done
        color = it.get("color") or [0, 0, 0, 0.8]
        alpha = dark.astype(np.float32) * color[3] * it.get("alpha", 1)
        rgb = np.broadcast_to(np.array(color[:3], dtype=np.float32), alpha.shape + (3,))
        blend(self.canvas, None, x0, y0, rgb, alpha, "BLEND")

    def draw_model(self, it):
        x, y, w, h = it["rect"]
        self.draw_texture({"rect": it["rect"], "color": list(MODEL_GREY), "alpha": it.get("alpha", 1), "clip": it.get("clip")})
        label = it.get("label") or "3D"
        px = max(8, int(min(w, h) / 4))
        text = {"font": FALLBACK_FONT, "px": px, "flags": "", "alpha": it.get("alpha", 1), "clip": it.get("clip"),
                "lineH": px, "asc": px * 0.8, "desc": -px * 0.2,
                "lines": [{"x": x + 2, "y": y + (h - px) / 2, "glyphs": [], "textures": []}]}
        pen = 0
        face = self.face(FALLBACK_FONT, px)
        for ch in label:
            text["lines"][0]["glyphs"].append([ord(ch), pen, 0.9, 0.9, 0.9, 1])
            face.load_char(ch)
            pen += face.glyph.advance.x / FIXED_26_6
        self.draw_text(text)

    # Text ----------------------------------------------------------------------

    def face(self, path, px):
        key = (path, px)
        f = self.faces.get(key)
        if f is None:
            f = freetype.Face(path)
            f.set_pixel_sizes(0, px)
            self.faces[key] = f
        return f

    def glyph(self, path, px, cp, stroke, mono):
        """(bitmap float32, left, top) fuer Fuellung oder Kontur."""
        key = (path, px, cp, stroke, mono)
        g = self.glyphs.get(key)
        if g is not None:
            return g
        face = self.face(path, px)
        flags = freetype.FT_LOAD_DEFAULT
        if mono:
            flags |= freetype.FT_LOAD_TARGET_MONO
        face.load_char(cp, flags | freetype.FT_LOAD_NO_BITMAP)
        mode = freetype.FT_RENDER_MODE_MONO if mono else freetype.FT_RENDER_MODE_NORMAL
        glyph = face.glyph.get_glyph()
        if stroke:
            stroker = freetype.Stroker()
            stroker.set(stroke * FIXED_26_6, freetype.FT_STROKER_LINECAP_ROUND, freetype.FT_STROKER_LINEJOIN_ROUND, 0)
            glyph.stroke(stroker, True)
        bg = glyph.to_bitmap(mode, freetype.Vector(0, 0), True)
        bm = bg.bitmap
        rows, width, pitch = bm.rows, bm.width, bm.pitch
        if rows == 0 or width == 0:
            g = (None, 0, 0)
        else:
            buf = np.array(bm.buffer, dtype=np.uint8)
            if mono:
                bits = np.unpackbits(buf.reshape(rows, pitch), axis=1)[:, :width]
                arr = bits.astype(np.float32)
            else:
                arr = buf.reshape(rows, pitch)[:, :width].astype(np.float32) / 255.0
            g = (arr, bg.left, bg.top)
        self.glyphs[key] = g
        return g

    def stamp(self, arr, gx, gy, rgb, alpha, clip):
        h, w = arr.shape
        win = self.window(gx, gy, w, h, clip)
        if not win:
            return
        x0, y0, x1, y1 = win
        sx, sy = x0 + self.ox - gx, y0 + self.oy - gy
        cover = arr[sy:sy + (y1 - y0), sx:sx + (x1 - x0)] * alpha
        rgbs = np.broadcast_to(np.array(rgb, dtype=np.float32), cover.shape + (3,))
        blend(self.canvas, None, x0, y0, rgbs, cover, "BLEND")

    def baseline(self, it, line):
        """Grundlinie: die Zeilenhoehe (Schrifthoehe) umschliesst Ober- und Unterlaenge mittig."""
        asc, desc, line_h = it["asc"], it["desc"], it["lineH"]
        return line["y"] + (line_h - (asc - desc)) / 2 + asc

    def draw_text(self, it):
        flags = (it.get("flags") or "").upper()
        mono = "MONOCHROME" in flags
        stroke = THICK_OUTLINE_PX if "THICK" in flags else (OUTLINE_PX if "OUTLINE" in flags else 0)
        path, px, alpha, clip = it["font"], it["px"], it.get("alpha", 1), it.get("clip")
        shadow = it.get("shadow")
        for line in it["lines"]:
            base = round(self.baseline(it, line))
            lx = line["x"]
            for tx in line.get("textures") or []:
                self.draw_texture({"rect": [round(lx + tx["x"]), round(line["y"] + tx["y"]), round(tx["w"]), round(tx["h"])],
                                   "file": tx["file"], "uv": tx["uv"], "vertex": tx.get("vertex"), "alpha": alpha, "clip": clip})
            passes = []
            if shadow:
                passes.append(("shadow", shadow["dx"], shadow["dy"]))
            if stroke:
                passes.append(("outline", 0, 0))
            passes.append(("fill", 0, 0))
            for kind, dx, dy in passes:
                for cp, gx, r, g, b, a in line["glyphs"]:
                    pen = round(lx + gx + dx)
                    if kind == "fill" or kind == "shadow" and not stroke:
                        arr, left, top = self.glyph(path, px, cp, 0, mono)
                    else:
                        arr, left, top = self.glyph(path, px, cp, stroke, mono)
                    if arr is None:
                        continue
                    if kind == "shadow":
                        sc = shadow["color"]
                        rgb, aa = sc[:3], (sc[3] if len(sc) > 3 else 1) * a
                    elif kind == "outline":
                        rgb, aa = (0, 0, 0), a
                    else:
                        rgb, aa = (r, g, b), a
                    self.stamp(arr, pen + left, base + round(dy) - top, rgb, aa * alpha, clip)

    # Ablauf ----------------------------------------------------------------------

    def run(self):
        draw = {"tex": self.draw_texture, "text": self.draw_text, "line": self.draw_line,
                "swipe": self.draw_swipe, "model": self.draw_model}
        problems = []
        for it in self.data["items"]:
            try:
                draw[it["k"]](it)
            except Exception as e:  # ein kaputtes Element darf das Bild nicht verhindern, wird aber gemeldet
                problems.append("%s %s: %s" % (it.get("k"), it.get("name"), e))
        return problems

    def image(self, scale=1.0):
        arr = (np.clip(self.canvas, 0, 1) * 255 + 0.5).astype(np.uint8)
        im = Image.fromarray(arr, "RGB")
        if scale != 1.0:
            im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.LANCZOS)
        return im
