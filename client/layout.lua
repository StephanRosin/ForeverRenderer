-- Anker-Loeser wie im Client. Gerechnet wird in "Weltkoordinaten": Einheiten
-- bei effektiver Skalierung 1, Ursprung unten links, Bildschirmhoehe 768.
-- Ein Rahmen mit effektiver Skalierung s hat Breite w*s in der Welt; seine
-- Anker-Versaetze zaehlen in seinen eigenen Einheiten (also auch *s).
local L = { gen = 0, screenW = 1024, screenH = 768, physW = 1024, physH = 768 }

-- Welt-Einheit = 768 / physische Hoehe; ein Pixel ist physH/768 Welt-Einheiten gross.
L.BASE_HEIGHT = 768

local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
L.POINTS = POINTS

function L.SetScreen(physW, physH)
    L.physW, L.physH = physW, physH
    L.screenH = L.BASE_HEIGHT
    L.screenW = L.BASE_HEIGHT * physW / physH
    L.Touch()
end

-- Pixel je Welt-Einheit.
function L.PixelsPerUnit() return L.physH / L.BASE_HEIGHT end

-- Jede Aenderung an Ankern, Groessen, Skalierung, Text oder Sichtbarkeit
-- macht alle zwischengespeicherten Rechtecke ungueltig.
function L.Touch() L.gen = L.gen + 1 end

local function st(o) return rawget(o, 0) end

function L.EffectiveScale(o)
    local s = st(o)
    local scale = s.scale or 1
    if s.animScale then scale = scale * s.animScale end
    local p = s.parent
    if p and not s.ignoreParentScale then
        return scale * L.EffectiveScale(p)
    end
    return scale
end

-- Groesse ohne Anker (eigene Einheiten). FontStrings messen sich selbst.
local function ownSize(o, s)
    local w, h = s.width, s.height
    if s.measure and (not w or not h or w == 0 or h == 0) then
        local mw, mh = s.measure(o)
        if not w or w == 0 then w = mw end
        if not h or h == 0 then h = mh end
    end
    return w or 0, h or 0
end

local resolving = {}

-- Welt-Rechteck {l, b, w, h} oder nil, wenn es sich nicht aufloesen laesst.
function L.Rect(o)
    local s = st(o)
    if s.rectGen == L.gen then return s.rect end
    if resolving[o] then return nil end -- Ankerschleife: wie im Client ungueltig
    resolving[o] = true
    local r = L.Compute(o, s)
    resolving[o] = nil
    s.rect, s.rectGen = r, L.gen
    return r
end

function L.ScreenRect()
    return { 0, 0, L.screenW, L.screenH }
end

local function relRect(o, s, rel)
    if rel == nil then
        if s.parent then return L.Rect(s.parent) end
        return L.ScreenRect()
    end
    if rel == "SCREEN" then return L.ScreenRect() end
    return L.Rect(rel)
end

function L.Compute(o, s)
    local es = L.EffectiveScale(o)
    -- Fuellung eines StatusBar: der Client legt sie selbst ueber den gefuellten Teil.
    local bar = s.statusBar
    if bar and st(bar).barTex == o then
        local br = L.Rect(bar)
        if not br then return nil end
        local bs = st(bar)
        local frac = package.loaded.widgets.BarFraction(bar)
        if bs.orientation == "VERTICAL" then
            local h = br[4] * frac
            return { br[1], bs.reverse and (br[2] + br[4] - h) or br[2], br[3], h }
        end
        local w = br[3] * frac
        return { bs.reverse and (br[1] + br[3] - w) or br[1], br[2], w, br[4] }
    end
    -- Kind eines ScrollFrames: liegt an dessen linker oberer Ecke, um den Bildlauf versetzt.
    if s.scrollParent then
        local ps = st(s.scrollParent)
        local pr = L.Rect(s.scrollParent)
        if not pr then return nil end
        local w, h = ownSize(o, s)
        local pes = L.EffectiveScale(s.scrollParent)
        return { pr[1] - (ps.hScroll or 0) * pes, pr[2] + pr[4] + (ps.vScroll or 0) * pes - h * es, w * es, h * es }
    end
    local pts = s.points
    if not pts or #pts == 0 then return nil end
    local xs, ys = {}, {}
    for _, p in ipairs(pts) do
        local rr = relRect(o, s, p.rel)
        if not rr then return nil end
        local rf = POINTS[p.relPoint]
        local ax = rr[1] + rf[1] * rr[3] + (p.x or 0) * es
        local ay = rr[2] + rf[2] * rr[4] + (p.y or 0) * es
        local f = POINTS[p.point]
        xs[f[1]] = ax
        ys[f[2]] = ay
    end
    local w, h = ownSize(o, s)
    local function axis(c, size)
        local lo, mid, hi = c[0], c[0.5], c[1]
        if lo and hi then return lo, hi - lo, true end
        if lo and mid then return lo, 2 * (mid - lo), true end
        if hi and mid then return 2 * mid - hi, 2 * (hi - mid), true end
        size = size * es
        if lo then return lo, size, false end
        if hi then return hi - size, size, false end
        if mid then return mid - size / 2, size, false end
        return nil
    end
    local l, ww, fixedW = axis(xs, w)
    local b, hh, fixedH = axis(ys, h)
    if not l or not b then return nil end
    -- Text mit fester Breite aus zwei Ankern: Hoehe aus dem umgebrochenen Text.
    if s.measure and fixedW and not fixedH and (not s.height or s.height == 0) then
        local _, mh = s.measure(o, ww / es)
        local newH = mh * es
        if ys[1] then b = ys[1] - newH
        elseif ys[0.5] then b = ys[0.5] - newH / 2 end
        hh = newH
    end
    return { l, b, ww, hh, fixedW = fixedW, fixedH = fixedH }
end

-- Rechteck in physischen Pixeln (Ursprung oben links), auf das Pixelraster gerundet.
function L.PixelRect(r)
    local ppu = L.PixelsPerUnit()
    local x0 = math.floor(r[1] * ppu + 0.5)
    local x1 = math.floor((r[1] + r[3]) * ppu + 0.5)
    local yTop = math.floor((L.screenH - (r[2] + r[4])) * ppu + 0.5)
    local yBot = math.floor((L.screenH - r[2]) * ppu + 0.5)
    return x0, yTop, x1 - x0, yBot - yTop
end

return L
