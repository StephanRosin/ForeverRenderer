-- C-Funktionen des Clients, die nicht in der generierten Doku stehen, aber
-- von Blizzards Grundlagen-Code und den Addons beim Laden gebraucht werden.
local W = require("widgets")
local R = require("report")

local C = {}

-- Mixin und CreateFromMixins liefert der Client in C (Mixin.lua sichert sie nur).
local function Mixin(object, ...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        if mixin then
            for k, v in pairs(mixin) do object[k] = v end
        end
    end
    return object
end

-- Szenario-Angaben zum Client (Version wie Live-Forever).
C.BUILD = { version = "1.60.1", build = "70938", date = "Nov 12 2026", interface = 16001 }

function C.Install(state, env)
    _G.Mixin = Mixin
    _G.CreateFromMixins = function(...) return Mixin({}, ...) end
    _G.GetCurrentEnvironment = function() return _G end
    _G.SetCurrentEnvironment = function() end
    _G.issecure = function() return W.loadingBlizzard or false end
    _G.GetLocale = function() return state.locale or "enUS" end
    _G.GetBuildInfo = function()
        return C.BUILD.version, C.BUILD.build, C.BUILD.date, C.BUILD.interface, "", "", C.BUILD.interface
    end
    _G.WOW_PROJECT_MAINLINE = 1
    _G.WOW_PROJECT_CLASSIC = 2
    _G.WOW_PROJECT_ID = 1
    _G.IsMacClient = function() return false end
    _G.IsWindowsClient = function() return true end
    _G.IsLinuxClient = function() return false end
    _G.IsTestBuild = function() return false end
    _G.IsBetaBuild = function() return false end
    _G.IsPublicBuild = function() return true end
    _G.IsPublicTestClient = function() return false end
    _G.IsGMClient = function() return false end
    _G.IsOnGlueScreen = function() return false end
    _G.Is64BitClient = function() return true end
    _G.IsDemonHunterAvailable = function() return false end
    _G.GetText = function(token) return _G[token] end
    _G.IsInGlue = function() return false end
    _G.GetGlobalEnvironment = function() return _G end
    _G.SetErrorCallstackHeight = function() end
    _G.GetCallstackHeight = function() return 1 end
    for _, typ in ipairs({ "Frame", "Button", "CheckButton", "EditBox", "Texture", "FontString", "StatusBar", "Slider", "ScrollFrame", "Cooldown", "GameTooltip", "Line", "MaskTexture", "AnimationGroup", "Animation" }) do
        local meta = W.classes[typ] and W.classes[typ].meta
        _G["Get" .. typ .. "Metatable"] = function() return meta end
    end
    _G.C_Widget = _G.C_Widget or {}
    C_Widget.IsWidget = function(o) return type(o) == "table" and rawget(o, 0) ~= nil end
    C_Widget.IsFrameWidget = function(o) return type(o) == "table" and rawget(o, 0) ~= nil and W.st(o).isFrame or false end
    C_Widget.IsRenderableWidget = function(o) return type(o) == "table" and rawget(o, 0) ~= nil end
    -- Globale Texte und Farben kommen im Client aus Spieltabellen (DB2).
    local Media = require("media")
    local U = require("util")
    local strings = Media.artDir and U.readFile(Media.artDir .. "/globalstrings.json")
    if strings then
        for k, v in pairs(Media.DecodeJson(strings)) do
            if rawget(_G, k) == nil then rawset(_G, k, v) end
        end
    else
        R.Note("globalstrings.json fehlt im Grafik-Archiv: globale Texte (z. B. PRESS_TAB) sind nil")
    end
    local colors = Media.artDir and U.readFile(Media.artDir .. "/globalcolors.json")
    local colorList = colors and Media.DecodeJson(colors) or {}
    if not colors then R.Note("globalcolors.json fehlt im Grafik-Archiv: C_UIColor.GetColors() ist leer") end
    _G.C_UIColor = _G.C_UIColor or {}
    C_UIColor.GetColors = function()
        local out = {}
        for _, c in ipairs(colorList) do
            out[#out + 1] = { baseTag = c.baseTag, color = { r = c.r, g = c.g, b = c.b, a = c.a } }
        end
        return out
    end
    -- Kurven (C_CurveUtil): Stuetzpunkte, linear ausgewertet.
    local Curve = {}
    Curve.__index = Curve
    function Curve:AddPoint(x, y) table.insert(self.points, { x, y }) table.sort(self.points, function(a, b) return a[1] < b[1] end) end
    function Curve:Evaluate(x)
        local p = self.points
        if #p == 0 then return 0 end
        if x <= p[1][1] then return p[1][2] end
        for i = 2, #p do
            if x <= p[i][1] then
                local a, b = p[i - 1], p[i]
                return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
            end
        end
        return p[#p][2]
    end
    function Curve:SetType(t) self.type = t end
    function Curve:ClearPoints() self.points = {} end
    function Curve:GetPointCount() return #self.points end
    function Curve:Copy() local c = setmetatable({ points = {} }, Curve) for i, v in ipairs(self.points) do c.points[i] = { v[1], v[2] } end return c end
    _G.C_CurveUtil = _G.C_CurveUtil or {}
    C_CurveUtil.CreateCurve = function() return setmetatable({ points = {} }, Curve) end
    C_CurveUtil.CreateColorCurve = function() return setmetatable({ points = {} }, Curve) end
    -- Zeitsignale: Rueckruf je Schluessel nach Ablauf.
    C_Timer.NewTimedSignalMap = function(dispatch)
        local map = {}
        function map:SetSignal(key, delay) C_Timer.After(delay or 0, function() dispatch(key) end) end
        function map:ClearSignal() end
        function map:ClearAllSignals() end
        return map
    end
    -- Schriftobjekte (fuer TextSizeManager u. a.).
    _G.GetFonts = function()
        local out = {}
        for _, o in ipairs(W.all) do
            local s = W.st(o)
            if s.isFont and s.name then out[#out + 1] = s.name end
        end
        return out
    end
    _G.GetFontInfo = function(name)
        local fo = type(name) == "string" and rawget(_G, name) or name
        if not fo or not fo.GetFont then return nil end
        local path, height, flags = fo:GetFont()
        local r, g, b, a = fo:GetTextColor()
        return { height = height, outline = flags, color = { r = r, g = g, b = b, a = a }, canBeUserScaled = false }
    end
end

return C
