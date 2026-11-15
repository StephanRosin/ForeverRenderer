-- Rahmen-Typen: Frame, Button, CheckButton, StatusBar, Slider, EditBox,
-- ScrollFrame, Cooldown, GameTooltip, MessageFrame, Model, Minimap ...
-- und CreateFrame selbst.
local W = require("widgets")
local L = require("layout")
local R = require("report")
local Sec = require("secret")

local F = {}
local st = W.st
local class = W.class

local function num(v, d)
    v = Sec.Unwrap(v)
    if v == nil then return d end
    return tonumber(v) or d
end

local function touch() L.Touch() end

-- Frame ----------------------------------------------------------------------------

local Frame = class("Frame", "Region")

function Frame:CreateTexture(name, layer, template, sub)
    return W.CreateRegion("Texture", self, name, layer, sub, template)
end
function Frame:CreateMaskTexture(name, layer, template, sub)
    return W.CreateRegion("MaskTexture", self, name, layer, sub, template)
end
function Frame:CreateLine(name, layer, template, sub)
    return W.CreateRegion("Line", self, name, layer, sub, template)
end
function Frame:CreateFontString(name, layer, template)
    local fs = W.CreateRegion("FontString", self, name, layer or "ARTWORK", 0, nil)
    if template then
        local fo = type(template) == "string" and rawget(_G, template) or template
        if type(fo) == "table" and rawget(fo, 0) and st(fo).type == "Font" then
            fs:SetFontObject(fo)
        else
            W.ApplyTemplates(fs, template)
        end
    end
    return fs
end
function Frame:GetChildren()
    return unpack(st(self).children or {})
end
function Frame:GetNumChildren() return #(st(self).children or {}) end
function Frame:GetRegions() return unpack(st(self).regions or {}) end
function Frame:GetNumRegions() return #(st(self).regions or {}) end
function Frame:GetAdditionalRegions() return end

-- Ebene: Schicht (Strata) und Stufe (Level).
local function eachDescendant(o, fn)
    for _, c in ipairs(st(o).children or {}) do
        fn(c)
        eachDescendant(c, fn)
    end
end
function Frame:SetFrameStrata(strata)
    if not W.STRATA_INDEX[strata] then return end
    local s = st(self)
    s.strata = strata
    eachDescendant(self, function(c)
        if not st(c).fixedStrata then st(c).strata = strata end
    end)
end
function Frame:GetFrameStrata() return st(self).strata or "MEDIUM" end
function Frame:SetFixedFrameStrata(v) st(self).fixedStrata = not not v end
function Frame:HasFixedFrameStrata() return not not st(self).fixedStrata end
function Frame:SetFrameLevel(level)
    local s = st(self)
    level = math.max(0, math.min(10000, math.floor(num(level, 0))))
    local delta = level - (s.level or 0)
    s.level = level
    -- Kinder behalten ihren Abstand zum Elternrahmen.
    eachDescendant(self, function(c)
        local cs = st(c)
        if not cs.fixedLevel then cs.level = math.max(0, (cs.level or 0) + delta) end
    end)
end
function Frame:GetFrameLevel() return st(self).level or 0 end
function Frame:SetFixedFrameLevel(v) st(self).fixedLevel = not not v end
function Frame:HasFixedFrameLevel() return not not st(self).fixedLevel end
function Frame:Raise()
    local s = st(self)
    local top = s.level or 0
    for _, o in ipairs(W.all) do
        local os = st(o)
        if os.isFrame and os.strata == s.strata and (os.level or 0) > top then top = os.level end
    end
    if top > (s.level or 0) then Frame.SetFrameLevel(self, math.min(top + 1, 10000)) end
end
function Frame:Lower() end
function Frame:SetToplevel(v) st(self).toplevel = not not v end
function Frame:IsToplevel() return not not st(self).toplevel end
function Frame:SetFrameBuffer() end
function Frame:SetIsFrameBuffer() end
function Frame:SetFlattensRenderLayers(v) st(self).flattens = not not v end
function Frame:GetFlattensRenderLayers() return not not st(self).flattens end
function Frame:SetDrawLayerEnabled(layer, on)
    local s = st(self)
    s.disabledLayers = s.disabledLayers or {}
    s.disabledLayers[layer] = not on or nil
end
function Frame:IsDrawLayerEnabled(layer) return not (st(self).disabledLayers or {})[layer] end
function Frame:SetClipsChildren(v) st(self).clips = not not v end
function Frame:DoesClipChildren() return not not st(self).clips end

