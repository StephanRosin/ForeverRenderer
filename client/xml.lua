-- XML-Lader fuer Blizzards und Addons' UI-Dateien: einfacher Parser plus
-- Aufbau von Frames, Regionen, Schriftobjekten und Vorlagen (virtual,
-- inherits, mixin, KeyValues, Layers, Frames, Scripts, Anchors).
local W = require("widgets")
local R = require("report")
local U = require("util")

local X = { templates = {}, intrinsics = {} }
local st = W.st

-- Parser ---------------------------------------------------------------------------

local ENTITIES = { lt = "<", gt = ">", amp = "&", quot = '"', apos = "'" }
local function unescape(s)
    return (s:gsub("&(#?x?%w+);", function(e)
        if ENTITIES[e] then return ENTITIES[e] end
        local hex = e:match("^#x(%x+)$")
        if hex then return string.char(tonumber(hex, 16) % 256) end
        local dec = e:match("^#(%d+)$")
        if dec then return string.char(tonumber(dec) % 256) end
        return "&" .. e .. ";"
    end))
end

function X.Parse(src)
    local root = { tag = "#root", attr = {}, children = {} }
    local stack = { root }
    local pos = 1
    local n = #src
    while pos <= n do
        local lt = src:find("<", pos, true)
        local top = stack[#stack]
        if not lt then break end
        if lt > pos then
            local text = src:sub(pos, lt - 1)
            if text:find("%S") then top.text = (top.text or "") .. unescape(text) end
        end
        if src:sub(lt, lt + 3) == "<!--" then
            local stop = src:find("-->", lt + 4, true)
            pos = (stop or n) + 3
        elseif src:sub(lt, lt + 8) == "<![CDATA[" then
            local stop = src:find("]]>", lt + 9, true)
            top.text = (top.text or "") .. src:sub(lt + 9, (stop or n) - 1)
            pos = (stop or n) + 3
        elseif src:sub(lt, lt + 1) == "<?" then
            local stop = src:find("?>", lt + 2, true)
            pos = (stop or n) + 2
        elseif src:sub(lt, lt + 1) == "</" then
            local stop = src:find(">", lt, true)
            if #stack > 1 then table.remove(stack) end
            pos = (stop or n) + 1
        else
            -- Start-Tag mit Attributen; Werte duerfen ">" enthalten.
            local i = lt + 1
            local tag = src:match("^[%w_:%-]+", i)
            i = i + #tag
            local node = { tag = tag, attr = {}, children = {}, parent = top }
            local selfClose = false
            while true do
                local ws = src:match("^%s*", i)
                i = i + #ws
                local c = src:sub(i, i)
                if c == ">" then i = i + 1 break end
                if src:sub(i, i + 1) == "/>" then selfClose = true i = i + 2 break end
                local name = src:match("^[%w_:%-]+", i)
                if not name then i = i + 1
                else
                    i = i + #name
                    local q = src:match("^%s*=%s*([\"'])", i)
                    if q then
                        local s0 = src:find(q, i, true)
                        local s1 = src:find(q, s0 + 1, true)
                        node.attr[name] = unescape(src:sub(s0 + 1, s1 - 1))
                        i = s1 + 1
                    else
                        node.attr[name] = "true"
                    end
                end
            end
            top.children[#top.children + 1] = node
            if not selfClose then stack[#stack + 1] = node end
            pos = i
        end
    end
    return root
end

-- Hilfen -----------------------------------------------------------------------------

local function bool(v) return v == "true" end
local function numAttr(v) return v and tonumber(v) end
local function child(node, tag)
    for _, c in ipairs(node.children) do if c.tag == tag then return c end end
end

local FRAME_TAGS = {
    Frame = "Frame", Button = "Button", CheckButton = "CheckButton", StatusBar = "StatusBar", Slider = "Slider",
    EditBox = "EditBox", ScrollFrame = "ScrollFrame", Cooldown = "Cooldown", GameTooltip = "GameTooltip",
    MessageFrame = "MessageFrame", ScrollingMessageFrame = "ScrollingMessageFrame", Model = "Model",
    PlayerModel = "PlayerModel", DressUpModel = "DressUpModel", CinematicModel = "CinematicModel",
    TabardModel = "TabardModel", ModelScene = "ModelScene", ColorSelect = "ColorSelect", SimpleHTML = "SimpleHTML",
    Browser = "Browser", Minimap = "Minimap", MovieFrame = "MovieFrame", EventFrame = "Frame", DropdownButton = "Button",
    ItemButton = "Button", ContainedAlertFrame = "Frame", UnitPositionFrame = "UnitPositionFrame", OffScreenFrame = "OffScreenFrame",
    FogOfWarFrame = "FogOfWarFrame", QuestPOIFrame = "QuestPOIFrame", ScenarioPOIFrame = "ScenarioPOIFrame", Checkout = "Checkout",
    ArchaeologyDigSiteFrame = "ArchaeologyDigSiteFrame", WorldFrame = "WorldFrame", EventButton = "Button", EventEditBox = "EditBox",
    EventScrollFrame = "ScrollFrame", EventCheckButton = "CheckButton", AuraContainer = "AuraContainer", PingPin = "PingPin",
    CheckBox = "CheckButton",
}
X.FRAME_TAGS = FRAME_TAGS
local REGION_TAGS = { Texture = "Texture", FontString = "FontString", Line = "Line", MaskTexture = "MaskTexture" }

-- Argumentlisten der Skripte wie im Client.
local SCRIPT_ARGS = {
    OnEvent = "self, event, ...", OnClick = "self, button, down", OnUpdate = "self, elapsed",
    OnAttributeChanged = "self, name, value", OnValueChanged = "self, value, userInput",
    OnEnter = "self, motion", OnLeave = "self, motion", OnMouseDown = "self, button", OnMouseUp = "self, button, upInside",
    OnSizeChanged = "self, width, height", OnMouseWheel = "self, delta", OnDragStart = "self, button",
    OnTextChanged = "self, userInput", OnChar = "self, text", OnKeyDown = "self, key", OnKeyUp = "self, key",
    PreClick = "self, button, down", PostClick = "self, button, down", OnVerticalScroll = "self, offset",
    OnHorizontalScroll = "self, offset", OnScrollRangeChanged = "self, xrange, yrange", OnTooltipSetDefaultAnchor = "self",
    OnMinMaxChanged = "self, min, max", OnHyperlinkClick = "self, link, text, button", OnHyperlinkEnter = "self, link, text",
    OnFinished = "self, requested", OnLoop = "self, loopState", OnEditFocusLost = "self", OnEditFocusGained = "self",
    OnEnterPressed = "self", OnEscapePressed = "self", OnTabPressed = "self", OnCooldownDone = "self",
}

local function compileScript(handler, body, srcName)
    local args = SCRIPT_ARGS[handler] or "self, ..."
    local chunk, err = loadstring("return function(" .. args .. ") " .. body .. "\nend", srcName)
    if not chunk then
        R.Error(err, "")
        return nil
    end
    setfenv(chunk, X.env)
    return chunk()
end

-- Kopiert eine Liste von Mixins wie Mixin() (spaeter auch aus Blizzards Code).
local function applyMixins(o, list)
    for name in list:gmatch("[^,%s]+") do
        local m = rawget(X.env, name)
        if type(m) == "table" then
            for k, v in pairs(m) do o[k] = v end
        else
            R.Note("Mixin fehlt: " .. name)
        end
    end
end

local function resolveRelative(o, a)
    local rel
    if a.relativeKey then
        local cur = o
        for part in a.relativeKey:gmatch("[^%.]+") do
            if part == "$parent" then cur = cur and cur:GetParent()
            elseif cur then cur = rawget(cur, part) end
        end
        rel = cur
    elseif a.relativeTo then
        local name = a.relativeTo
        if name:find("$parent", 1, true) then
            local p = st(o).parent
            name = name:gsub("%$parent", p and st(p).name or "")
        end
        rel = rawget(_G, name)
        if rel == nil then rel = "SCREEN" end
    end
    return rel
end

local function readSize(node)
    local x, y = numAttr(node.attr.x), numAttr(node.attr.y)
    local abs = child(node, "AbsDimension")
    if abs then x, y = numAttr(abs.attr.x) or x, numAttr(abs.attr.y) or y end
    return x, y
end

local function readColor(node)
    if not node then return nil end
    if node.attr.color then
        local c = rawget(_G, node.attr.color)
        if type(c) == "table" and c.GetRGBA then return { c:GetRGBA() } end
    end
    return { tonumber(node.attr.r) or 0, tonumber(node.attr.g) or 0, tonumber(node.attr.b) or 0, tonumber(node.attr.a) or 1 }
end

local function applyAnchors(o, node)
    for _, a in ipairs(node.children) do
        if a.tag == "Anchor" then
            local point = (a.attr.point or "TOPLEFT"):upper()
            local relPoint = (a.attr.relativePoint or point):upper()
            local x, y = numAttr(a.attr.x) or 0, numAttr(a.attr.y) or 0
            local off = child(a, "Offset")
            if off then local ox, oy = readSize(off) x, y = ox or x, oy or y end
            local rel = resolveRelative(o, a.attr)
            if rel == "SCREEN" then rel = nil end
            if rel == nil and (a.attr.relativeTo or a.attr.relativeKey) then
                R.Note("XML-Anker: Bezug fehlt " .. tostring(a.attr.relativeTo or a.attr.relativeKey))
            end
            local ok, err = pcall(o.SetPoint, o, point, rel or st(o).parent, relPoint, x, y)
            if not ok then R.Note("XML-Anker: " .. tostring(err)) end
        end
    end
end

-- Schrift-Attribute (Font-Element, FontString, ButtonText ...).
local function applyFontAttrs(o, node)
    local a = node.attr
    local s = st(o)
    -- font="GameFontNormal" nennt ein Schriftobjekt, keine Datei.
    local fo = a.font and rawget(_G, a.font)
    if type(fo) == "table" and rawget(fo, 0) and st(fo).isFont then
        if o.SetFontObject then o:SetFontObject(fo) else o:CopyFontObject(fo) end
    elseif a.font then
        local height = 12
        local fh = child(node, "FontHeight")
        if fh then
            local abs = child(fh, "AbsValue")
            height = numAttr(fh.attr.val) or (abs and numAttr(abs.attr.val)) or height
        end
        local flags = {}
        if a.outline == "NORMAL" then flags[#flags + 1] = "OUTLINE" elseif a.outline == "THICK" then flags[#flags + 1] = "THICKOUTLINE" end
        if bool(a.monochrome) then flags[#flags + 1] = "MONOCHROME" end
        o:SetFont(a.font, height, table.concat(flags, ","))
    else
        local fh = child(node, "FontHeight")
        if fh and o.SetFontHeight then
            local abs = child(fh, "AbsValue")
            local h = numAttr(fh.attr.val) or (abs and numAttr(abs.attr.val))
            if h then o:SetFontHeight(h) end
        end
    end
    if a.justifyH then pcall(o.SetJustifyH, o, a.justifyH) end
    if a.justifyV then pcall(o.SetJustifyV, o, a.justifyV) end
    if a.spacing then o:SetSpacing(tonumber(a.spacing)) end
    local color = child(node, "Color")
    if color then local c = readColor(color) o:SetTextColor(c[1], c[2], c[3], c[4]) end
    local shadow = child(node, "Shadow")
    if shadow then
        local c = readColor(child(shadow, "Color")) or { 0, 0, 0, 1 }
        o:SetShadowColor(c[1], c[2], c[3], c[4])
        local off = child(shadow, "Offset")
        if off then local x, y = readSize(off) o:SetShadowOffset(x or 0, y or 0) end
    end
end

-- Regionen ----------------------------------------------------------------------------

local applyNode

local function setParentKey(o, parent, a)
    if a.parentKey then
        rawset(parent, a.parentKey, o)
        st(o).parentKey = a.parentKey
    end
    if a.parentArray then
        local arr = rawget(parent, a.parentArray)
        if type(arr) ~= "table" then arr = {} rawset(parent, a.parentArray, arr) end
        table.insert(arr, o)
    end
end

local function buildRegion(node, parent, layer, sublevel)
    local typ = REGION_TAGS[node.tag]
    local a = node.attr
    local o = W.CreateRegion(typ, parent, a.name, layer, sublevel)
    setParentKey(o, parent, a)
    applyNode(o, node, true)
    return o
end

-- Wendet einen (Vorlagen-)Knoten auf ein Objekt an. own=true: der Knoten
-- beschreibt das Objekt selbst (nicht nur eine Vorlage), dann zaehlt auch hidden.
function applyNode(o, node, own)
    local a = node.attr
    local s = st(o)
    if a.inherits then
        for t in a.inherits:gmatch("[^,%s]+") do X.ApplyTemplate(o, t) end
    end
    if a.mixin then applyMixins(o, a.mixin) end
    if a.secureMixin then applyMixins(o, a.secureMixin) end
    local isRegion = not s.isFrame and (s.type == "Texture" or s.type == "FontString" or s.type == "Line" or s.type == "MaskTexture")

    if bool(a.hidden) then o:Hide() elseif a.hidden == "false" then o:Show() end
    if a.alpha and o.SetAlpha then o:SetAlpha(tonumber(a.alpha)) end
    if a.scale and o.SetScale then o:SetScale(tonumber(a.scale)) end
    if bool(a.setAllPoints) then o:SetAllPoints() end
    if bool(a.ignoreParentAlpha) and o.SetIgnoreParentAlpha then o:SetIgnoreParentAlpha(true) end
    if bool(a.ignoreParentScale) and o.SetIgnoreParentScale then o:SetIgnoreParentScale(true) end
    if s.isFrame then
        if a.frameStrata then o:SetFrameStrata(a.frameStrata) end
        if a.frameLevel then o:SetFrameLevel(tonumber(a.frameLevel)) end
        if bool(a.toplevel) then o:SetToplevel(true) end
        if bool(a.enableMouse) then o:EnableMouse(true) end
        if bool(a.movable) then o:SetMovable(true) end
        if bool(a.resizable) then o:SetResizable(true) end
        if bool(a.clipChildren) then o:SetClipsChildren(true) end
        if bool(a.clampedToScreen) then o:SetClampedToScreen(true) end
        if bool(a.flattenRenderLayers) then o:SetFlattensRenderLayers(true) end
        if bool(a.useParentLevel) then s.usingParentLevel = true end
        if bool(a.fixedFrameStrata) then s.fixedStrata = true end
        if bool(a.fixedFrameLevel) then s.fixedLevel = true end
        if a.id then o:SetID(tonumber(a.id)) end
        if a.registerForClicks and o.RegisterForClicks then o:RegisterForClicks(a.registerForClicks) end
        if a.text and o.SetText then o:SetText(rawget(_G, a.text) or a.text) end
        if bool(a.checked) and o.SetChecked then o:SetChecked(true) end
        if a.minValue and o.SetMinMaxValues then o:SetMinMaxValues(tonumber(a.minValue), tonumber(a.maxValue) or 1) end
        if a.defaultValue and o.SetValue then o:SetValue(tonumber(a.defaultValue)) end
        if a.valueStep and o.SetValueStep then o:SetValueStep(tonumber(a.valueStep)) end
        if a.orientation and o.SetOrientation then o:SetOrientation(a.orientation) end
        if bool(a.reverseFill) and o.SetReverseFill then o:SetReverseFill(true) end
        if a.letters and o.SetMaxLetters then o:SetMaxLetters(tonumber(a.letters)) end
        if a.autoFocus and o.SetAutoFocus then o:SetAutoFocus(bool(a.autoFocus)) end
        if bool(a.multiLine) and o.SetMultiLine then o:SetMultiLine(true) end
        if bool(a.numeric) and o.SetNumeric then o:SetNumeric(true) end
        if a.drawSwipe and o.SetDrawSwipe then o:SetDrawSwipe(bool(a.drawSwipe)) end
        if a.drawEdge and o.SetDrawEdge then o:SetDrawEdge(bool(a.drawEdge)) end
        if a.drawBling and o.SetDrawBling then o:SetDrawBling(bool(a.drawBling)) end
        if a.reverse and o.SetReverse then o:SetReverse(bool(a.reverse)) end
        if a.hideCountdownNumbers and o.SetHideCountdownNumbers then o:SetHideCountdownNumbers(bool(a.hideCountdownNumbers)) end
    end
    if s.type == "Texture" or s.type == "MaskTexture" or s.type == "Line" then
        if a.file then o:SetTexture(a.file, a.horizTile == "true" and "REPEAT" or nil, a.vertTile == "true" and "REPEAT" or nil) end
        if a.atlas then o:SetAtlas(a.atlas, bool(a.useAtlasSize)) end
        if a.alphaMode then o:SetBlendMode(a.alphaMode) end
        if bool(a.horizTile) then o:SetHorizTile(true) end
        if bool(a.vertTile) then o:SetVertTile(true) end
        if bool(a.desaturated) then o:SetDesaturated(true) end
        if a.snapToPixelGrid then o:SetSnapToPixelGrid(bool(a.snapToPixelGrid)) end
        if a.thickness and o.SetThickness then o:SetThickness(tonumber(a.thickness)) end
        if a.rotation then o:SetRotation(math.rad(tonumber(a.rotation))) end
    end
    if s.type == "FontString" or s.type == "Font" then
        if a.inherits == nil and a.font == nil and s.type == "FontString" and a.fontObject then o:SetFontObject(a.fontObject) end
        applyFontAttrs(o, node)
        if s.type == "FontString" then
            if a.text then o:SetText(rawget(_G, a.text) or a.text) end
            if a.wordwrap then o:SetWordWrap(bool(a.wordwrap)) end
            if a.nonspacewrap then o:SetNonSpaceWrap(bool(a.nonspacewrap)) end
            if a.maxLines then o:SetMaxLines(tonumber(a.maxLines)) end
        end
    end

    for _, c in ipairs(node.children) do
        local tag = c.tag
        if tag == "Size" then
            local x, y = readSize(c)
            if x then o:SetWidth(x) end
            if y then o:SetHeight(y) end
        elseif tag == "Anchors" then
            applyAnchors(o, c)
        elseif tag == "KeyValues" then
            for _, kv in ipairs(c.children) do
                if kv.tag == "KeyValue" then
                    local v = kv.attr.value
                    local t = kv.attr.type or "string"
                    if t == "number" then v = tonumber(v)
                    elseif t == "boolean" then v = v == "true"
                    elseif t == "global" then v = rawget(_G, v) end
                    local key = kv.attr.keyType == "number" and tonumber(kv.attr.key) or kv.attr.key
                    rawset(o, key, v)
                end
            end
        elseif tag == "Attributes" and s.isFrame then
            for _, at in ipairs(c.children) do
                if at.tag == "Attribute" then
                    local v = at.attr.value
                    if at.attr.type == "number" then v = tonumber(v) elseif at.attr.type == "boolean" then v = v == "true" end
                    o:SetAttribute(at.attr.name, v)
                end
            end
        elseif tag == "Layers" and s.isFrame then
            for _, layer in ipairs(c.children) do
                if layer.tag == "Layer" then
                    local level = layer.attr.level or "ARTWORK"
                    local sub = tonumber(layer.attr.textureSubLevel) or 0
                    for _, r in ipairs(layer.children) do
                        if REGION_TAGS[r.tag] then buildRegion(r, o, level, sub) end
                    end
                end
            end
        elseif tag == "ScrollChild" and s.type == "ScrollFrame" then
            for _, f in ipairs(c.children) do
                if FRAME_TAGS[f.tag] or X.intrinsics[f.tag] then o:SetScrollChild(X.BuildFrame(f, o)) end
            end
        elseif tag == "Frames" and s.isFrame then
            for _, f in ipairs(c.children) do
                if FRAME_TAGS[f.tag] or X.intrinsics[f.tag] then X.BuildFrame(f, o) end
            end
        elseif tag == "Scripts" then
            X.ApplyScripts(o, c)
        elseif tag == "Animations" then
            for _, g in ipairs(c.children) do
                if g.tag == "AnimationGroup" then X.BuildAnimGroup(g, o) end
            end
        elseif tag == "TexCoords" and o.SetTexCoord then
            local ta = c.attr
            if ta.ULx then
                o:SetTexCoord(tonumber(ta.ULx), tonumber(ta.ULy), tonumber(ta.LLx), tonumber(ta.LLy), tonumber(ta.URx), tonumber(ta.URy), tonumber(ta.LRx), tonumber(ta.LRy))
            else
                o:SetTexCoord(tonumber(ta.left) or 0, tonumber(ta.right) or 1, tonumber(ta.top) or 0, tonumber(ta.bottom) or 1)
            end
        elseif tag == "Color" and (s.type == "Texture" or s.type == "Line") then
            local col = readColor(c)
            o:SetColorTexture(col[1], col[2], col[3], col[4])
        elseif tag == "Gradient" and o.SetGradient then
            local mn, mx = child(c, "MinColor"), child(c, "MaxColor")
            local cMin, cMax = readColor(mn) or { 1, 1, 1, 1 }, readColor(mx) or { 1, 1, 1, 1 }
            o:SetGradient(c.attr.orientation or "HORIZONTAL", { r = cMin[1], g = cMin[2], b = cMin[3], a = cMin[4] }, { r = cMax[1], g = cMax[2], b = cMax[3], a = cMax[4] })
        elseif tag == "HitRectInsets" and o.SetHitRectInsets then
            local abs = child(c, "AbsInset") or c
            o:SetHitRectInsets(tonumber(abs.attr.left) or 0, tonumber(abs.attr.right) or 0, tonumber(abs.attr.top) or 0, tonumber(abs.attr.bottom) or 0)
        elseif tag == "TextInsets" and o.SetTextInsets then
            local abs = child(c, "AbsInset") or c
            o:SetTextInsets(tonumber(abs.attr.left) or 0, tonumber(abs.attr.right) or 0, tonumber(abs.attr.top) or 0, tonumber(abs.attr.bottom) or 0)
        elseif (tag == "NormalTexture" or tag == "PushedTexture" or tag == "DisabledTexture" or tag == "HighlightTexture"
                or tag == "CheckedTexture" or tag == "DisabledCheckedTexture" or tag == "ThumbTexture" or tag == "BarTexture") and s.isFrame then
            X.BuildStateTexture(o, tag, c)
        elseif (tag == "NormalFont" or tag == "HighlightFont" or tag == "DisabledFont") and s.isFrame then
            local fo = rawget(_G, c.attr.style or "")
            local setter = o["Set" .. tag .. "Object"]
            if fo and setter then setter(o, fo) end
        elseif tag == "ButtonText" and s.isFrame and o.SetFontString then
            local fs = W.CreateRegion("FontString", o, c.attr.name, "OVERLAY", 0)
            setParentKey(fs, o, c.attr)
            o:SetFontString(fs)
            if #c.children == 0 or not child(c, "Anchors") then fs:SetPoint("CENTER") end
            applyNode(fs, c, true)
        elseif tag == "FontString" and s.type == "EditBox" then
            applyNode(W.EditText(o), c, true)
        elseif tag == "BarColor" and o.SetStatusBarColor then
            local col = readColor(c)
            o:SetStatusBarColor(col[1], col[2], col[3], col[4])
        elseif tag == "SwipeTexture" and o.SetSwipeTexture then
            o:SetSwipeTexture(c.attr.file)
        end
    end
end
X.applyNode = applyNode

local STATE_SETTER = {
    NormalTexture = "SetNormalTexture", PushedTexture = "SetPushedTexture", DisabledTexture = "SetDisabledTexture",
    HighlightTexture = "SetHighlightTexture", CheckedTexture = "SetCheckedTexture",
    DisabledCheckedTexture = "SetDisabledCheckedTexture", ThumbTexture = "SetThumbTexture", BarTexture = "SetStatusBarTexture",
}
local STATE_LAYER = { HighlightTexture = "HIGHLIGHT", CheckedTexture = "OVERLAY", DisabledCheckedTexture = "OVERLAY", ThumbTexture = "OVERLAY", BarTexture = "ARTWORK" }

function X.BuildStateTexture(o, tag, node)
    local setter = o[STATE_SETTER[tag]]
    if not setter then return end
    local t = W.CreateRegion("Texture", o, node.attr.name, STATE_LAYER[tag] or "ARTWORK", 0)
    setParentKey(t, o, node.attr)
    if not child(node, "Anchors") and not node.attr.setAllPoints then t:SetAllPoints(o) end
    applyNode(t, node, true)
    if tag == "HighlightTexture" and not node.attr.alphaMode then t:SetBlendMode("ADD") end
    setter(o, t)
end

function X.ApplyScripts(o, node)
    for _, sc in ipairs(node.children) do
        local handler = sc.tag
        local fn
        if sc.attr["function"] then
            local name = sc.attr["function"]
            fn = function(self, ...)
                local f = rawget(X.env, name)
                if type(f) ~= "function" then error("Script function missing: " .. name) end
                return f(self, ...)
            end
        elseif sc.attr.method then
            local m = sc.attr.method
            fn = function(self, ...)
                local f = self[m]
                if type(f) ~= "function" then error(("Script method %s missing on %s"):format(m, tostring(self:GetDebugName()))) end
                return f(self, ...)
            end
        elseif sc.text and sc.text:find("%S") then
            fn = compileScript(handler, sc.text, "=" .. (st(o).name or "xml") .. ":" .. handler)
        end
        if fn then
            local old = o:GetScript(handler)
            local mode = sc.attr.inherit
            if old and mode == "prepend" then
                local new = fn
                fn = function(...) new(...) return old(...) end
            elseif old and mode == "append" then
                local new = fn
                fn = function(...) old(...) return new(...) end
            end
            o:SetScript(handler, fn)
        end
    end
end

function X.BuildAnimGroup(node, owner)
    local g = W.CreateAnimationGroup(owner, node.attr.name)
    setParentKey(g, owner, node.attr)
    if node.attr.inherits then
        for t in node.attr.inherits:gmatch("[^,%s]+") do X.ApplyTemplate(g, t) end
    end
    X.ApplyAnimGroupNode(g, node)
    return g
end

function X.ApplyAnimGroupNode(g, node)
    if node.attr.looping then g:SetLooping(node.attr.looping) end
    if bool(node.attr.setToFinalAlpha) then g:SetToFinalAlpha(true) end
    if node.attr.mixin then applyMixins(g, node.attr.mixin) end
    for _, c in ipairs(node.children) do
        if c.tag == "Scripts" then X.ApplyScripts(g, c)
        elseif c.tag == "KeyValues" then applyNode(g, { attr = {}, children = { c } })
        elseif W.classes[c.tag] or c.tag == "Animation" then
            local a = g:CreateAnimation(c.tag, c.attr.name)
            setParentKey(a, g, c.attr)
            local at = c.attr
            if at.duration then a:SetDuration(tonumber(at.duration)) end
            if at.startDelay then a:SetStartDelay(tonumber(at.startDelay)) end
            if at.order then a:SetOrder(tonumber(at.order)) end
            if at.fromAlpha then a:SetFromAlpha(tonumber(at.fromAlpha)) end
            if at.toAlpha then a:SetToAlpha(tonumber(at.toAlpha)) end
            if at.offsetX or at.offsetY then a:SetOffset(tonumber(at.offsetX) or 0, tonumber(at.offsetY) or 0) end
            if at.scaleX or at.scaleY then a:SetScaleTo(tonumber(at.scaleX) or 1, tonumber(at.scaleY) or 1) end
            if at.fromScaleX then a:SetScaleFrom(tonumber(at.fromScaleX) or 1, tonumber(at.fromScaleY) or 1) end
            if at.toScaleX then a:SetScaleTo(tonumber(at.toScaleX) or 1, tonumber(at.toScaleY) or 1) end
            if at.degrees then a:SetDegrees(tonumber(at.degrees)) end
            if at.childKey then a:SetChildKey(at.childKey) end
            if at.targetKey then a:SetTargetKey(at.targetKey) end
            if at.smoothing then a:SetSmoothing(at.smoothing) end
            for _, sc in ipairs(c.children) do if sc.tag == "Scripts" then X.ApplyScripts(a, sc) end end
        end
    end
end

-- Frames ------------------------------------------------------------------------------

function X.ApplyTemplate(o, name)
    local t = X.templates[name]
    -- FontStrings erben Schriftobjekte (inherits="GameFontNormal").
    if not t and st(o).type == "FontString" then
        local fo = rawget(_G, name)
        if type(fo) == "table" and rawget(fo, 0) and st(fo).isFont then
            o:SetFontObject(fo)
            return true
        end
    end
    if not t then
        R.Missing("template", name)
        return false
    end
    if st(o).type == "AnimationGroup" then
        X.ApplyAnimGroupNode(o, t.node)
        return true
    end
    applyNode(o, t.node, false)
    return true
end

-- CreateFrame-Vorlagen: alle anwenden, dann OnLoad einmal (wie der Client).
W.hooks.applyTemplates = function(o, list, intrinsicOnly)
    for name in tostring(list):gmatch("[^,%s]+") do X.ApplyTemplate(o, name) end
    if st(o).isFrame and not intrinsicOnly then W.Fire(o, "OnLoad") end
end
W.hooks.intrinsic = function(typeName)
    local t = X.intrinsics[typeName]
    if t then return { baseType = FRAME_TAGS[t.node.tag] or "Frame" } end
end

function X.BuildFrame(node, parent)
    local a = node.attr
    local typ = FRAME_TAGS[node.tag]
    if a.parent then parent = rawget(_G, a.parent) or parent end
    local name = a.name
    local intr = X.intrinsics[node.tag]
    if intr then typ = FRAME_TAGS[intr.node.tag] or "Frame" end
    local CreateFrame = require("frames").CreateFrame
    local o = CreateFrame(typ, name, parent)
    if intr then X.ApplyTemplate(o, node.tag) end
    setParentKey(o, parent, a)
    applyNode(o, node, true)
    W.Fire(o, "OnLoad")
    if st(o).shown and W.visible(o) then W.Fire(o, "OnShow") end
    return o
end

function X.BuildFont(node)
    local a = node.attr
    local fo = X.CreateFont(a.name)
    if a.inherits then
        local base = rawget(_G, a.inherits)
        if base then fo:CopyFontObject(base) end
    end
    applyFontAttrs(fo, node)
    return fo
end

-- Laedt eine XML-Datei; Script/Include relativ zum Ordner der Datei.
-- loadLua(pfad) laedt Lua-Dateien im richtigen Kontext (Addon-Namespace).
function X.LoadFile(path, loadLua)
    local src = U.readFile(path)
    if not src then
        R.Note("XML-Datei fehlt: " .. path)
        return
    end
    local dir = path:match("^(.*)/[^/]+$") or "."
    local root = X.Parse(src)
    for _, ui in ipairs(root.children) do
        if ui.tag == "Ui" then
            for _, node in ipairs(ui.children) do
                X.LoadNode(node, dir, loadLua)
            end
        end
    end
end

local function realPath(dir, file)
    file = file:gsub("\\", "/")
    local M = require("media")
    return dir .. "/" .. M.CaseInsensitive(dir, file)
end

function X.LoadNode(node, dir, loadLua)
    local a = node.attr
    local tag = node.tag
    if tag == "Script" then
        if a.file then loadLua(realPath(dir, a.file))
        elseif node.text then
            local chunk, err = loadstring(node.text, "=" .. dir .. "/<Script>")
            if chunk then setfenv(chunk, X.env) R.Call(chunk) else R.Error(err) end
        end
    elseif tag == "Include" then
        local p = realPath(dir, a.file)
        if p:match("%.lua$") then loadLua(p) else X.LoadFile(p, loadLua) end
    elseif tag == "Font" then
        if bool(a.virtual) or a.name then R.Call(X.BuildFont, node) end
    elseif tag == "FontFamily" then
        local fo = X.CreateFont(a.name)
        for _, m in ipairs(node.children) do
            if m.tag == "Member" and (m.attr.alphabet == "roman") then
                local f = child(m, "Font")
                if f then applyFontAttrs(fo, f) end
            end
        end
    elseif FRAME_TAGS[tag] or REGION_TAGS[tag] or tag == "AnimationGroup" or X.intrinsics[tag] then
        if bool(a.virtual) or bool(a.intrinsic) then
            if a.name then
                X.templates[a.name] = { node = node, dir = dir }
                if bool(a.intrinsic) then X.intrinsics[a.name] = X.templates[a.name] end
            end
        elseif FRAME_TAGS[tag] or X.intrinsics[tag] then
            R.Call(X.BuildFrame, node, a.parent and rawget(_G, a.parent) or nil)
        end
    end
end

return X
