-- Szenario-Schritte: Zeit vorspulen, Ereignisse, Klicks, Zeigen (Hover),
-- Slash-Befehle und freie Lua-Funktionen im Client.
local W = require("widgets")
local E = require("events")
local L = require("layout")
local R = require("report")

local S = {}
local st = W.st

local function find(name)
    if type(name) ~= "string" then return name end
    local o = rawget(_G, name)
    if o then return o end
    -- Pfad wie "ForeverDataBar.gold.button"
    local cur
    for part in name:gmatch("[^%.]+") do
        if cur == nil then cur = rawget(_G, part) else cur = cur and cur[part] end
    end
    return cur
end
S.Find = find

-- Alle Theme-Kennungen der Forever-Familie (Themes.IDS der Addons).
S.THEME_IDS = { "CLASSIC", "WOOD", "TECH", "PARCHMENT", "RUNESTONE", "GLASS", "COMIC", "FROST", "PIXEL", "SWISS", "CONSOLE", "PITWALL",
    "WOOD_HD", "TECH_HD", "PARCHMENT_HD", "RUNESTONE_HD", "GLASS_HD", "COMIC_HD", "FROST_HD" }

-- Je Addon: aktuelles Theme und Farben je Theme, fuer Bilderbogen und Bericht.
function S.ThemeInfo()
    local out = {}
    for name, e in pairs(rawget(_G, "ForeverThemes") or {}) do
        if type(e) == "table" and e.Switch then
            local colors = {}
            for _, id in ipairs(S.THEME_IDS) do
                local list = e.Colors and R.Call(e.Colors, id)
                colors[id] = list or {}
            end
            out[name] = { current = e.Current and R.Call(e.Current), color = e.Color and R.Call(e.Color), colors = colors }
        end
    end
    return out
end

-- Theme (und Farbe) in allen geladenen Forever-Addons ueber ihre
-- Registrierung _G.ForeverThemes setzen, wie das Theme-Menue des InfoPanel.
function S.Theme(theme, color, only)
    local reg = rawget(_G, "ForeverThemes") or {}
    local names = {}
    for name in pairs(reg) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local e = reg[name]
        if (not only or only == name) and type(e) == "table" and e.Switch then
            local ok, why = R.Call(e.Switch, theme)
            if not ok and why then R.Note(name .. ": Theme " .. tostring(theme) .. " abgelehnt (" .. tostring(why) .. ")") end
            if color and e.SetColor then R.Call(e.SetColor, color, theme) end
        end
    end
end

-- "Addon:Pfad.zur.Funktion" im privaten Namensraum eines Addons aufrufen.
function S.Call(spec, args)
    local addon, path = spec:match("^([^:]+):(.+)$")
    local cur = addon and require("loader").namespaces[addon]
    for part in (path or ""):gmatch("[^%.]+") do cur = type(cur) == "table" and cur[part] or nil end
    if type(cur) ~= "function" then
        R.Error("Schritt call: Funktion fehlt " .. spec, "")
        return
    end
    R.Call(cur, unpack(args or {}))
end

function S.Run(step, scn)
    if step.call then S.Call(step.call, step.args) end
    if step.theme then S.Theme(step.theme, step.color, step.addon) end
    if step.advance then E.Advance(step.advance) end
    if step.event then E.Fire(step.event, unpack(step.args or {})) end
    if step.run then R.Call(step.run) end
    if step.slash then S.Slash(step.slash) end
    if step.click then
        local f = find(step.click)
        if not f then R.Error("Schritt click: Rahmen fehlt " .. tostring(step.click), "")
        elseif f.Click then f:Click(step.button or "LeftButton") end
    end
    if step.hover then
        local f = find(step.hover)
        if not f then R.Error("Schritt hover: Rahmen fehlt " .. tostring(step.hover), "") else
            local r = L.Rect(f)
            if r then W.cursor = { r[1] + r[3] / 2, r[2] + r[4] / 2 } end
            W.mouseFocus = f
            W.hovered = W.hovered or {}
            W.hovered[f] = true
            W.Fire(f, "OnEnter", true)
        end
    end
    if step.leave then
        local f = find(step.leave)
        if f then
            if W.hovered then W.hovered[f] = nil end
            W.Fire(f, "OnLeave", true)
        end
    end
end

-- Slash-Befehl wie aus dem Chat: SLASH_<NAME>1.. -> SlashCmdList[NAME].
function S.Slash(line)
    local cmd, rest = line:match("^(/%S+)%s*(.-)$")
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" and v:lower() == cmd:lower() then
            local name = k:match("^SLASH_(.-)%d+$")
            local fn = SlashCmdList and SlashCmdList[name]
            if fn then R.Call(fn, rest) return end
        end
    end
    R.Error("Slash-Befehl unbekannt: " .. cmd, "")
end

-- Ausschnitt: Rechteck in Pixeln oder Rahmen(+Rand).
function S.ResolveCrop(crop)
    if not crop then return nil end
    if crop == "auto" then return "auto" end -- Zeichner nimmt die Huelle aller Elemente
    if crop.rect then return crop.rect end
    local frames = crop.frames or { crop.frame }
    local x0, y0, x1, y1
    for _, name in ipairs(frames) do
        local f = find(name)
        local r = f and L.Rect(f)
        if r then
            local x, y, w, h = L.PixelRect(r)
            x0 = math.min(x0 or x, x) y0 = math.min(y0 or y, y)
            x1 = math.max(x1 or x + w, x + w) y1 = math.max(y1 or y + h, y + h)
        else
            R.Note("Ausschnitt: Rahmen fehlt oder ohne Rechteck " .. tostring(name))
        end
    end
    if not x0 then return nil end
    local pad = crop.pad or 16
    return { x0 - pad, y0 - pad, x1 - x0 + 2 * pad, y1 - y0 + 2 * pad }
end

return S