-- Ereignisse (Pruefung gegen die Doku wie im Client).
function Frame:RegisterEvent(ev)
    if not W.validEvent(ev) then error(("Attempt to register unknown event \"%s\""):format(tostring(ev)), 2) end
    local s = st(self)
    s.events = s.events or {}
    if s.events[ev] then return true end
    s.events[ev] = true
    W.eventList(ev)[#W.eventList(ev) + 1] = self
    return true
end
function Frame:RegisterUnitEvent(ev, u1, u2)
    Frame.RegisterEvent(self, ev)
    local s = st(self)
    s.unitFilter = s.unitFilter or {}
    s.unitFilter[ev] = { u1, u2 }
    return true
end
function Frame:UnregisterEvent(ev)
    local s = st(self)
    if not (s.events and s.events[ev]) then return end
    s.events[ev] = nil
    if s.unitFilter then s.unitFilter[ev] = nil end
    local list = W.eventList(ev)
    for i, f in ipairs(list) do if f == self then table.remove(list, i) break end end
end
function Frame:UnregisterAllEvents()
    local s = st(self)
    for ev in pairs(s.events or {}) do Frame.UnregisterEvent(self, ev) end
end
function Frame:IsEventRegistered(ev)
    local s = st(self)
    return s.events and s.events[ev] or false
end
function Frame:RegisterAllEvents() end

-- Attribute (sichere Vorlagen leben davon).
function Frame:SetAttribute(name, value)
    local s = st(self)
    s.attributes = s.attributes or {}
    s.attributes[name] = value
    W.Fire(self, "OnAttributeChanged", name, value)
end
function Frame:SetAttributeNoHandler(name, value)
    local s = st(self)
    s.attributes = s.attributes or {}
    s.attributes[name] = value
end
function Frame:GetAttribute(name, ...)
    local a = st(self).attributes
    if not a then return nil end
    if select("#", ...) > 0 then
        -- GetAttribute(prefix, name, suffix): sucht wie SecureButton_GetModifiedAttribute.
        local prefix, suffix = name, select(2, ...)
        name = select(1, ...)
        return a[(prefix or "") .. name .. (suffix or "")] or a["*" .. name .. (suffix or "")] or a[name]
    end
    local v = a[name]
    if v == nil and type(name) == "string" then
        v = a["*" .. name]
    end
    return v
end
function Frame:ExecuteAttribute(name, ...)
    local fn = Frame.GetAttribute(self, name)
    if type(fn) == "function" then return fn(self, ...) end
end
function Frame:ClearAttribute(name) local a = st(self).attributes if a then a[name] = nil end end
function Frame:ClearAttributes() st(self).attributes = {} end
function Frame:CanChangeAttribute() return true end

function Frame:SetID(id) st(self).id = num(id, 0) end
function Frame:GetID() return st(self).id or 0 end
function Frame:SetMovable(v) st(self).movable = not not v end
function Frame:IsMovable() return not not st(self).movable end
function Frame:SetResizable(v) st(self).resizable = not not v end
function Frame:IsResizable() return not not st(self).resizable end
function Frame:SetUserPlaced(v) st(self).userPlaced = not not v end
function Frame:IsUserPlaced() return not not st(self).userPlaced end
function Frame:SetDontSavePosition() end
function Frame:GetDontSavePosition() return false end
function Frame:SetClampedToScreen(v) st(self).clamped = not not v end
function Frame:IsClampedToScreen() return not not st(self).clamped end
function Frame:SetClampRectInsets() end
function Frame:GetClampRectInsets() return 0, 0, 0, 0 end
function Frame:SetHitRectInsets(l, r, t, b) st(self).hitInsets = { l, r, t, b } end
function Frame:GetHitRectInsets() local h = st(self).hitInsets or { 0, 0, 0, 0 } return h[1], h[2], h[3], h[4] end
function Frame:SetResizeBounds(a, b, c, d) st(self).resizeBounds = { a, b, c, d } end
function Frame:GetResizeBounds() local r = st(self).resizeBounds or { 0, 0, 0, 0 } return r[1], r[2], r[3], r[4] end
function Frame:SetMinResize() end
function Frame:SetMaxResize() end
function Frame:StartMoving() end
function Frame:StartSizing() end
function Frame:StopMovingOrSizing() end
function Frame:RegisterForDrag() end
function Frame:EnableKeyboard(v) st(self).keyboard = not not v end
function Frame:IsKeyboardEnabled() return not not st(self).keyboard end
function Frame:SetPropagateKeyboardInput() end
function Frame:GetPropagateKeyboardInput() return false end
function Frame:EnableGamePadButton() end
function Frame:EnableGamePadStick() end
function Frame:SetHyperlinksEnabled() end
function Frame:GetHyperlinksEnabled() return false end
function Frame:EnableMouseWheel(v) st(self).wheel = not not v end
function Frame:IsMouseWheelEnabled() return not not st(self).wheel end
function Frame:SetWindow() end
function Frame:LockHighlight() st(self).lockHighlight = true end
function Frame:UnlockHighlight() st(self).lockHighlight = nil end
function Frame:GetBoundsRect() return Frame.GetRect(self) end
function Frame:SetHighlightLocked(v) st(self).lockHighlight = v or nil end
function Frame:IgnoreDepth() end
function Frame:SetDepth() end
function Frame:GetDepth() return 0 end
function Frame:SetUsingParentLevel(v) st(self).usingParentLevel = not not v end
function Frame:IsUsingParentLevel() return not not st(self).usingParentLevel end
function Frame:SetShadowColor() end
function Frame:DesaturateHierarchy(v)
    local function walk(o)
        for _, r in ipairs(st(o).regions or {}) do
            if r.SetDesaturation then r:SetDesaturation(v) end
        end
        for _, c in ipairs(st(o).children or {}) do walk(c) end
    end
    walk(self)
end
function Frame:RegisterForClicks(...) st(self).clicks = { ... } end
function Frame:GetEffectiveAlpha() return W.classes.Region.methods.GetEffectiveAlpha(self) end
function Frame:AddRoleset() end
function Frame:SetRoleset() end
function Frame:GetRaisedFrameLevel() return (st(self).level or 0) + 1 end
function Frame:Intersects() return false end
function Frame:IsVisible() return W.visible(self) end
function Frame:SetFrameRef(label, ref)
    local s = st(self)
    s.frameRefs = s.frameRefs or {}
    s.frameRefs[label] = ref
    Frame.SetAttribute(self, "_frame-" .. label, ref)
end
function Frame:GetFrameRef(label) return (st(self).frameRefs or {})[label] end

-- Button ----------------------------------------------------------------------------

local Button = class("Button", "Frame")
local function stateTexture(key, layer)
    return function(self, tex, ...)
        local s = st(self)
        local t = s[key]
        if type(tex) == "table" and rawget(tex, 0) then
            -- Uebernimmt eine fertige Textur.
            if t and t ~= tex then t:Hide() end
            s[key] = tex
            tex:SetParent(self)
            tex:ClearAllPoints()
            tex:SetAllPoints(self)
            local tl = st(tex)
            tl.layer = layer
            W.Button_Refresh(self)
            return
        end
        if tex == nil or tex == "" then
            if t then st(t).texture, st(t).file, st(t).atlas = nil, nil, nil end
            W.Button_Refresh(self)
            return
        end
        if not t then
            t = W.CreateRegion("Texture", self, nil, layer, 0)
            t:SetAllPoints(self)
            s[key] = t
        end
        t:SetTexture(tex)
        if layer == "HIGHLIGHT" and select(1, ...) then t:SetBlendMode(select(1, ...)) end
        if layer == "HIGHLIGHT" and not select(1, ...) then t:SetBlendMode("ADD") end
        W.Button_Refresh(self)
    end
end
local function atlasTexture(key, layer)
    return function(self, atlas, useSize)
        local s = st(self)
        local t = s[key]
        if not t then
            t = W.CreateRegion("Texture", self, nil, layer, 0)
            t:SetAllPoints(self)
            s[key] = t
        end
        t:SetAtlas(atlas, useSize)
        if layer == "HIGHLIGHT" then t:SetBlendMode("ADD") end
        W.Button_Refresh(self)
    end
end
local function getter(key) return function(self) return st(self)[key] end end

Button.SetNormalTexture = stateTexture("normalTex", "ARTWORK")
Button.SetPushedTexture = stateTexture("pushedTex", "ARTWORK")
Button.SetDisabledTexture = stateTexture("disabledTex", "ARTWORK")
Button.SetHighlightTexture = stateTexture("highlightTex", "HIGHLIGHT")
Button.SetNormalAtlas = atlasTexture("normalTex", "ARTWORK")
Button.SetPushedAtlas = atlasTexture("pushedTex", "ARTWORK")
Button.SetDisabledAtlas = atlasTexture("disabledTex", "ARTWORK")
Button.SetHighlightAtlas = atlasTexture("highlightTex", "HIGHLIGHT")
Button.GetNormalTexture = getter("normalTex")
Button.GetPushedTexture = getter("pushedTex")
Button.GetDisabledTexture = getter("disabledTex")
Button.GetHighlightTexture = getter("highlightTex")
function Button:ClearNormalTexture() local t = st(self).normalTex if t then t:SetTexture(nil) end end
function Button:ClearPushedTexture() local t = st(self).pushedTex if t then t:SetTexture(nil) end end
function Button:ClearDisabledTexture() local t = st(self).disabledTex if t then t:SetTexture(nil) end end
function Button:ClearHighlightTexture() local t = st(self).highlightTex if t then t:SetTexture(nil) end end

-- Sichtbarkeit der Zustandstexturen nach Zustand (normal/gedrueckt/aus).
function W.Button_Refresh(self)
    local s = st(self)
    local disabled = s.disabled
    local pushed = s.buttonState == "PUSHED"
    local function show(t, v) if t then st(t).stateHidden = not v end end
    if disabled and s.disabledTex and (st(s.disabledTex).file or st(s.disabledTex).color) then
        show(s.normalTex, false) show(s.pushedTex, false) show(s.disabledTex, true)
    elseif pushed and s.pushedTex and (st(s.pushedTex).file or st(s.pushedTex).color) then
        show(s.normalTex, false) show(s.pushedTex, true) show(s.disabledTex, false)
    else
        show(s.normalTex, true) show(s.pushedTex, false) show(s.disabledTex, false)
    end
    local fs = s.fontString
    if fs then
        local fo = disabled and s.disabledFont or (s.highlighted and s.highlightFont) or s.normalFont
        if fo and st(fs).fontObject ~= fo then fs:SetFontObject(fo) end
    end
end

local function buttonText(self)
    local s = st(self)
    if not s.fontString then
        local fs = W.CreateRegion("FontString", self, nil, "OVERLAY", 0)
        fs:SetPoint("CENTER", self, "CENTER", 0, 0)
        s.fontString = fs
        if s.normalFont then fs:SetFontObject(s.normalFont) end
    end
    return s.fontString
end
function Button:SetText(t)
    if t == nil and not st(self).fontString then return end
    buttonText(self):SetText(t)
end
function Button:SetFormattedText(fmt, ...) buttonText(self):SetFormattedText(fmt, ...) end
function Button:GetText() local fs = st(self).fontString return fs and fs:GetText() end
function Button:GetFontString() return st(self).fontString end
function Button:SetFontString(fs)
    local s = st(self)
    s.fontString = fs
    if fs and s.normalFont and not st(fs).fontObject and not st(fs).fontFile then fs:SetFontObject(s.normalFont) end
end
function Button:GetTextWidth() local fs = st(self).fontString return fs and fs:GetStringWidth() or 0 end
function Button:GetTextHeight() local fs = st(self).fontString return fs and fs:GetStringHeight() or 0 end
local function fontSetter(key)
    return function(self, fo)
        if type(fo) == "string" then fo = rawget(_G, fo) end
        st(self)[key] = fo
        W.Button_Refresh(self)
    end
end
Button.SetNormalFontObject = fontSetter("normalFont")
Button.SetHighlightFontObject = fontSetter("highlightFont")
Button.SetDisabledFontObject = fontSetter("disabledFont")
Button.GetNormalFontObject = getter("normalFont")
Button.GetHighlightFontObject = getter("highlightFont")
Button.GetDisabledFontObject = getter("disabledFont")
function Button:SetPushedTextOffset(x, y) st(self).pushedOffset = { x, y } end
function Button:GetPushedTextOffset() local p = st(self).pushedOffset or { 0, 0 } return p[1], p[2] end
function Button:Enable() st(self).disabled = nil W.Button_Refresh(self) end
function Button:Disable() st(self).disabled = true W.Button_Refresh(self) end
function Button:SetEnabled(v) if Sec.Unwrap(v) then Button.Enable(self) else Button.Disable(self) end end
function Button:IsEnabled() return not st(self).disabled end
function Button:SetButtonState(state, lock) st(self).buttonState = state W.Button_Refresh(self) end
function Button:GetButtonState() return st(self).buttonState or "NORMAL" end
function Button:Click(button, down)
    if st(self).disabled then return end
    button = button or "LeftButton"
    W.Fire(self, "PreClick", button, down)
    W.Fire(self, "OnClick", button, down)
    W.Fire(self, "PostClick", button, down)
end
function Button:SetMotionScriptsWhileDisabled(v) st(self).motionWhileDisabled = not not v end
function Button:GetMotionScriptsWhileDisabled() return not not st(self).motionWhileDisabled end
function Button:RegisterForMouse() end
function Button:SetHighlightLocked(v) st(self).lockHighlight = v or nil end
function Button:IsHighlightLocked() return not not st(self).lockHighlight end

-- CheckButton ------------------------------------------------------------------------

local Check = class("CheckButton", "Button")
Check.SetCheckedTexture = stateTexture("checkedTex", "OVERLAY")
Check.SetDisabledCheckedTexture = stateTexture("disabledCheckedTex", "OVERLAY")
Check.GetCheckedTexture = getter("checkedTex")
Check.GetDisabledCheckedTexture = getter("disabledCheckedTex")
function Check:SetChecked(v)
    local s = st(self)
    s.checked = Sec.Unwrap(v) and true or false
    if s.checkedTex then st(s.checkedTex).stateHidden = not s.checked end
end
function Check:GetChecked() return not not st(self).checked end
local baseCheckRefresh = W.Button_Refresh
function W.Button_Refresh(self)
    baseCheckRefresh(self)
    local s = st(self)
    if s.checkedTex then st(s.checkedTex).stateHidden = not s.checked end
    if s.disabledCheckedTex then st(s.disabledCheckedTex).stateHidden = not (s.checked and s.disabled) end
end
local baseClick = Button.Click
function Check:Click(button, down)
    if st(self).disabled then return end
    Check.SetChecked(self, not st(self).checked)
    baseClick(self, button, down)
end

-- StatusBar -------------------------------------------------------------------------

local Bar = class("StatusBar", "Frame")
local function barTexture(self)
    local s = st(self)
    if not s.barTex then
        local t = W.CreateRegion("Texture", self, nil, "ARTWORK", 0)
        st(t).statusBar = self
        s.barTex = t
    end
    return s.barTex
end
function Bar:SetStatusBarTexture(tex, layer, sub)
    local s = st(self)
    if type(tex) == "table" and rawget(tex, 0) then
        s.barTex = tex
        st(tex).statusBar = self
        return true
    end
    local t = barTexture(self)
    if layer then t:SetDrawLayer(layer, sub) end
    local c = s.barColor
    local ok = t:SetTexture(tex)
    return ok
end
function Bar:GetStatusBarTexture() return barTexture(self) end
function Bar:SetStatusBarAtlas(atlas) barTexture(self):SetAtlas(atlas) end
function Bar:SetStatusBarColor(r, g, b, a)
    barTexture(self):SetVertexColor(r, g, b, a)
end
function Bar:GetStatusBarColor() return barTexture(self):GetVertexColor() end
function Bar:SetStatusBarDesaturated(v) barTexture(self):SetDesaturated(v) end
function Bar:SetMinMaxValues(lo, hi)
    local s = st(self)
    s.min, s.max = num(lo, 0), num(hi, 1)
    if s.value then s.value = math.max(s.min, math.min(s.max, s.value)) end
end
function Bar:GetMinMaxValues() local s = st(self) return s.min or 0, s.max or 1 end
function Bar:SetValue(v)
    local s = st(self)
    v = num(v, 0)
    s.value = math.max(s.min or 0, math.min(s.max or 1, v))
    W.Fire(self, "OnValueChanged", s.value, false)
end
function Bar:GetValue() return st(self).value or 0 end
function Bar:SetOrientation(o) st(self).orientation = o end
function Bar:GetOrientation() return st(self).orientation or "HORIZONTAL" end
function Bar:SetReverseFill(v) st(self).reverse = not not Sec.Unwrap(v) end
function Bar:GetReverseFill() return not not st(self).reverse end
function Bar:SetFillStyle(v) st(self).fillStyle = v end
function Bar:GetFillStyle() return st(self).fillStyle or "STANDARD" end
function Bar:SetRotatesTexture(v) st(self).rotates = not not v end
function Bar:GetRotatesTexture() return not not st(self).rotates end
function Bar:SetTimerDuration() end
function Bar:SetToTargetValue(v) Bar.SetValue(self, v) end
function Bar:GetInterpolatedValue() return Bar.GetValue(self) end
function Bar:IsInterpolating() return false end
function Bar:SetInterpolationMode() end

-- Fuellstand 0..1 fuer den Zeichner.
function W.BarFraction(bar)
    local s = st(bar)
    local lo, hi = s.min or 0, s.max or 1
    if hi <= lo then return 0 end
    return math.max(0, math.min(1, ((s.value or 0) - lo) / (hi - lo)))
end

-- Slider ------------------------------------------------------------------------------

local Slider = class("Slider", "Frame")
function Slider:SetThumbTexture(tex)
    local s = st(self)
    if type(tex) == "table" and rawget(tex, 0) then s.thumb = tex
    else
        if not s.thumb then s.thumb = W.CreateRegion("Texture", self, nil, "ARTWORK", 0) end
        s.thumb:SetTexture(tex)
    end
    st(s.thumb).slider = self
end
function Slider:GetThumbTexture() return st(self).thumb end
function Slider:SetMinMaxValues(lo, hi)
    local s = st(self)
    s.min, s.max = num(lo, 0), num(hi, 1)
    W.Fire(self, "OnMinMaxChanged", s.min, s.max)
end
function Slider:GetMinMaxValues() local s = st(self) return s.min or 0, s.max or 1 end
function Slider:SetValue(v)
    local s = st(self)
    v = math.max(s.min or 0, math.min(s.max or 1, num(v, 0)))
    if s.value == v then return end
    s.value = v
    W.Fire(self, "OnValueChanged", v, false)
end
function Slider:GetValue() return st(self).value or 0 end
function Slider:SetValueStep(v) st(self).step = num(v, 0) end
function Slider:GetValueStep() return st(self).step or 0 end
function Slider:SetObeyStepOnDrag() end
function Slider:GetObeyStepOnDrag() return false end
function Slider:SetStepsPerPage() end
function Slider:GetStepsPerPage() return 1 end
function Slider:SetOrientation(o) st(self).orientation = o end
function Slider:GetOrientation() return st(self).orientation or "HORIZONTAL" end
function Slider:Enable() st(self).disabled = nil end
function Slider:Disable() st(self).disabled = true end
function Slider:SetEnabled(v) st(self).disabled = not v or nil end
function Slider:IsEnabled() return not st(self).disabled end
function Slider:IsDraggingThumb() return false end

-- EditBox (nur Anzeige) -------------------------------------------------------------

local Edit = class("EditBox", "Frame")
for k, v in pairs(W.classes.FontInstance.methods) do
    if k ~= "GetName" then
        Edit[k] = function(self, ...)
            local fs = W.EditText(self)
            return v(fs, ...)
        end
    end
end
function W.EditText(self)
    local s = st(self)
    if not s.textFS then
        local fs = W.CreateRegion("FontString", self, nil, "OVERLAY", 0)
        st(fs).editBox = self
        s.textFS = fs
        fs:SetJustifyH("LEFT")
        W.EditLayout(self)
    end
    return s.textFS
end
function W.EditLayout(self)
    local s = st(self)
    local fs = s.textFS
    if not fs then return end
    local i = s.insets or { 0, 0, 0, 0 }
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", self, "TOPLEFT", i[1], -i[3])
    fs:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -i[2], i[4])
    fs:SetWordWrap(s.multiLine or false)
    if not s.multiLine then fs:SetJustifyV("MIDDLE") else fs:SetJustifyV("TOP") end
