-- Widget-Modell des Clients: Objekte sind Tabellen mit dem Zustand in [0]
-- (der Client legt dort sein userdata ab) und den Methoden im Metatable.
-- Addons duerfen beliebige Felder setzen; Mixins kopieren sich hinein.
local L = require("layout")
local R = require("report")
local Sec = require("secret")
local Media = require("media")
local Text = require("text")
local Font = require("font")

local W = { classes = {}, all = {}, eventFrames = {}, roots = {}, hooks = {} }
local seq = 0

local function st(o) return rawget(o, 0) end
W.st = st

local function touch() L.Touch() end

W.STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
W.STRATA_INDEX = { WORLD = 0 }
for i, s in ipairs(W.STRATA) do W.STRATA_INDEX[s] = i end
W.LAYERS = { "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT" }
W.LAYER_INDEX = {}
for i, s in ipairs(W.LAYERS) do W.LAYER_INDEX[s] = i end

local MAX_FRAME_LEVEL = 10000
local DEFAULT_FONT_HEIGHT = 12

-- Klassenaufbau ---------------------------------------------------------------

local function class(name, ...)
    local methods = {}
    for _, base in ipairs({ ... }) do
        for k, v in pairs(W.classes[base].methods) do methods[k] = v end
    end
    local c = { name = name, methods = methods, meta = { __index = methods }, parentClass = W.classes[(...) or ""] }
    -- Einige Bibliotheken pruefen tostring(frame); der Client liefert "table: ...".
    W.classes[name] = c
    return methods
end
W.class = class

local function isA(o, typeName)
    local s = st(o)
    if not s then return false end
    local c = W.classes[s.type]
    while c do
        if c.name == typeName then return true end
        c = c.parentClass
    end
    return false
end

-- Zahlen aus Argumenten: der Client nimmt auch Zahlen-Strings.
local function num(v, default)
    v = Sec.Unwrap(v)
    if v == nil then return default end
    return tonumber(v) or default
end

