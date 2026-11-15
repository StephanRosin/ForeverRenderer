-- Erzeugt die Zeichenliste: alles Sichtbare in Client-Reihenfolge (Strata,
-- Level, Rahmen, DrawLayer, Sublevel), mit Pixel-Rechtecken, Clipping,
-- Alpha, Texturkoordinaten und gesetztem Text (Glyphen mit Position).
local W = require("widgets")
local L = require("layout")
local Font = require("font")
local Media = require("media")
local R = require("report")

local D = {}
local st = W.st

-- Blizzard-Rahmen, die mitgezeichnet werden, obwohl Blizzard sie angelegt hat.
-- Blizzard-Rahmen, die zum Bild gehoeren (samt Kindern): Tooltip und die
-- Minimap, die ForeverSquareMinimap umbaut.
-- Weitere per Szenario (drawBlizzard = { "MinimapCluster" }).
D.blizzardAllow = { GameTooltip = true }

local function intersect(a, b)
    if not a then return b end
    if not b then return a end
    local x0, y0 = math.max(a[1], b[1]), math.max(a[2], b[2])
    local x1, y1 = math.min(a[1] + a[3], b[1] + b[3]), math.min(a[2] + a[4], b[2] + b[4])
    return { x0, y0, math.max(0, x1 - x0), math.max(0, y1 - y0) }
end

local function pixelBox(r)
    local x, y, w, h = L.PixelRect(r)
    return { x, y, w, h }
end

-- Unrund (fuer Text und Linien): Welt -> Pixel ohne Rundung.
local function pixelFloat(r)
    local ppu = L.PixelsPerUnit()
    return r[1] * ppu, (L.screenH - (r[2] + r[4])) * ppu, r[3] * ppu, r[4] * ppu
end

local function frameDrawn(f)
    local s = st(f)
    if not s.blizzard or s.forceDraw then return true end
    while f do
        if D.blizzardAllow[st(f).name or ""] then return true end
        f = st(f).parent
    end
    return false
end