end
function Edit:SetText(t)
    local s = st(self)
    t = Sec.Unwrap(t)
    s.text = t and tostring(t) or ""
    local shown = s.text
    if s.password then shown = string.rep("*", #shown) end
    W.EditText(self):SetText(shown)
    W.Fire(self, "OnTextChanged", false)
end
function Edit:GetText() return st(self).text or "" end
function Edit:Insert(t) Edit.SetText(self, (st(self).text or "") .. tostring(t)) end
function Edit:SetNumber(n) Edit.SetText(self, tostring(n)) end
function Edit:GetNumber() return tonumber(st(self).text) or 0 end
function Edit:SetTextInsets(l, r, t, b) st(self).insets = { num(l, 0), num(r, 0), num(t, 0), num(b, 0) } W.EditLayout(self) end
function Edit:GetTextInsets() local i = st(self).insets or { 0, 0, 0, 0 } return i[1], i[2], i[3], i[4] end
function Edit:SetMultiLine(v) st(self).multiLine = not not v W.EditLayout(self) end
function Edit:IsMultiLine() return not not st(self).multiLine end
function Edit:SetAutoFocus(v) st(self).autoFocus = not not v end
function Edit:IsAutoFocus() return not not st(self).autoFocus end
function Edit:SetFocus() st(self).focus = true end
function Edit:ClearFocus() st(self).focus = nil end
function Edit:HasFocus() return not not st(self).focus end
function Edit:SetMaxLetters(n) st(self).maxLetters = n end
function Edit:GetMaxLetters() return st(self).maxLetters or 0 end
function Edit:SetMaxBytes() end
function Edit:SetNumeric(v) st(self).numeric = not not v end
function Edit:IsNumeric() return not not st(self).numeric end
function Edit:SetPassword(v) st(self).password = not not v end
function Edit:HighlightText() end
function Edit:SetCursorPosition(p) st(self).cursor = p end
function Edit:GetCursorPosition() return st(self).cursor or 0 end
function Edit:SetHistoryLines() end
function Edit:AddHistoryLine() end
function Edit:SetCountInvisibleLetters() end
function Edit:SetBlinkSpeed() end
function Edit:SetAltArrowKeyMode() end
function Edit:Enable() st(self).disabled = nil end
function Edit:Disable() st(self).disabled = true end
function Edit:SetEnabled(v) st(self).disabled = not v or nil end
function Edit:IsEnabled() return not st(self).disabled end
function Edit:GetNumLetters() return #(st(self).text or "") end
function Edit:SetHighlightColor() end
function Edit:SetSecureText() end
function Edit:IsInIMECompositionMode() return false end
function Edit:SetVisibleTextByteLimit() end
function Edit:GetFontString() return W.EditText(self) end

-- ScrollFrame -------------------------------------------------------------------------

local Scroll = class("ScrollFrame", "Frame")
function Scroll:SetScrollChild(child)
    local s = st(self)
    if s.scrollChild then st(s.scrollChild).scrollParent = nil end
    s.scrollChild = child
    if child then
        if st(child).parent ~= self then child:SetParent(self) end
        st(child).scrollParent = self
    end
    s.clips = true
    touch()
end
function Scroll:GetScrollChild() return st(self).scrollChild end
function Scroll:SetVerticalScroll(v)
    st(self).vScroll = num(v, 0)
    touch()
    W.Fire(self, "OnVerticalScroll", st(self).vScroll)
end
function Scroll:GetVerticalScroll() return st(self).vScroll or 0 end
function Scroll:SetHorizontalScroll(v) st(self).hScroll = num(v, 0) touch() end
function Scroll:GetHorizontalScroll() return st(self).hScroll or 0 end
function Scroll:GetVerticalScrollRange()
    local c = st(self).scrollChild
    if not c then return 0 end
    return math.max(0, c:GetHeight() - self:GetHeight())
end
function Scroll:GetHorizontalScrollRange()
    local c = st(self).scrollChild
    if not c then return 0 end
    return math.max(0, c:GetWidth() - self:GetWidth())
end
function Scroll:UpdateScrollChildRect() end

-- Cooldown ------------------------------------------------------------------------------

local CD = class("Cooldown", "Frame")
function CD:SetCooldown(start, duration, modRate)
    local s = st(self)
    s.cdStart, s.cdDuration, s.cdRate = num(start, 0), num(duration, 0), num(modRate, 1)
    if s.cdDuration > 0 then W.setShown(self, true) end
end
function CD:SetCooldownDuration(duration, modRate) CD.SetCooldown(self, W.now(), duration, modRate) end
function CD:SetCooldownUNIX(start, duration, modRate) CD.SetCooldown(self, start - os.time() + W.now(), duration, modRate) end
function CD:SetCooldownFromDurationObject(d)
    if type(d) == "table" and d.startTime then CD.SetCooldown(self, d.startTime, d.duration) end
end
function CD:SetCooldownFromExpirationTime(exp, duration, modRate) CD.SetCooldown(self, num(exp, 0) - num(duration, 0), duration, modRate) end
function CD:GetCooldownTimes()
    local s = st(self)
    return (s.cdStart or 0) * 1000, (s.cdDuration or 0) * 1000
end
function CD:GetCooldownDuration() return (st(self).cdDuration or 0) * 1000 end
function CD:Clear() local s = st(self) s.cdStart, s.cdDuration = 0, 0 end
function CD:Pause() st(self).paused = true end
function CD:Resume() st(self).paused = nil end
function CD:IsPaused() return not not st(self).paused end
function CD:SetSwipeColor(r, g, b, a) st(self).swipeColor = { num(r, 0), num(g, 0), num(b, 0), num(a, 0.8) } end
function CD:GetSwipeColor() local c = st(self).swipeColor or { 0, 0, 0, 0.8 } return c[1], c[2], c[3], c[4] end
function CD:SetSwipeTexture(t, r, g, b, a) st(self).swipeTexture = t end
function CD:SetDrawSwipe(v) st(self).noSwipe = not v or nil end
function CD:GetDrawSwipe() return not st(self).noSwipe end
function CD:SetDrawEdge(v) st(self).drawEdge = not not v end
function CD:GetDrawEdge() return not not st(self).drawEdge end
function CD:SetDrawBling(v) st(self).drawBling = not not v end
function CD:GetDrawBling() return not not st(self).drawBling end
function CD:SetReverse(v) st(self).reverse = not not v end
function CD:GetReverse() return not not st(self).reverse end
function CD:SetHideCountdownNumbers(v) st(self).hideNumbers = not not v end
function CD:GetHideCountdownNumbers() return not not st(self).hideNumbers end
function CD:SetEdgeTexture() end
function CD:SetBlingTexture() end
function CD:SetEdgeScale() end
function CD:SetUseCircularEdge() end
function CD:SetCountdownFont(f) st(self).countdownFont = f end
function CD:SetCountdownAbbrevThreshold() end
function CD:SetMinimumCountdownDuration() end
function CD:SetUseAuraDisplayTime() end
function CD:SetTexCoordRange() end
function CD:GetCountdownFontString()
    local s = st(self)
    if not s.countdownFS then
        s.countdownFS = W.CreateRegion("FontString", self, nil, "OVERLAY", 0)
        s.countdownFS:SetPoint("CENTER")
        local fo = rawget(_G, "NumberFontNormal") or rawget(_G, "GameFontHighlightOutline")
        if fo then s.countdownFS:SetFontObject(fo) end
    end
    return s.countdownFS
end
function CD:IsCooldownActive()
    local s = st(self)
    return (s.cdDuration or 0) > 0 and W.now() < (s.cdStart or 0) + s.cdDuration
end

-- Tooltip (GameTooltip) ----------------------------------------------------------------

local Tip = class("GameTooltip", "Frame")
local TOOLTIP_PADDING = 10
local TOOLTIP_LINE_GAP = 2
local TOOLTIP_DOUBLE_GAP = 20

local function tipLine(self, i)
    local s = st(self)
    s.lines = s.lines or {}
    local ln = s.lines[i]
    if ln then return ln end
    local name = s.name or "Tooltip"
    local left = W.CreateRegion("FontString", self, name .. "TextLeft" .. i, "ARTWORK", 0)
    local right = W.CreateRegion("FontString", self, name .. "TextRight" .. i, "ARTWORK", 0)
    local fLeft = i == 1 and (rawget(_G, "GameTooltipHeaderText") or rawget(_G, "GameFontNormalLarge")) or (rawget(_G, "GameTooltipText") or rawget(_G, "GameFontNormal"))
    local fRight = rawget(_G, "GameTooltipTextSmall") or rawget(_G, "GameTooltipText") or rawget(_G, "GameFontNormal")
    if fLeft then left:SetFontObject(fLeft) end
    if fRight then right:SetFontObject(i == 1 and fLeft or fRight) end
    left:SetJustifyH("LEFT")
    right:SetJustifyH("RIGHT")
    ln = { left = left, right = right }
    s.lines[i] = ln
    rawset(self, "TextLeft" .. i, left)
    rawset(self, "TextRight" .. i, right)
    return ln
end

function Tip:SetOwner(owner, anchor, x, y)
    local s = st(self)
    s.owner, s.anchor, s.ox, s.oy = owner, anchor or "ANCHOR_LEFT", num(x, 0), num(y, 0)
    Tip.ClearLines(self)
end
function Tip:GetOwner() return st(self).owner end
function Tip:IsOwned(o) return st(self).owner == o end
function Tip:SetAnchorType(a, x, y) local s = st(self) s.anchor, s.ox, s.oy = a, num(x, 0), num(y, 0) end
function Tip:GetAnchorType() return st(self).anchor end
function Tip:ClearLines()
    local s = st(self)
    s.numLines = 0
    for _, ln in ipairs(s.lines or {}) do
        ln.left:SetText(nil) ln.left:Hide()
        ln.right:SetText(nil) ln.right:Hide()
    end
    for _, f in ipairs(s.inserted or {}) do f:Hide() end
    s.inserted = {}
end
function Tip:NumLines() return st(self).numLines or 0 end
local function addLine(self, left, right, lc, rc, wrap)
    local s = st(self)
    s.numLines = (s.numLines or 0) + 1
    local ln = tipLine(self, s.numLines)
    ln.left:SetText(left)
    ln.left:SetTextColor(lc[1], lc[2], lc[3], lc[4] or 1)
    ln.left:Show()
    ln.wrap = wrap
    if right then
        ln.right:SetText(right)
        ln.right:SetTextColor(rc[1], rc[2], rc[3], rc[4] or 1)
        ln.right:Show()
    else
        ln.right:Hide()
    end
end
local NORMAL = { 1, 0.82, 0 }
local HIGHLIGHT = { 1, 1, 1 }
function Tip:SetText(text, r, g, b, a, wrap)
    Tip.ClearLines(self)
    addLine(self, text, nil, { num(r, 1), num(g, 1), num(b, 1), num(a, 1) }, nil, wrap)
    Tip.Show(self)
end
function Tip:AddLine(text, r, g, b, wrap)
    addLine(self, text, nil, { num(r, NORMAL[1]), num(g, NORMAL[2]), num(b, NORMAL[3]) }, nil, wrap)
end
function Tip:AddDoubleLine(l, rText, lr, lg, lb, rr, rg, rb)
    addLine(self, l, rText, { num(lr, NORMAL[1]), num(lg, NORMAL[2]), num(lb, NORMAL[3]) },
        { num(rr, HIGHLIGHT[1]), num(rg, HIGHLIGHT[2]), num(rb, HIGHLIGHT[3]) })
end
function Tip:AddTexture() end
function Tip:SetMinimumWidth(w) st(self).minWidth = num(w, 0) end
function Tip:SetPadding(r, b, l, t) st(self).padding = { num(r, 0), num(b, 0), num(l, 0), num(t, 0) } end
function Tip:GetPadding() local p = st(self).padding or { 0, 0, 0, 0 } return p[1], p[2], p[3], p[4] end
function Tip:InsertFrame(frame, height)
    local s = st(self)
    s.inserted = s.inserted or {}
    table.insert(s.inserted, frame)
    s.numLines = (s.numLines or 0) + 1
    local ln = tipLine(self, s.numLines)
    ln.left:SetText(" ")
    ln.left:Show()
    ln.frame = frame
    ln.frameHeight = height or frame:GetHeight()
    frame:SetParent(self)
    frame:Show()
    return 0
end

-- Groesse und Zeilenlage wie GameTooltip:Show im Client.
function W.TooltipLayout(self)
    local s = st(self)
    local n = s.numLines or 0
    local width, y = s.minWidth or 0, -TOOLTIP_PADDING
    for i = 1, n do
        local ln = s.lines[i]
        local lw = ln.left:GetStringWidth()
        if ln.right:IsShown() then lw = lw + TOOLTIP_DOUBLE_GAP + ln.right:GetStringWidth() end
        if ln.frame then lw = math.max(lw, ln.frame:GetWidth()) end
        if lw > width then width = lw end
    end
    local pad = s.padding or { 0, 0, 0, 0 }
    for i = 1, n do
        local ln = s.lines[i]
        ln.left:ClearAllPoints()
        ln.left:SetPoint("TOPLEFT", self, "TOPLEFT", TOOLTIP_PADDING + pad[3], y)
        if ln.wrap then ln.left:SetWidth(width) end
        ln.right:ClearAllPoints()
        ln.right:SetPoint("RIGHT", ln.left, "LEFT", width, 0)
        local h = ln.frame and ln.frameHeight or ln.left:GetStringHeight()
        if ln.frame then
            ln.frame:ClearAllPoints()
            ln.frame:SetPoint("TOPLEFT", ln.left, "TOPLEFT", 0, 0)
        end
        y = y - h - TOOLTIP_LINE_GAP
    end
    W.classes.ScriptRegion.methods.SetSize(self, width + 2 * TOOLTIP_PADDING + pad[1] + pad[3], -y + TOOLTIP_PADDING - TOOLTIP_LINE_GAP + pad[2] + pad[4])
    -- Anker beim Besitzer.
    local owner = s.owner
    if owner and s.anchor and s.anchor ~= "ANCHOR_NONE" and s.anchor ~= "ANCHOR_PRESERVE" then
        self:ClearAllPoints()
        local a, ox, oy = s.anchor, s.ox or 0, s.oy or 0
        local map = {
            ANCHOR_TOP = { "BOTTOM", "TOP" }, ANCHOR_BOTTOM = { "TOP", "BOTTOM" },
            ANCHOR_LEFT = { "BOTTOMRIGHT", "TOPLEFT" }, ANCHOR_RIGHT = { "BOTTOMLEFT", "TOPRIGHT" },
            ANCHOR_TOPLEFT = { "BOTTOMLEFT", "TOPLEFT" }, ANCHOR_TOPRIGHT = { "BOTTOMRIGHT", "TOPRIGHT" },
            ANCHOR_BOTTOMLEFT = { "TOPRIGHT", "BOTTOMLEFT" }, ANCHOR_BOTTOMRIGHT = { "TOPLEFT", "BOTTOMRIGHT" },
        }
        local m = map[a]
        if m then self:SetPoint(m[1], owner, m[2], ox, oy)
        elseif a == "ANCHOR_CURSOR" or a == "ANCHOR_CURSOR_RIGHT" then
            local cx, cy = W.cursor and W.cursor[1] or 0, W.cursor and W.cursor[2] or 0
            local es = L.EffectiveScale(self)
            self:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", cx / es + ox, cy / es + oy)
        end
    end
end
function Tip:Show()
    W.TooltipLayout(self)
    W.setShown(self, true)
end
function Tip:FadeOut() W.setShown(self, false) end
function Tip:SetUnit(unit) if W.hooks.tooltipUnit then W.hooks.tooltipUnit(self, unit) end end
function Tip:SetSpellByID(id) if W.hooks.tooltipSpell then W.hooks.tooltipSpell(self, id) end end
function Tip:SetItemByID(id) if W.hooks.tooltipItem then W.hooks.tooltipItem(self, id) end end
function Tip:SetHyperlink(link) end
function Tip:GetUnit() return nil end
function Tip:GetSpell() return nil end
function Tip:GetItem() return nil end
function Tip:IsTooltipType() return false end
function Tip:SetUnitAura() end
function Tip:SetUnitBuff() end
function Tip:SetUnitDebuff() end
function Tip:SetUnitBuffByAuraInstanceID() end
function Tip:SetUnitDebuffByAuraInstanceID() end
function Tip:SetMinimumWidth(w) st(self).minWidth = num(w, 0) end
function Tip:GetMinimumWidth() return st(self).minWidth or 0 end
function Tip:SetAllowShowWithNoLines() end
function Tip:SetCustomLineSpacing() end
function Tip:SetCustomWordWrapMinWidth() end
function Tip:SetCurrencyByID() end
function Tip:SetQuestLogItem() end
function Tip:SetAction() end
function Tip:SetBagItem() end
function Tip:SetInventoryItem() end
function Tip:AppendText(t)
    local s = st(self)
    local ln = s.lines and s.lines[s.numLines or 0]
    if ln then ln.left:SetText((ln.left:GetText() or "") .. t) end
end

-- Uebrige Typen ohne eigene Darstellung -------------------------------------------------

local Msg = class("MessageFrame", "Frame")
for k, v in pairs(W.classes.FontInstance.methods) do if k ~= "GetName" and not Msg[k] then Msg[k] = v end end
function Msg:AddMessage() end
function Msg:Clear() end
function Msg:SetFading() end
function Msg:SetTimeVisible() end
function Msg:SetFadeDuration() end
function Msg:SetInsertMode() end
function Msg:SetMaxLines() end
local SMsg = class("ScrollingMessageFrame", "MessageFrame")
function SMsg:GetNumMessages() return 0 end
function SMsg:ScrollToBottom() end

class("Model", "Frame")
class("PlayerModel", "Model")
class("DressUpModel", "PlayerModel")
class("CinematicModel", "PlayerModel")
class("TabardModel", "PlayerModel")
class("ModelScene", "Frame")
class("ColorSelect", "Frame")
class("SimpleHTML", "Frame")
class("Browser", "Frame")
class("Checkout", "Frame")
class("FogOfWarFrame", "Frame")
class("UnitPositionFrame", "Frame")
class("ArchaeologyDigSiteFrame", "Frame")
class("QuestPOIFrame", "Frame")
class("ScenarioPOIFrame", "Frame")
class("MovieFrame", "Frame")
class("OffScreenFrame", "Frame")
class("WorldFrame", "Frame")
class("ScrollingMessageFrame2", "Frame")
class("ContainedAlertFrame", "Frame")
class("AuraContainer", "Frame")
class("Minimap", "Frame")
class("PingPin", "Frame")

-- 3D-Modelle sind Platzhalter (siehe Grenzen): ein graues Feld mit Beschriftung.
local Model = W.classes.Model.methods
for _, typ in ipairs({ "Model", "PlayerModel", "DressUpModel", "CinematicModel", "TabardModel", "ModelScene" }) do
    W.classes[typ].methods.__isModel = true
end
function Model:SetUnit(u) st(self).modelUnit = u end
function Model:SetPortraitZoom() end
function Model:SetCamDistanceScale() end
function Model:SetPosition() end
function Model:SetFacing() end
function Model:ClearModel() end
function Model:SetModel() end
function Model:SetDisplayInfo() end
function Model:SetCreature() end
function Model:RefreshUnit() end
function Model:SetAnimation() end
function Model:SetKeepModelOnHide() end
function Model:SetLight() end
function Model:SetModelDrawLayer() end
function Model:SetViewTranslation() end
function Model:SetCamera() end
function Model:FreezeAnimation() end
function Model:SetPaused() end
function Model:SetRotation() end

-- CreateFrame --------------------------------------------------------------------------

local TYPE_ALIASES = { CheckBox = "CheckButton", Checkbox = "CheckButton" }

function F.CreateFrame(frameType, name, parent, templates, id)
    if type(frameType) ~= "string" then error("CreateFrame: Unknown frame type", 2) end
    local intrinsic = W.hooks.intrinsic and W.hooks.intrinsic(frameType)
    local base = TYPE_ALIASES[frameType] or frameType
    if intrinsic then base = intrinsic.baseType end
    -- Gross-/Kleinschreibung beim Typ ist dem Client egal.
    if not W.classes[base] then
        for k in pairs(W.classes) do
            if k:lower() == base:lower() then base = k break end
        end
    end
    local c = W.classes[base]
    if not c or not c.methods.CreateTexture then
        error(("CreateFrame: Unknown frame type '%s'"):format(tostring(frameType)), 2)
    end
    if type(parent) == "string" then parent = rawget(_G, parent) end
    local o, s = W.newObject(base, parent, name)
    s.isFrame = true
    s.level = parent and ((st(parent).level or 0) + 1) or 0
    s.strata = parent and st(parent).strata or "MEDIUM"
    if base == "GameTooltip" then s.strata = "TOOLTIP" end
    W.attach(o)
    if id then s.id = id end
    touch()
    if intrinsic then W.ApplyTemplates(o, frameType, true) end
    if templates then W.ApplyTemplates(o, templates) end
    if W.hooks.afterCreate then W.hooks.afterCreate(o, templates) end
    return o
end

return F
