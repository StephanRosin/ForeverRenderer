-- Globale Umgebung wie im Client: Lua-Erweiterungen (strsplit, wipe, bit ...),
-- Enum/Constants aus der Doku, protokollierende Stubs fuer jede
-- dokumentierte, aber nicht nachgebaute Funktion, und die Grundbausteine
-- (CreateFrame, CreateFont, UIParent, GetTime, C_Timer, hooksecurefunc).
local W = require("widgets")
local Frames = require("frames")
local L = require("layout")
local R = require("report")
local Sec = require("secret")
local E = require("events")
local X = require("xml")

local Env = {}
local st = W.st

-- Lua-Erweiterungen des Clients -----------------------------------------------------

local function installLuaExtensions()
    _G.type = Sec.Type
    string.format = Sec.Format
    _G.format = Sec.Format
    table.wipe = function(t)
        for k in pairs(t) do t[k] = nil end
        return t
    end
    _G.wipe = table.wipe
    string.trim = function(s, chars)
        if chars then
            local set = "[" .. chars:gsub("[%]%^%-]", "%%%0") .. "]"
            return (s:gsub("^" .. set .. "+", ""):gsub(set .. "+$", ""))
        end
        return (s:gsub("^%s+", ""):gsub("%s+$", ""))
    end
    _G.strtrim = string.trim
    local function split(sep, s, limit)
        if s == nil then return nil end
        s = tostring(Sec.Unwrap(s))
        local out, pos = {}, 1
        local set = "[" .. sep:gsub("[%]%^%-%%]", "%%%0") .. "]"
        while true do
            if limit and #out == limit - 1 then out[#out + 1] = s:sub(pos) break end
            local a, b = s:find(set, pos)
            if not a then out[#out + 1] = s:sub(pos) break end
            out[#out + 1] = s:sub(pos, a - 1)
            pos = b + 1
        end
        return unpack(out)
    end
    _G.strsplit = split
    string.split = split
    _G.strsplittable = function(sep, s, limit) return { split(sep, s, limit) } end
    _G.strjoin = function(sep, ...)
        local t = { ... }
        for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
        return table.concat(t, sep)
    end
    string.join = _G.strjoin
    _G.strconcat = function(...) return table.concat({ ... }) end
    _G.strcmputf8i = function(a, b)
        a, b = tostring(a):lower(), tostring(b):lower()
        if a == b then return 0 end
        return a < b and -1 or 1
    end
    _G.strlenutf8 = function(s)
        local n = 0
        for _ in tostring(s):gmatch("[^\128-\191]") do n = n + 1 end
        return n
    end
    string.utf8len = _G.strlenutf8
    _G.tostringall = function(...)
        local t = { ... }
        for i = 1, select("#", ...) do t[i] = tostring(t[i]) end
        return unpack(t, 1, select("#", ...))
    end
    _G.bit = _G.bit or require("bit")
    math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    _G.fastrandom = math.random
    _G.debugstack = function(start, n1, n2) return debug.traceback("", (start or 1) + 1) end
    _G.debuglocals = function() return "" end
    _G.debugprofilestart = function() end
    _G.debugprofilestop = function() return os.clock() * 1000 end
    _G.securecall = function(fn, ...)
        if type(fn) == "string" then fn = _G[fn] end
        return R.Call(fn, ...)
    end
    _G.securecallfunction = _G.securecall
    _G.secureexecuterange = function(t, fn, ...)
        for k, v in pairs(t) do R.Call(fn, k, v, ...) end
    end
    _G.issecure = function() return false end
    _G.issecurevariable = function() return true, nil end
    _G.forceinsecure = function() end
    _G.scrub = function(...) return ... end
    _G.issecretvalue = Sec.Is
    _G.issecrettable = function() return false end
    _G.canaccessvalue = function(v) return not Sec.Is(v) end
    _G.canaccesssecrets = function() return false end
    _G.canaccesstable = function() return true end
    _G.secretwrap = function(...) local t = { ... } for i = 1, select("#", ...) do t[i] = Sec.Wrap(t[i]) end return unpack(t, 1, select("#", ...)) end
    _G.dropsecretaccess = function() end
    _G.mapvalues = function(fn, ...)
        local t = { ... }
        for i = 1, select("#", ...) do t[i] = fn(t[i]) end
        return unpack(t, 1, select("#", ...))
    end
    _G.hasanysecretvalues = function(...) return Sec.AnyArg(...) end
    local errorHandler = function(err) R.Error(err, debug.traceback("", 2)) end
    _G.geterrorhandler = function() return errorHandler end
    _G.seterrorhandler = function(fn) errorHandler = fn end
end

-- hooksecurefunc: Nachlaeufer an Tabellen- oder globale Funktionen.
local function hooksecurefunc(t, name, fn)
    if type(t) == "string" then t, name, fn = _G, t, name end
    local orig = t[name]
    if type(orig) ~= "function" then error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2) end
    t[name] = function(...)
        local r = { orig(...) }
        R.Call(fn, ...)
        return unpack(r, 1, table.maxn(r))
    end
end

-- Doku-Stubs ----------------------------------------------------------------------------

local function stub(label)
    return function()
        R.Missing("api", label)
        return nil
    end
end

local function installDocStubs(D)
    _G.Enum = D.enums
    _G.Constants = D.constants
    for _, sys in ipairs(D.systems) do
        local ns = sys.Namespace
        local target = _G
        if ns then
            target = rawget(_G, ns)
            if target == nil then target = {} rawset(_G, ns, target) end
        end
        for _, fn in ipairs(sys.Functions or {}) do
            if rawget(target, fn.Name) == nil then
                target[fn.Name] = stub((ns and ns .. "." or "") .. fn.Name)
                Env.stubbed[(ns and ns .. "." or "") .. fn.Name] = target[fn.Name]
            end
        end
    end
end

-- Dokumentierte Widget-Methoden, die nicht nachgebaut sind, protokollieren.
local DOC_FOR_CLASS = {
    Object = { "SimpleObjectAPI", "SimpleFrameScriptObjectAPI" },
    ScriptRegion = { "SimpleScriptRegionAPI", "SimpleScriptRegionResizingAPI" },
    Region = { "SimpleRegionAPI" },
    TextureBase = { "SimpleTextureBaseAPI" },
    Texture = { "SimpleTextureAPI" },
    MaskTexture = { "SimpleMaskTextureAPI" },
    Line = { "SimpleLineAPI" },
    FontString = { "SimpleFontStringAPI" },
    Font = { "SimpleFontAPI" },
    Frame = { "SimpleFrameAPI" },
    Button = { "SimpleButtonAPI" },
    CheckButton = { "SimpleCheckboxAPI" },
    StatusBar = { "SimpleStatusBarAPI" },
    Slider = { "SimpleSliderAPI" },
    EditBox = { "SimpleEditBoxAPI" },
    ScrollFrame = { "SimpleScrollFrameAPI" },
    Cooldown = { "FrameAPICooldown" },
    GameTooltip = { "FrameAPITooltip" },
    MessageFrame = { "SimpleMessageFrameAPI" },
    Model = { "SimpleModelAPI" },
    ColorSelect = { "SimpleColorSelectAPI" },
    SimpleHTML = { "SimpleHTMLAPI" },
    Minimap = { "MinimapFrameAPI" },
    AnimationGroup = { "SimpleAnimGroupAPI" },
    Animation = { "SimpleAnimAPI" },
}
local CLASS_ORDER = { "Object", "ScriptRegion", "Region", "TextureBase", "Texture", "MaskTexture", "Line", "FontString", "Font",
    "Frame", "Button", "CheckButton", "StatusBar", "Slider", "EditBox", "ScrollFrame", "Cooldown", "GameTooltip",
    "MessageFrame", "Model", "ColorSelect", "SimpleHTML", "Minimap", "AnimationGroup", "Animation" }

local function installMethodStubs(D)
    -- Stubs pro Klasse, dann an alle abgeleiteten Klassen weiterreichen.
    for _, cname in ipairs(CLASS_ORDER) do
        local c = W.classes[cname]
        for _, doc in ipairs(DOC_FOR_CLASS[cname] or {}) do
            for _, m in ipairs(D.Methods(doc)) do
                if c.methods[m] == nil then
                    local label = cname .. ":" .. m
                    c.methods[m] = function() R.Missing("method", label) return nil end
                end
            end
        end
    end
    for _, c in pairs(W.classes) do
        local p = c.parentClass
        while p do
            for k, v in pairs(p.methods) do if c.methods[k] == nil then c.methods[k] = v end end
            p = p.parentClass
        end
    end
    -- FontString und EditBox haben die FontInstance-Methoden doppelt; Frames die Region-Methoden.
end

-- Grundbausteine ------------------------------------------------------------------------

function Env.CreateFont(name)
    local fo, s = W.newObject("Font", nil, name)
    s.isFont = true
    return fo
end
X.CreateFont = Env.CreateFont

local function makeRoots(scn)
    local CreateFrame = Frames.CreateFrame
    local world = CreateFrame("Frame", "WorldFrame")
    world:SetAllPoints(nil)
    st(world).points = {
        { point = "TOPLEFT", rel = "SCREEN", relPoint = "TOPLEFT", x = 0, y = 0 },
        { point = "BOTTOMRIGHT", rel = "SCREEN", relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    }
    local ui = CreateFrame("Frame", "UIParent")
    st(ui).points = {
        { point = "TOPLEFT", rel = "SCREEN", relPoint = "TOPLEFT", x = 0, y = 0 },
        { point = "BOTTOMRIGHT", rel = "SCREEN", relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    }
    ui:SetScale(scn.uiScale or 1)
    st(ui).strata = "MEDIUM"
    st(ui).level = 0
end

function Env.Install(D, scn)
    Env.stubbed = {}
    installLuaExtensions()
    E.docs = D
    installDocStubs(D)
    installMethodStubs(D)
    X.env = _G
    _G.CreateFrame = Frames.CreateFrame
    _G.CreateFont = Env.CreateFont
    _G.hooksecurefunc = hooksecurefunc
    _G.GetTime = function() return E.clock end
    _G.GetTimePreciseSec = function() return E.clock end
    _G.GetServerTime = function() return Env.epoch + math.floor(E.clock - Env.clockStart) end
    _G.time = function(t)
        if t then return os.time(t) end
        return Env.epoch + math.floor(E.clock - Env.clockStart)
    end
    _G.date = function(fmt, t) return os.date(fmt, t or _G.time()) end
    _G.C_Timer = setmetatable(E.C_Timer, { __index = _G.C_Timer })
    _G.GetFramerate = function() return 60 end
    _G.GetScreenWidth = function() return L.screenW end
    _G.GetScreenHeight = function() return L.screenH end
    _G.GetPhysicalScreenSize = function() return L.physW, L.physH end
    _G.GetScreenDPIScale = function() return 1 end
    _G.GetCursorPosition = function()
        -- Welt-Einheiten: geteilt durch UIParent:GetEffectiveScale() ergibt UIParent-Koordinaten.
        local c = W.cursor or { 0, 0 }
        return c[1], c[2]
    end
    _G.GetMouseFoci = function() return { W.mouseFocus } end
    _G.GetMouseFocus = function() return W.mouseFocus end
    _G.EnumerateFrames = function(cur)
        local found = cur == nil
        for _, o in ipairs(W.all) do
            local s = st(o)
            if s.isFrame then
                if found then return o end
                if o == cur then found = true end
            end
        end
        return nil
    end
    _G.InCombatLockdown = function() return Env.state and Env.state.combat or false end
    _G.ReloadUI = function() R.Note("ReloadUI aufgerufen (ignoriert)") end
    _G.PlaySound = function() return true end
    _G.PlaySoundFile = function() return true end
    _G.StopSound = function() end
    _G.Screenshot = function() end
    _G.RegisterStateDriver = function(frame, state, values) Env.RegisterStateDriver(frame, state, values) end
    _G.UnregisterStateDriver = function() end
    _G.RegisterAttributeDriver = function(frame, attr, values) Env.RegisterStateDriver(frame, attr, values, true) end
    _G.UnregisterAttributeDriver = function() end
    _G.RegisterUnitWatch = function(frame, asState) Env.RegisterUnitWatch(frame, asState) end
    _G.UnregisterUnitWatch = function() end
    _G.UnitWatchRegistered = function() return false end
    Env.epoch = scn.epoch or 1794700800 -- 2026-11-15 00:00 UTC als feste Szenario-Zeit
    Env.clockStart = E.clock
    makeRoots(scn)
end

-- Sichtbarkeitstreiber ([combat] hide; show ...) einmal auswerten.
function Env.EvalConditional(spec)
    if type(spec) ~= "string" then return nil end
    for clause in spec:gmatch("[^;]+") do
        local conds, value = clause:match("^%s*(%b[])%s*(.-)%s*$")
        if not conds then return (clause:gsub("^%s+", ""):gsub("%s+$", "")) end
        local all = true
        for cond in conds:gmatch("%[([^%]]*)%]") do
            local ok = true
            for c in (cond .. ","):gmatch("([^,]*),") do
                c = c:gsub("^%s+", ""):gsub("%s+$", "")
                if c ~= "" and not Env.Condition(c) then ok = false break end
            end
            if ok then all = true break else all = false end
        end
        if all then return value end
    end
    return nil
end

function Env.Condition(c)
    local neg = false
    if c:sub(1, 2) == "no" and c ~= "nomod" then neg = true c = c:sub(3) end
    local key, arg = c:match("^([%w@]+):?(.*)$")
    local s = Env.state or {}
    local v
    if key == "combat" then v = s.combat or false
    elseif key == "group" then
        if arg == "raid" then v = (s.group == "raid") else v = s.group ~= nil end
    elseif key == "petbattle" or key == "vehicleui" or key == "overridebar" or key == "possessbar" or key == "mounted" or key == "flying" or key == "dead" then v = false
    elseif key == "pet" then v = s.pet ~= nil
    elseif key == "harm" or key == "help" or key == "exists" then
        v = Env.UnitExists and Env.UnitExists("target") or false
    elseif key:sub(1, 1) == "@" then v = true
    else v = false end
    if neg then return not v end
    return v
end

function Env.RegisterStateDriver(frame, state, values, isAttribute)
    local v = Env.EvalConditional(values)
    if isAttribute then
        frame:SetAttribute(state, v)
    elseif state == "visibility" then
        if v == "hide" then frame:Hide() else frame:Show() end
    else
        frame:SetAttribute("state-" .. state, v)
    end
end

function Env.RegisterUnitWatch(frame, asState)
    local unit = frame:GetAttribute("unit")
    local exists = unit and Env.UnitExists and Env.UnitExists(unit)
    if asState then frame:SetAttribute("state-unitexists", exists and true or false)
    elseif exists then frame:Show() else frame:Hide() end
end

return Env