local function textureItem(t, s, rect, alpha, clip)
    local item = { k = "tex", alpha = alpha, clip = clip, name = t:GetDebugName() }
    if s.color then item.color = s.color
    elseif s.file then item.file = s.file
    else return nil end
    local coords = s.coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
    local box = pixelBox(rect)
    -- StatusBar: Fuellung schneidet Rechteck und Texturkoordinaten zu.
    local bar = s.statusBar
    if bar and st(bar).barTex == t then
        local frac = W.BarFraction(bar)
        local bs = st(bar)
        local br = L.Rect(bar)
        if not br then return nil end
        rect = { br[1], br[2], br[3], br[4] }
        box = pixelBox(rect)
        local vertical = bs.orientation == "VERTICAL"
        local rev = bs.reverse
        local u0, u1 = coords[1], coords[5]
        local v0, v1 = coords[2], coords[4]
        if vertical then
            local h = math.floor(box[4] * frac + 0.5)
            if rev then box = { box[1], box[2], box[3], h } else box = { box[1], box[2] + box[4] - h, box[3], h } end
            if rev then coords = { u0, v0, u0, v0 + (v1 - v0) * frac, u1, v0, u1, v0 + (v1 - v0) * frac }
            else coords = { u0, v1 - (v1 - v0) * frac, u0, v1, u1, v1 - (v1 - v0) * frac, u1, v1 } end
        else
            local w = math.floor(box[3] * frac + 0.5)
            if rev then
                box = { box[1] + box[3] - w, box[2], w, box[4] }
                coords = { u1 - (u1 - u0) * frac, v0, u1 - (u1 - u0) * frac, v1, u1, v0, u1, v1 }
            else
                box = { box[1], box[2], w, box[4] }
                coords = { u0, v0, u0, v1, u0 + (u1 - u0) * frac, v0, u0 + (u1 - u0) * frac, v1 }
            end
        end
        if box[3] <= 0 or box[4] <= 0 then return nil end
    end
    item.rect = box
    item.uv = coords
    item.vertex = s.vertex
    if s.gradient then item.gradient = { s.gradient.orientation, s.gradient.min, s.gradient.max } end
    item.blend = s.blend
    item.desat = s.desat
    if s.rotation and s.rotation ~= 0 then item.rotation = s.rotation item.rotCenter = s.rotCenter end
    if s.horizTile or s.vertTile or s.wrapH == "REPEAT" or s.wrapV == "REPEAT" then
        item.tileH = s.horizTile or s.wrapH == "REPEAT" or nil
        item.tileV = s.vertTile or s.wrapV == "REPEAT" or nil
        -- Kacheln in Texturpixeln: Bildschirm-Pixel je Texturpixel = effektive Skalierung * ppu.
        item.tileScale = L.EffectiveScale(t) * L.PixelsPerUnit()
    end
    if s.slice then
        item.slice = s.slice
        item.sliceScale = L.EffectiveScale(t) * L.PixelsPerUnit()
    end
    if s.masks then
        item.masks = {}
        for _, m in ipairs(s.masks) do
            local ms = st(m)
            local mr = L.Rect(m)
            if mr and ms.file then
                item.masks[#item.masks + 1] = { file = ms.file, rect = pixelBox(mr), uv = ms.coords or { 0, 0, 0, 1, 1, 0, 1, 1 } }
            end
        end
    end
    return item
end

local function lineItem(t, s, alpha, clip)
    local function endPoint(p)
        if not p then return nil end
        local rel = p.rel or s.parent
        local r = L.Rect(rel)
        if not r then return nil end
        local f = L.POINTS[p.point]
        local es = L.EffectiveScale(t)
        return r[1] + f[1] * r[3] + p.x * es, r[2] + f[2] * r[4] + p.y * es
    end
    local x0, y0 = endPoint(s.startPt)
    local x1, y1 = endPoint(s.endPt)
    if not x0 or not x1 then return nil end
    local ppu = L.PixelsPerUnit()
    local item = { k = "line", alpha = alpha, clip = clip, name = t:GetDebugName(),
        p0 = { x0 * ppu, (L.screenH - y0) * ppu }, p1 = { x1 * ppu, (L.screenH - y1) * ppu },
        thickness = (s.thickness or 1) * L.EffectiveScale(t) * ppu }
    if s.color then item.color = s.color elseif s.file then item.file = s.file else return nil end
    item.vertex = s.vertex
    item.blend = s.blend
    return item
end

local function textItem(fs, s, rect, alpha, clip)
    local text = s.text
    if not text or text == "" then return nil end
    local widthUnits = (rect.fixedW or (s.width and s.width > 0)) and rect[3] / L.EffectiveScale(fs) or nil
    local lay = W.TextLayout(fs, widthUnits)
    if not lay then return nil end
    local x, y, w, h = pixelFloat(rect)
    local justH = W.fontProp(fs, "justifyH") or "CENTER"
    local justV = W.fontProp(fs, "justifyV") or "MIDDLE"
    local lineH = (W.fontProp(fs, "fontHeight") or 12) * lay.unitPx
    local spacing = (W.fontProp(fs, "spacing") or 0) * lay.unitPx
    local blockH = lay.height
    local top = y
    if justV == "MIDDLE" then top = y + (h - blockH) / 2 elseif justV == "BOTTOM" then top = y + h - blockH end
    local asc, desc = Font.Metrics(lay.file, lay.px)
    local item = { k = "text", alpha = alpha, clip = clip, name = fs:GetDebugName(), font = lay.file, px = lay.px,
        flags = W.fontProp(fs, "fontFlags") or "", lines = {}, asc = asc, desc = desc, lineH = lineH }
    local sc = W.fontProp(fs, "shadowColor")
    local so = W.fontProp(fs, "shadowOffset")
    if so and (so[1] ~= 0 or so[2] ~= 0) then
        local c = sc or { 0, 0, 0, 1 }
        item.shadow = { color = c, dx = so[1] * lay.unitPx, dy = -so[2] * lay.unitPx }
    end
    local vertex = s.vertex
    for i, ln in ipairs(lay.lines) do
        local lx = x
        if justH == "CENTER" then lx = x + (w - ln.w) / 2 elseif justH == "RIGHT" then lx = x + w - ln.w end
        local ly = top + (i - 1) * (lineH + spacing)
        local glyphs, textures = {}, {}
        for _, it in ipairs(ln.items) do
            local tok = it.tok
            if tok.k == "g" then
                if tok.cp ~= 32 then
                    local c = tok.color or { 1, 1, 1, 1 }
                    if vertex then c = { c[1] * vertex[1], c[2] * vertex[2], c[3] * vertex[3], (c[4] or 1) * (vertex[4] or 1) } end
                    glyphs[#glyphs + 1] = { tok.cp, it.x, c[1], c[2], c[3], c[4] or 1 }
                end
            elseif tok.k == "tex" then
                local e
                if tok.atlas then
                    local a = Media.Atlas(tok.path)
                    if a then e = { file = a.abs, uv = { a.left, a.top, a.left, a.bottom, a.right, a.top, a.right, a.bottom } } end
                else
                    local m = Media.Texture(tonumber(tok.path) or tok.path)
                    if m then
                        local uv = { 0, 0, 0, 1, 1, 0, 1, 1 }
                        if tok.l and tok.tw and tok.tw > 0 then
                            local l, r, t2, b = tok.l / tok.tw, tok.r / tok.tw, tok.t / tok.th, tok.b / tok.th
                            uv = { l, t2, l, b, r, t2, r, b }
                        end
                        e = { file = m.file, uv = uv }
                    end
                end
                if e then
                    textures[#textures + 1] = { file = e.file, uv = e.uv, x = it.x + (tok.ox or 0) * lay.unitPx,
                        y = (lineH - tok.ph) / 2 - (tok.oy or 0) * lay.unitPx, w = tok.pw, h = tok.ph,
                        vertex = tok.vr and { tok.vr / 255, tok.vg / 255, tok.vb / 255, 1 } or nil }
                end
            end
        end
        item.lines[#item.lines + 1] = { x = lx, y = ly, glyphs = glyphs, textures = textures }
    end
    return item
end

-- Sammelt Regionen eines Rahmens in Ebenen-Reihenfolge.
local function frameItems(f, out, alphaOf, clip, hovered)
    local s = st(f)
    -- Die Minimap-Karte zeichnet der Client selbst: Platzhalter unter den eigenen Regionen.
    if s.type == "Minimap" then
        local rect = L.Rect(f)
        if rect then
            out[#out + 1] = { k = "model", rect = pixelBox(rect), alpha = f:GetEffectiveAlpha(), clip = clip,
                label = "Karte", name = f:GetDebugName() }
        end
    end
    local regions = {}
    for _, r in ipairs(s.regions or {}) do
        local rs = st(r)
        if rs.shown and not rs.stateHidden then regions[#regions + 1] = r end
    end
    table.sort(regions, function(a, b)
        local as, bs = st(a), st(b)
        local la, lb = W.LAYER_INDEX[as.layer or "ARTWORK"], W.LAYER_INDEX[bs.layer or "ARTWORK"]
        if la ~= lb then return la < lb end
        if (as.sublevel or 0) ~= (bs.sublevel or 0) then return (as.sublevel or 0) < (bs.sublevel or 0) end
        return as.seq < bs.seq
    end)
    local showHighlight = hovered or s.lockHighlight
    for _, r in ipairs(regions) do
        local rs = st(r)
        if rs.layer ~= "HIGHLIGHT" or showHighlight then
            if not (s.disabledLayers and s.disabledLayers[rs.layer or "ARTWORK"]) then
                local alpha = r:GetEffectiveAlpha()
                if alpha > 0.001 then
                    local item
                    if rs.type == "Line" then item = lineItem(r, rs, alpha, clip)
                    else
                        local rect = L.Rect(r)
                        if rect then
                            if rs.animOffset then
                                local es = L.EffectiveScale(r)
                                rect = { rect[1] + rs.animOffset[1] * es, rect[2] + rs.animOffset[2] * es, rect[3], rect[4], fixedW = rect.fixedW, fixedH = rect.fixedH }
                            end
                            if rs.type == "Texture" then item = textureItem(r, rs, rect, alpha, clip)
                            elseif rs.type == "FontString" then item = textItem(r, rs, rect, alpha, clip) end
                        end
                    end
                    if item then
                        item.layer = rs.layer
                        out[#out + 1] = item
                    end
                end
            end
        end
    end
    -- Cooldown-Wischer und Modell-Platzhalter gehoeren zum Rahmen selbst.
    if s.type == "Cooldown" and (s.cdDuration or 0) > 0 and not s.noSwipe then
        local now = W.now()
        local remain = (s.cdStart + s.cdDuration - now) / s.cdDuration
        local rect = L.Rect(f)
        if rect and remain > 0 and remain <= 1 then
            out[#out + 1] = { k = "swipe", rect = pixelBox(rect), remain = remain, reverse = s.reverse or nil,
                color = s.swipeColor or { 0, 0, 0, 0.8 }, alpha = f:GetEffectiveAlpha(), clip = clip, name = f:GetDebugName() }
            if not s.hideNumbers then
                local left = s.cdStart + s.cdDuration - now
                local fs = f:GetCountdownFontString()
                local txt = left >= 60 and string.format("%dm", math.ceil(left / 60)) or string.format("%d", math.ceil(left))
                fs:SetText(txt)
                local fr = L.Rect(fs)
                if fr then
                    local it = textItem(fs, st(fs), fr, f:GetEffectiveAlpha(), clip)
                    if it then out[#out + 1] = it end
                end
            end
        end
    end
    if f.__isModel then
        local rect = L.Rect(f)
        if rect then
            out[#out + 1] = { k = "model", rect = pixelBox(rect), alpha = f:GetEffectiveAlpha(), clip = clip,
                label = s.modelUnit or "3D", name = f:GetDebugName() }
        end
    end
end

-- Alle sichtbaren Rahmen mit Clip-Rechteck sammeln.
local function gatherFrames(f, clip, list)
    local s = st(f)
    if not s.shown then return end
    local myClip = clip
    if s.clips then
        local r = L.Rect(f)
        if r then myClip = intersect(clip, pixelBox(r)) end
    end
    list[#list + 1] = { frame = f, clip = clip }
    for _, c in ipairs(s.children or {}) do gatherFrames(c, myClip, list) end
end

function D.Collect()
    local frames = {}
    local roots = {}
    for f in pairs(W.roots) do roots[#roots + 1] = f end
    table.sort(roots, function(a, b) return st(a).seq < st(b).seq end)
    for _, f in ipairs(roots) do gatherFrames(f, nil, frames) end
    table.sort(frames, function(a, b)
        local as, bs = st(a.frame), st(b.frame)
        local sa, sb = W.STRATA_INDEX[as.strata or "MEDIUM"] or 3, W.STRATA_INDEX[bs.strata or "MEDIUM"] or 3
        if sa ~= sb then return sa < sb end
        if (as.level or 0) ~= (bs.level or 0) then return (as.level or 0) < (bs.level or 0) end
        return as.seq < bs.seq
    end)
    local items = {}
    for _, e in ipairs(frames) do
        if frameDrawn(e.frame) then
            local hovered = W.hovered and W.hovered[e.frame]
            -- Ein Fehler beim Zeichnen eines Rahmens kostet nur diesen Rahmen (steht im Bericht).
            R.Call(frameItems, e.frame, items, nil, e.clip, hovered)
        end
    end
    return items
end

return D