local function newObject(typeName, parent, name)
    seq = seq + 1
    local c = W.classes[typeName]
    local s = { type = typeName, seq = seq, parent = parent, shown = true, alpha = 1, points = {} }
    local o = setmetatable({ [0] = s }, c.meta)
    s.self = o
    if name then
        if parent and name:find("$parent", 1, true) then
            local pn = st(parent).name or ""
            name = name:gsub("%$parent", pn)
        elseif name:find("$parent", 1, true) then
            name = name:gsub("%$parent", "")
        end
        s.name = name
        rawset(_G, name, o)
    end
    W.all[#W.all + 1] = o
    return o, s
end
W.newObject = newObject

-- Object / FrameScriptObject ---------------------------------------------------

local Object = class("Object")
function Object:GetName() return st(self).name end
function Object:GetDebugName()
    local s = st(self)
    if s.name then return s.name end
    local p = s.parent
    if p then
        for k, v in pairs(p) do if v == self then return Object.GetDebugName(p) .. "." .. tostring(k) end end
    end
    return tostring(self)
end
function Object:GetObjectType() return st(self).type end
function Object:IsObjectType(t) return isA(self, t) end
function Object:IsForbidden() return false end
function Object:SetForbidden() end
function Object:GetParent() return st(self).parent end
function Object:GetParentKey() return st(self).parentKey end
function Object:SetParentKey(k)
    local s = st(self)
    s.parentKey = k
    if s.parent then rawset(s.parent, k, self) end
end
function Object:ClearParentKey() st(self).parentKey = nil end
function Object:IsProtected() return false, false end
function Object:CanChangeProtectedState() return true end
function Object:IsPreventingSecretValues() return false end
function Object:SetPreventSecretValues() end
function Object:HasSecretValues() return false end
function Object:HasSecretAspect() return false end
function Object:HasAnySecretAspect() return false end
function Object:SetToDefaults() end

-- Skripte: Name -> Funktion; HookScript haengt Nachlaeufer an.
function Object:SetScript(name, fn)
    local s = st(self)
    s.scripts = s.scripts or {}
    s.scripts[name] = fn
    s.hooks = s.hooks or {}
    s.hooks[name] = nil
    if name == "OnUpdate" then W.onUpdate[self] = fn and true or nil end
end
function Object:GetScript(name)
    local s = st(self)
    return s.scripts and s.scripts[name]
end
function Object:HookScript(name, fn)
    local s = st(self)
    s.scripts = s.scripts or {}
    if not s.scripts[name] then
        s.scripts[name] = fn
        if name == "OnUpdate" then W.onUpdate[self] = true end
        return true
    end
    s.hooks = s.hooks or {}
    s.hooks[name] = s.hooks[name] or {}
    table.insert(s.hooks[name], fn)
    return true
end
function Object:HasScript(name) return true end

-- Ruft ein Skript samt Hooks geschuetzt auf.
function W.Fire(o, name, ...)
    local s = st(o)
    local fn = s.scripts and s.scripts[name]
    if not fn then return end
    R.Call(fn, o, ...)
    local hooks = s.hooks and s.hooks[name]
    if hooks then
        for _, h in ipairs(hooks) do R.Call(h, o, ...) end
    end
end
W.onUpdate = setmetatable({}, { __mode = "k" })

-- ScriptRegion: Sichtbarkeit, Anker, Groesse -----------------------------------

local Region = class("ScriptRegion", "Object")

local function normPoint(p)
    if type(p) ~= "string" then return nil end
    p = p:upper()
    if L.POINTS[p] then return p end
    return nil
end

local function resolveRel(rel)
    if type(rel) == "string" then
        local o = rawget(_G, rel)
        if o == nil then return nil, true end
        return o
    end
    return rel
end

function Region:SetPoint(point, rel, relPoint, x, y)
    local s = st(self)
    local p = normPoint(point)
    if not p then error("SetPoint: invalid point " .. tostring(point), 2) end
    -- Kurzformen: SetPoint(p, x, y) und SetPoint(p, rel, x, y)
    if type(Sec.Unwrap(rel)) == "number" then
        rel, relPoint, x, y = nil, p, rel, relPoint
    elseif type(Sec.Unwrap(relPoint)) == "number" then
        relPoint, x, y = p, relPoint, x
    end
    local relObj, missing = resolveRel(rel)
    if missing then error("SetPoint: unknown region " .. tostring(rel), 2) end
    if relObj == self then error("Cannot anchor to itself", 2) end
    local rp = normPoint(relPoint) or p
    for i, q in ipairs(s.points) do
        if q.point == p then table.remove(s.points, i) break end
    end
    if rel == nil and relPoint == nil and x == nil then relObj = nil end
    table.insert(s.points, { point = p, rel = relObj, relPoint = rp, x = num(x, 0), y = num(y, 0) })
    touch()
end
function Region:SetAllPoints(rel, doResize)
    local s = st(self)
    local relObj = resolveRel(rel)
    s.points = {
        { point = "TOPLEFT", rel = relObj, relPoint = "TOPLEFT", x = 0, y = 0 },
        { point = "BOTTOMRIGHT", rel = relObj, relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    }
    touch()
end
function Region:ClearAllPoints()
    st(self).points = {}
    touch()
end
function Region:ClearPoint(point)
    local s = st(self)
    point = normPoint(point)
    for i, q in ipairs(s.points) do
        if q.point == point then table.remove(s.points, i) break end
    end
    touch()
end
function Region:ClearPointsOffset()
    for _, q in ipairs(st(self).points) do q.x, q.y = 0, 0 end
    touch()
end
function Region:AdjustPointsOffset(dx, dy)
    for _, q in ipairs(st(self).points) do q.x, q.y = q.x + num(dx, 0), q.y + num(dy, 0) end
    touch()
end
function Region:GetNumPoints() return #st(self).points end
function Region:GetPoint(i)
    if type(i) == "string" then
        for _, q in ipairs(st(self).points) do
            if q.point == i:upper() then return q.point, q.rel, q.relPoint, q.x, q.y end
        end
        return nil
    end
    local q = st(self).points[i or 1]
    if not q then return nil end
    return q.point, q.rel or st(self).parent, q.relPoint, q.x, q.y
end
function Region:GetPointByName(name) return Region.GetPoint(self, name) end

function Region:SetSize(w, h)
    local s = st(self)
    s.width, s.height = num(w, 0), num(h, 0)
    touch()
end
function Region:SetWidth(w) st(self).width = num(w, 0) touch() end
function Region:SetHeight(h) st(self).height = num(h, 0) touch() end

-- Der Client meldet die aufgeloeste Groesse, wenn Anker sie bestimmen, sonst die gesetzte.
function Region:GetWidth()
    local s = st(self)
    local r = L.Rect(self)
    if r and (r.fixedW or not s.width) then return r[3] / L.EffectiveScale(self) end
    if s.width then return s.width end
    if s.measure then local w = s.measure(self) return w end
    return 0
end
function Region:GetHeight()
    local s = st(self)
    local r = L.Rect(self)
    if r and (r.fixedH or not s.height or s.measure) then return r[4] / L.EffectiveScale(self) end
    if s.height then return s.height end
    if s.measure then local _, h = s.measure(self) return h end
    return 0
end
function Region:GetSize() return Region.GetWidth(self), Region.GetHeight(self) end

local function edge(o, f)
    local r = L.Rect(o)
    if not r then return nil end
    return f(r) / L.EffectiveScale(o)
end
function Region:GetLeft() return edge(self, function(r) return r[1] end) end
function Region:GetRight() return edge(self, function(r) return r[1] + r[3] end) end
function Region:GetBottom() return edge(self, function(r) return r[2] end) end
function Region:GetTop() return edge(self, function(r) return r[2] + r[4] end) end
function Region:GetCenter()
    local r = L.Rect(self)
    if not r then return nil end
    local es = L.EffectiveScale(self)
    return (r[1] + r[3] / 2) / es, (r[2] + r[4] / 2) / es
end
function Region:GetRect()
    local r = L.Rect(self)
    if not r then return nil end
    local es = L.EffectiveScale(self)
    return r[1] / es, r[2] / es, r[3] / es, r[4] / es
end
function Region:GetScaledRect()
    local r = L.Rect(self)
    if not r then return nil end
    return r[1], r[2], r[3], r[4]
end
function Region:IsRectValid() return L.Rect(self) ~= nil end
function Region:IsAnchoringRestricted() return false end
function Region:IsAnchoringSecret() return false end
function Region:IsCollapsed() return false end
function Region:SetCollapsesLayout() end
function Region:GetSourceLocation() return nil end
function Region:IsDragging() return false end
function Region:EnableMouse(on) st(self).mouse = not not on end
function Region:IsMouseEnabled() return not not st(self).mouse end
function Region:EnableMouseMotion(on) st(self).mouseMotion = not not on end
function Region:IsMouseMotionEnabled() return not not st(self).mouseMotion end
function Region:SetMouseClickEnabled(on) st(self).mouseClick = not not on end
function Region:IsMouseClickEnabled() return not not st(self).mouseClick end
function Region:SetMouseMotionEnabled(on) st(self).mouseMotion = not not on end
function Region:SetPassThroughButtons() end
function Region:CanChangeProtectedState() return true end
function Region:SetPropagateMouseMotion() end
function Region:SetPropagateMouseClicks() end

-- Maus ueber dem Rechteck (Szenarien setzen die Zeigerposition).
function Region:IsMouseOver(top, bottom, left, right)
    local r = L.Rect(self)
    if not r or not W.cursor then return false end
    local cx, cy = W.cursor[1], W.cursor[2]
    local es = L.EffectiveScale(self)
    return cx >= r[1] - (left or 0) * es and cx <= r[1] + r[3] + (right or 0) * es
        and cy >= r[2] - (bottom or 0) * es and cy <= r[2] + r[4] + (top or 0) * es
end
function Region:IsMouseMotionFocus() return W.mouseFocus == self end

-- Sichtbarkeit; OnShow/OnHide nur fuer Rahmen, wenn sich IsVisible aendert.
local function visible(o)
    while o do
        local s = st(o)
        if not s.shown then return false end
        o = s.parent
    end
    return true
end
W.visible = visible

local function collectVisible(o, out)
    out[#out + 1] = o
    local s = st(o)
    if s.children then
        for _, c in ipairs(s.children) do
            if st(c).shown then collectVisible(c, out) end
        end
    end
end

local function setShown(o, show)
    local s = st(o)
    show = not not show
    if s.shown == show then return end
    local wasVisible = visible(o)
    s.shown = show
    touch()
    local isVisible = visible(o)
    if wasVisible ~= isVisible and s.isFrame then
        local list = {}
        collectVisible(o, list)
        local script = isVisible and "OnShow" or "OnHide"
        for _, f in ipairs(list) do W.Fire(f, script) end
    end
end
W.setShown = setShown
function Region:Show() setShown(self, true) end
function Region:Hide() setShown(self, false) end
function Region:SetShown(v) setShown(self, Sec.Unwrap(v)) end
function Region:IsShown() return st(self).shown end
function Region:IsVisible() return visible(self) end

-- Region: Alpha, Skalierung, Ebene, Farbe ---------------------------------------

local Reg = class("Region", "ScriptRegion")
function Reg:SetAlpha(a) st(self).alpha = math.max(0, math.min(1, num(a, 1))) end
function Reg:GetAlpha() return st(self).alpha end
function Reg:SetAlphaFromBoolean(v, a1, a0) st(self).alpha = Sec.Unwrap(v) and (a1 or 1) or (a0 or 0) end
function Reg:GetEffectiveAlpha()
    local a, o = 1, self
    while o do
        local s = st(o)
        a = a * (s.animAlpha or s.alpha)
        if s.ignoreParentAlpha then break end
        o = s.parent
    end
    return a
end
function Reg:SetIgnoreParentAlpha(v) st(self).ignoreParentAlpha = not not v end
function Reg:IsIgnoringParentAlpha() return not not st(self).ignoreParentAlpha end
function Reg:SetIgnoreParentScale(v) st(self).ignoreParentScale = not not v touch() end
function Reg:IsIgnoringParentScale() return not not st(self).ignoreParentScale end
function Reg:SetScale(v) st(self).scale = num(v, 1) touch() end
function Reg:GetScale() return st(self).scale or 1 end
function Reg:GetEffectiveScale() return L.EffectiveScale(self) end
function Reg:SetParent(p)
    local s = st(self)
    if type(p) == "string" then p = rawget(_G, p) end
    if s.parent == p then return end
    W.detach(self)
    s.parent = p
    W.attach(self)
    touch()
end
function Reg:SetDrawLayer(layer, sub)
    local s = st(self)
    if layer and W.LAYER_INDEX[layer] then s.layer = layer end
    if sub then s.sublevel = math.max(-8, math.min(7, num(sub, 0))) end
end
function Reg:GetDrawLayer() local s = st(self) return s.layer or "ARTWORK", s.sublevel or 0 end
function Reg:SetVertexColor(r, g, b, a)
    local s = st(self)
    s.vertex = { num(r, 1), num(g, 1), num(b, 1), num(a, 1) }
    s.gradient = nil
end
function Reg:GetVertexColor()
    local v = st(self).vertex or { 1, 1, 1, 1 }
    return v[1], v[2], v[3], v[4]
end
function Reg:SetVertexColorFromBoolean(v, c1, c0)
    local c = Sec.Unwrap(v) and c1 or c0
    if c then Reg.SetVertexColor(self, c:GetRGBA()) end
end
function Reg:IsVisible() return visible(self) end
function Reg:SetSnapToPixelGrid(v) st(self).snap = v end
function Reg:IsSnappingToPixelGrid() return st(self).snap ~= false end
function Reg:SetTexelSnappingBias() end
function Reg:GetTexelSnappingBias() return 0 end
function Reg:IsObjectLoaded() return true end

-- Textures -----------------------------------------------------------------------

local TexBase = class("TextureBase", "Region")

local function resetCoords(s) s.coords = nil end

function TexBase:SetTexture(path, wrapH, wrapV, filter)
    local s = st(self)
    path = Sec.Unwrap(path)
    s.color, s.atlas = nil, nil
    if path == nil or path == "" then
        s.texture, s.file = nil, nil
        return true
    end
    s.texture = path
    local e = Media.Texture(path)
    s.file = e and e.file or nil
    s.fileW, s.fileH = e and e.w, e and e.h
    s.wrapH, s.wrapV = wrapH, wrapV
    if not e then R.Note("Textur nicht gefunden: " .. tostring(path)) end
    return e ~= nil
end
function TexBase:GetTexture()
    local s = st(self)
    if s.atlas then return s.atlasInfo and s.atlasInfo.fdid end
    if type(s.texture) == "string" then
        local e = Media.Texture(s.texture)
        if e and e.fdid then return e.fdid end
    end
    return s.texture
end
function TexBase:GetTextureFileID()
    local t = TexBase.GetTexture(self)
    if type(t) == "number" then return t end
    return nil
end
function TexBase:GetTextureFilePath() return st(self).texture end
function TexBase:SetColorTexture(r, g, b, a)
    local s = st(self)
    s.texture, s.file, s.atlas = nil, nil, nil
    s.color = { num(r, 1), num(g, 1), num(b, 1), num(a, 1) }
    return true
end
function TexBase:SetAtlas(name, useAtlasSize, filter, resetTexCoords)
    local s = st(self)
    name = Sec.Unwrap(name)
    local a = Media.Atlas(name)
    s.color = nil
    if not a then
        R.Note("Atlas nicht gefunden: " .. tostring(name))
        s.atlas, s.atlasInfo, s.file, s.texture = nil, nil, nil, nil
        return false
    end
    s.atlas, s.atlasInfo = name, a
    s.texture = a.fdid
    s.file = a.abs
    s.coords = { a.left, a.top, a.left, a.bottom, a.right, a.top, a.right, a.bottom }
    s.wrapH = a.tilesH and "REPEAT" or nil
    s.wrapV = a.tilesV and "REPEAT" or nil
    s.horizTile, s.vertTile = a.tilesH, a.tilesV
    if useAtlasSize then
        s.width, s.height = a.width, a.height
        touch()
    end
    return true
end
function TexBase:GetAtlas() return st(self).atlas end
-- SetTexCoord(l, r, t, b) oder acht Werte (UL, LL, UR, LR).
function TexBase:SetTexCoord(...)
    local s = st(self)
    local n = select("#", ...)
    local v = { ... }
    for i = 1, n do v[i] = num(v[i], 0) end
    if n >= 8 then
        s.coords = { v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8] }
    else
        local l, r, t, b = v[1] or 0, v[2] or 1, v[3] or 0, v[4] or 1
        s.coords = { l, t, l, b, r, t, r, b }
    end
end
function TexBase:GetTexCoord()
    local c = st(self).coords or { 0, 0, 0, 1, 1, 0, 1, 1 }
    return c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8]
end
function TexBase:SetDesaturated(v) st(self).desat = Sec.Unwrap(v) and 1 or 0 end
function TexBase:IsDesaturated() return (st(self).desat or 0) > 0 end
function TexBase:SetDesaturation(v) st(self).desat = num(v, 0) end
function TexBase:GetDesaturation() return st(self).desat or 0 end
function TexBase:SetBlendMode(m) st(self).blend = m end
function TexBase:GetBlendMode() return st(self).blend or "BLEND" end
function TexBase:SetRotation(rad, center)
    local s = st(self)
    s.rotation = num(rad, 0)
    s.rotCenter = center and { center.x or 0.5, center.y or 0.5 } or nil
end
function TexBase:GetRotation() return st(self).rotation or 0 end
function TexBase:SetHorizTile(v) st(self).horizTile = not not v end
function TexBase:GetHorizTile() return not not st(self).horizTile end
function TexBase:SetVertTile(v) st(self).vertTile = not not v end
function TexBase:GetVertTile() return not not st(self).vertTile end
function TexBase:SetGradient(orientation, minColor, maxColor)
    local s = st(self)
    local function rgba(c)
        if type(c) == "table" and c.GetRGBA then return { c:GetRGBA() } end
        if type(c) == "table" then return { c.r or 1, c.g or 1, c.b or 1, c.a or 1 } end
        return { 1, 1, 1, 1 }
    end
    s.gradient = { orientation = orientation, min = rgba(minColor), max = rgba(maxColor) }
end
function TexBase:SetTextureSliceMargins(l, t, r, b) st(self).slice = { num(l, 0), num(t, 0), num(r, 0), num(b, 0) } end
function TexBase:SetTextureSliceMode(m) st(self).sliceMode = m end
function TexBase:GetTextureSliceMargins() local m = st(self).slice or { 0, 0, 0, 0 } return m[1], m[2], m[3], m[4] end
function TexBase:ClearTextureSlice() st(self).slice = nil end
function TexBase:IsBlockingLoadRequested() return false end
function TexBase:SetBlockingLoadsRequested() end
function TexBase:ResetTexCoord() resetCoords(st(self)) end
function TexBase:SetSpriteSheetCell() end

local Tex = class("Texture", "TextureBase")
function Tex:AddMaskTexture(mask)
    local s = st(self)
    s.masks = s.masks or {}
    for _, m in ipairs(s.masks) do if m == mask then return end end
    table.insert(s.masks, mask)
end
function Tex:RemoveMaskTexture(mask)
    local s = st(self)
    for i, m in ipairs(s.masks or {}) do if m == mask then table.remove(s.masks, i) return end end
end
function Tex:GetNumMaskTextures() return #(st(self).masks or {}) end
function Tex:GetMaskTexture(i) return (st(self).masks or {})[i] end
function Tex:SetMask(path)
    -- Alte Form: Maske direkt als Pfad.
    local s = st(self)
    s.maskPath = path
end

class("MaskTexture", "TextureBase")

local Line = class("Line", "TextureBase")
function Line:SetStartPoint(point, rel, x, y)
    st(self).startPt = { point = normPoint(point) or "CENTER", rel = resolveRel(rel), x = num(x, 0), y = num(y, 0) }
end
function Line:SetEndPoint(point, rel, x, y)
    st(self).endPt = { point = normPoint(point) or "CENTER", rel = resolveRel(rel), x = num(x, 0), y = num(y, 0) }
end
function Line:GetStartPoint() local p = st(self).startPt if p then return p.point, p.rel, p.x, p.y end end
function Line:GetEndPoint() local p = st(self).endPt if p then return p.point, p.rel, p.x, p.y end end
function Line:SetThickness(t) st(self).thickness = num(t, 1) end
function Line:GetThickness() return st(self).thickness or 1 end

-- Fonts (Schriftobjekte und FontStrings teilen die FontInstance-Methoden) ------

local FontInst = class("FontInstance", "Object")

-- Wert aus eigener Einstellung, sonst aus dem Schriftobjekt (rekursiv).
local function fontProp(o, key, seen)
    local s = st(o)
    if s[key] ~= nil then return s[key] end
    local fo = s.fontObject
    seen = seen or {}
    if fo and not seen[fo] then
        seen[fo] = true
        return fontProp(fo, key, seen)
    end
    return nil
end
W.fontProp = fontProp

local function fontChanged(o)
    local s = st(o)
    s.layoutKey = nil
    touch()
    -- Schriftobjekte reichen Aenderungen an ihre Nutzer weiter.
    if s.users then
        for u in pairs(s.users) do fontChanged(u) end
    end
end

function FontInst:SetFont(path, height, flags)
    local s = st(self)
    path = Sec.Unwrap(path)
    local file = Media.Font(path)
    if not file then
        R.Note("Schrift nicht gefunden: " .. tostring(path))
        return false
    end
    s.fontPath, s.fontFile, s.fontHeight, s.fontFlags = path, file, num(height, DEFAULT_FONT_HEIGHT), flags or ""
    fontChanged(self)
    return true
end
function FontInst:GetFont()
    return fontProp(self, "fontPath"), fontProp(self, "fontHeight"), fontProp(self, "fontFlags")
end
function FontInst:SetFontObject(fo)
    local s = st(self)
    if type(fo) == "string" then fo = rawget(_G, fo) end
    if s.fontObject and st(s.fontObject).users then st(s.fontObject).users[self] = nil end
    s.fontObject = fo
    -- Ein neues Schriftobjekt ersetzt die eigenen Schrift-Einstellungen.
    s.fontPath, s.fontFile, s.fontHeight, s.fontFlags = nil, nil, nil, nil
    s.textColor, s.shadowColor, s.shadowOffset, s.justifyH, s.justifyV, s.spacing = nil, nil, nil, nil, nil, nil
    if fo then
        local fs = st(fo)
        fs.users = fs.users or setmetatable({}, { __mode = "k" })
        fs.users[self] = true
    end
    fontChanged(self)
end
function FontInst:GetFontObject() return st(self).fontObject end
function FontInst:SetTextColor(r, g, b, a) st(self).textColor = { num(r, 1), num(g, 1), num(b, 1), num(a, 1) } fontChanged(self) end
function FontInst:GetTextColor()
    local c = fontProp(self, "textColor") or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end
function FontInst:SetShadowColor(r, g, b, a) st(self).shadowColor = { num(r, 0), num(g, 0), num(b, 0), num(a, 1) } end
function FontInst:GetShadowColor()
    local c = fontProp(self, "shadowColor") or { 0, 0, 0, 1 }
    return c[1], c[2], c[3], c[4]
end
function FontInst:SetShadowOffset(x, y) st(self).shadowOffset = { num(x, 0), num(y, 0) } end
function FontInst:GetShadowOffset()
    local o = fontProp(self, "shadowOffset") or { 0, 0 }
    return o[1], o[2]
end
function FontInst:SetJustifyH(j)
    j = type(j) == "string" and j:upper() or j
    if j ~= "LEFT" and j ~= "CENTER" and j ~= "RIGHT" then error("SetJustifyH: bad argument " .. tostring(j), 2) end
    st(self).justifyH = j
    fontChanged(self)
end
function FontInst:GetJustifyH() return fontProp(self, "justifyH") or "CENTER" end
function FontInst:SetJustifyV(j)
    j = type(j) == "string" and j:upper() or j
    if j ~= "TOP" and j ~= "MIDDLE" and j ~= "BOTTOM" then error("SetJustifyV: bad argument " .. tostring(j), 2) end
    st(self).justifyV = j
end
function FontInst:GetJustifyV() return fontProp(self, "justifyV") or "MIDDLE" end
function FontInst:SetSpacing(v) st(self).spacing = num(v, 0) fontChanged(self) end
function FontInst:GetSpacing() return fontProp(self, "spacing") or 0 end
function FontInst:SetIndentedWordWrap(v) st(self).indented = not not v end
function FontInst:GetIndentedWordWrap() return not not st(self).indented end
function FontInst:GetFontObjectForAlphabet() return self end
function FontInst:SetFontHeight(h)
    local s = st(self)
    s.fontPath = s.fontPath or fontProp(self, "fontPath")
    s.fontFile = s.fontFile or fontProp(self, "fontFile")
    s.fontFlags = s.fontFlags or fontProp(self, "fontFlags")
    s.fontHeight = num(h, DEFAULT_FONT_HEIGHT)
    fontChanged(self)
end
function FontInst:GetFontHeight() return fontProp(self, "fontHeight") end

local FontObj = class("Font", "FontInstance")
function FontObj:CopyFontObject(src)
    if type(src) == "string" then src = rawget(_G, src) end
    if not src then return end
    local s = st(self)
    for _, k in ipairs({ "fontPath", "fontFile", "fontHeight", "fontFlags", "textColor", "shadowColor", "shadowOffset", "justifyH", "justifyV", "spacing" }) do
        local v = fontProp(src, k)
        if type(v) == "table" then local c = {} for i, x in ipairs(v) do c[i] = x end v = c end
        s[k] = v
    end
    fontChanged(self)
end
function FontObj:GetAlpha() return 1 end
function FontObj:SetAlpha() end

-- FontString ---------------------------------------------------------------------

local FS = class("FontString", "Region")
for k, v in pairs(W.classes.FontInstance.methods) do FS[k] = v end

-- Satz des Texts fuer eine gegebene Breite (UI-Einheiten); zwischengespeichert.
function W.TextLayout(o, widthUnits)
    local s = st(o)
    local text = s.text
    if text == nil or text == "" then return nil end
    local file = fontProp(o, "fontFile")
    if not file then return nil end
    local height = fontProp(o, "fontHeight") or DEFAULT_FONT_HEIGHT
    local es = L.EffectiveScale(o) * (s.textScale or 1)
    local unitPx = es * L.PixelsPerUnit()
    local px = Font.PixelSize(height, unitPx)
    local maxW = widthUnits and widthUnits > 0 and widthUnits * unitPx or nil
    local maxH = nil
    if s.height and s.height > 0 then maxH = s.height * unitPx end
    local key = table.concat({ text, file, px, tostring(maxW), tostring(maxH), tostring(s.wordWrap), tostring(s.maxLines), tostring(fontProp(o, "spacing")), tostring(s.nonSpaceWrap) }, "\1")
    if s.layoutKey == key then return s.layoutCache end
    local c = fontProp(o, "textColor") or { 1, 1, 1, 1 }
    local tokens = Text.Parse(text, c)
    local lay = Text.Layout(tokens, {
        font = file, px = px, unitPx = unitPx, maxWidth = maxW, maxHeight = maxH,
        wordWrap = s.wordWrap ~= false, nonSpaceWrap = s.nonSpaceWrap,
        maxLines = s.maxLines, spacing = (fontProp(o, "spacing") or 0) * unitPx,
        lineHeight = height * unitPx,
    })
    lay.unitPx, lay.px, lay.file = unitPx, px, file
    s.layoutKey, s.layoutCache = key, lay
    return lay
end

local function measureFS(o, widthUnits)
    local s = st(o)
    if widthUnits == nil and s.width and s.width > 0 then widthUnits = s.width end
    local lay = W.TextLayout(o, widthUnits)
    if not lay then return 0, 0 end
    return lay.width / lay.unitPx, lay.height / lay.unitPx
end
W.measureFS = measureFS

function FS:SetText(t)
    local s = st(self)
    t = Sec.Unwrap(t)
    if t ~= nil then t = tostring(t) end
    if s.text == t then return end
    s.text = t
    s.layoutKey = nil
    touch()
end
function FS:SetFormattedText(fmt, ...) FS.SetText(self, Sec.Unwrap(Sec.Format(fmt, ...))) end
function FS:GetText() return st(self).text end
function FS:SetTextToFit(t) FS.SetText(self, t) end
function FS:GetStringWidth()
    local s = st(self)
    local lay = W.TextLayout(self, nil)
    if not lay then return 0 end
    return lay.width / lay.unitPx
end
function FS:GetUnboundedStringWidth() return FS.GetStringWidth(self) end
function FS:GetStringHeight()
    local w = Region.GetWidth(self)
    local lay = W.TextLayout(self, w > 0 and w or nil)
    if not lay then return 0 end
    return lay.height / lay.unitPx
end
function FS:GetWrappedWidth()
    local w = Region.GetWidth(self)
    local lay = W.TextLayout(self, w > 0 and w or nil)
    if not lay then return 0 end
    return lay.width / lay.unitPx
end
function FS:GetNumLines()
    local w = Region.GetWidth(self)
    local lay = W.TextLayout(self, w > 0 and w or nil)
    return lay and #lay.lines or 0
end
function FS:IsTruncated()
    local w = Region.GetWidth(self)
    local lay = W.TextLayout(self, w > 0 and w or nil)
    return lay and lay.truncated or false
end
function FS:SetWordWrap(v) st(self).wordWrap = not not v fontChanged(self) end
function FS:CanWordWrap() return st(self).wordWrap ~= false end
function FS:SetNonSpaceWrap(v) st(self).nonSpaceWrap = not not v fontChanged(self) end
function FS:CanNonSpaceWrap() return not not st(self).nonSpaceWrap end
function FS:SetMaxLines(n) st(self).maxLines = num(n, 0) fontChanged(self) end
function FS:GetMaxLines() return st(self).maxLines or 0 end
function FS:SetTextScale(v) st(self).textScale = num(v, 1) fontChanged(self) end
function FS:GetTextScale() return st(self).textScale or 1 end
function FS:SetTextHeight(h) FontInst.SetFontHeight(self, h) end
function FS:GetLineHeight() return fontProp(self, "fontHeight") or DEFAULT_FONT_HEIGHT end
function FS:SetFixedColor(v) st(self).fixedColor = not not v end
function FS:SetAlphaGradient() end
function FS:ClearText() FS.SetText(self, nil) end
function FS:FindCharacterIndexAtCoordinate() return 1 end
function FS:CalculateScreenAreaFromCharacterSpan() return nil end

-- Vom Rahmen aus erzeugte Regionen --------------------------------------------

function W.attach(o)
    local s = st(o)
    local p = s.parent
    if not p then
        if s.isFrame then W.roots[o] = true end
        return
    end
    W.roots[o] = nil
    local ps = st(p)
    if s.isFrame then
        ps.children = ps.children or {}
        table.insert(ps.children, o)
    else
        ps.regions = ps.regions or {}
        table.insert(ps.regions, o)
    end
end

function W.detach(o)
    local s = st(o)
    local p = s.parent
    if not p then W.roots[o] = nil return end
    local ps = st(p)
    local list = s.isFrame and ps.children or ps.regions
    if list then
        for i, c in ipairs(list) do if c == o then table.remove(list, i) break end end
    end
end

function W.CreateRegion(typeName, parent, name, layer, sublevel, template)
    local o, s = newObject(typeName, parent, name)
    s.layer = W.LAYER_INDEX[layer or ""] and layer or "ARTWORK"
    s.sublevel = num(sublevel, 0)
    if typeName == "FontString" then
        s.measure = measureFS
        s.wordWrap = true
    end
    W.attach(o)
    if template then W.ApplyTemplates(o, template) end
    return o
end

-- Wird von xml.lua gesetzt: wendet Vorlagen (Komma-Liste) an.
function W.ApplyTemplates(o, templates)
    if W.hooks.applyTemplates then return W.hooks.applyTemplates(o, templates) end
end

return W
