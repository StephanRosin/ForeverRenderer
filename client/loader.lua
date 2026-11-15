-- Laedt Blizzard-UI-Code und unsere Addons wie der Client: TOC-Reihenfolge,
-- Ladebedingungen, Namespace je Addon, XML, SavedVariables, ADDON_LOADED.
local U = require("util")
local R = require("report")
local X = require("xml")
local E = require("events")
local W = require("widgets")

local Ld = { loaded = {}, toc = {}, order = {} }

-- Forever ist "camelot" und laedt auch die Mainline-Dateien (siehe
-- Blizzard_FrameXML.toc: InstanceDifficulty [mainline] + Camelot-Override).
local GAME_TYPES = { mainline = true, camelot = true }
local PATH_VARS = { Family = "Mainline", Game = "Camelot" }

local function allowed(cond)
    for tag, args in cond:gmatch("%[(%w+)%s*([^%]]*)%]") do
        if tag == "AllowLoadGameType" then
            local ok = false
            for t in args:gmatch("[%w]+") do if GAME_TYPES[t] then ok = true end end
            if not ok then return false end
        elseif tag == "ExcludeLoadGameType" then
            for t in args:gmatch("[%w]+") do if GAME_TYPES[t] then return false end end
        elseif tag == "AllowLoad" then
            if args:find("Glue") and not args:find("Game") and not args:find("Both") then return false end
        elseif tag == "AllowLoadTextLocale" or tag == "AllowLoadLocale" then
            if not args:find("enUS") then return false end
        end
    end
    return true
end
Ld.Allowed = allowed

function Ld.ParseToc(path)
    local text = U.readFile(path)
    if not text then return nil end
    local toc = { meta = {}, files = {}, path = path, dir = path:match("^(.*)/[^/]+$") }
    text = text:gsub("^\239\187\191", "")
    for line in text:gmatch("[^\r\n]+") do
        local key, val = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if key then
            -- Schluessel koennen selbst Bedingungen tragen ("## Dep: X [AllowLoadGameType mainline]").
            local cond = val:match("(%[.*%])%s*$") or ""
            if allowed(cond) then
                val = val:gsub("%s*%[.*%]%s*$", "")
                local prev = toc.meta[key]
                toc.meta[key] = prev and (prev .. ", " .. val) or val
            end
        elseif not line:match("^%s*#") and line:match("%S") then
            local file, cond = line:match("^%s*(.-)%s*(%[.*%])%s*$")
            if not file then file, cond = U.trim(line), "" end
            if cond:find("^%[Family%]") or cond:find("^%[Game%]") then file, cond = line:match("^%s*(%S+)%s*(.-)%s*$") end
            if allowed(cond) then
                file = file:gsub("%[(%w+)%]", function(v) return PATH_VARS[v] or v end)
                toc.files[#toc.files + 1] = file:gsub("\\", "/")
            end
        end
    end
    return toc
end

-- Laedt eine Lua-Datei mit (addonName, ns) wie der Client; Fehler sammeln.
function Ld.RunLua(path, addonName, ns)
    local chunk, err = loadfile(path)
    if not chunk then
        R.Error(err or ("Datei fehlt: " .. path), "")
        return
    end
    R.Call(chunk, addonName, ns)
end

function Ld.LoadFiles(toc, addonName, ns)
    local M = require("media")
    for _, f in ipairs(toc.files) do
        local path = toc.dir .. "/" .. M.CaseInsensitive(toc.dir, f)
        if f:lower():match("%.xml$") then
            X.LoadFile(path, function(p) Ld.RunLua(p, addonName, ns) end)
        elseif f:lower():match("%.lua$") then
            Ld.RunLua(path, addonName, ns)
        end
    end
end

-- Blizzard: eine Liste von Addons samt Abhaengigkeiten (ausser denen in skip).
function Ld.LoadBlizzard(uiSource, name, opts)
    if Ld.loaded[name] then return end
    Ld.loaded[name] = true
    local toc = Ld.ParseToc(uiSource .. "/" .. name .. "/" .. name .. ".toc")
    if not toc then
        R.Note("Blizzard-Addon fehlt: " .. name)
        return
    end
    local deps = (toc.meta.Dependencies or "") .. "," .. (toc.meta.Dep or "") .. "," .. (toc.meta.RequiredDep or "")
    for dep in deps:gmatch("[^,%s]+") do
        if not opts.skip[dep] and not (opts.nodeps and opts.nodeps[name]) then Ld.LoadBlizzard(uiSource, dep, opts) end
    end
    local only = opts.only and opts.only[name]
    if only then
        local keep = {}
        for _, f in ipairs(toc.files) do
            for _, want in ipairs(only) do
                if f == want then keep[#keep + 1] = f end
            end
        end
        toc.files = keep
    end
    Ld.toc[name] = toc
    Ld.LoadFiles(toc, name, {})
end

-- SavedVariables aus dem Szenario: Lua-Tabellen, die vor ADDON_LOADED als
-- Globale bereitstehen (wie aus WTF gelesen).
function Ld.LoadAddon(dir, name, saved)
    local tocPath
    for _, f in ipairs(U.listDir(dir)) do
        if f:lower() == (name .. ".toc"):lower() then tocPath = dir .. "/" .. f end
    end
    local toc = tocPath and Ld.ParseToc(tocPath)
    if not toc then
        R.Error("TOC fehlt: " .. dir .. "/" .. name .. ".toc", "")
        return
    end
    Ld.toc[name] = toc
    Ld.order[#Ld.order + 1] = name
    for var in ((toc.meta.SavedVariables or "") .. "," .. (toc.meta.SavedVariablesPerCharacter or "")):gmatch("[^,%s]+") do
        if saved and saved[var] ~= nil then rawset(_G, var, saved[var]) end
    end
    local ns = {}
    Ld.LoadFiles(toc, name, ns)
    Ld.loaded[name] = true
    E.Fire("ADDON_LOADED", name, false)
    return ns
end

return Ld
