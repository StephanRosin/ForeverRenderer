-- Kopfloser Client: luajit client/main.lua <szenario.lua> <ausgabe.json>
-- Laedt Blizzards UI-Grundlagen und die Addons des Szenarios, spielt die
-- Szenario-Schritte ab und schreibt Zeichenliste plus Bericht als JSON.
local CLIENT_DIR = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = CLIENT_DIR .. "/?.lua;" .. CLIENT_DIR .. "/api/?.lua;" .. package.path

local U = require("util")
local R = require("report")
local L = require("layout")
local W = require("widgets")
require("frames")
local E = require("events")
local Media = require("media")
local Docs = require("docs")
local Env = require("env")
local Ld = require("loader")
local Draw = require("draw")
local Config = require("config")

local scenarioPath, outPath = arg[1], arg[2]
if not scenarioPath or not outPath then
    io.stderr:write("Aufruf: luajit client/main.lua <szenario.lua> <ausgabe.json>\n")
    os.exit(2)
end

local scn = assert(dofile(scenarioPath), "Szenario liefert keine Tabelle")
-- extends = "compare/_base": Felder des Basisszenarios, eigene gewinnen.
if scn.extends then
    local base = assert(dofile(Config.ROOT .. "/scenarios/" .. scn.extends .. ".lua"), "Basisszenario fehlt")
    for k, v in pairs(base) do if scn[k] == nil then scn[k] = v end end
end
local screen = scn.screen or Config.DEFAULT_SCREEN
L.SetScreen(screen[1], screen[2])

for name, dir in pairs(Config.ADDONS) do
    Media.AddAddonDir(name, dir)
    R.AddRoot(dir, name)
end
local art = Config.ArtDir()
if not art or not Media.LoadArt(art) then R.Note("Grafik-Archiv fehlt (tools/extract-art): Blizzard-Texturen und -Schriften fehlen") end

local uiSource = Config.UiSource()
local docs = Docs.Load(uiSource)
for _, e in ipairs(docs.loadErrors) do R.Note("API-Doku: " .. e) end
docs.ScanEvents(uiSource)
Env.Install(docs, scn)

-- Spielzustand des Szenarios (Einheiten, Gruppe, Auren, Geld ...).
local State = require("state")
State.Install(scn.state or {}, Env)

R.phase = "blizzard"
W.loadingBlizzard = true
for _, name in ipairs(Config.BLIZZARD_ADDONS) do
    Ld.LoadBlizzard(uiSource, name, { skip = Config.BLIZZARD_SKIP, only = Config.BLIZZARD_ONLY, nodeps = Config.BLIZZARD_NODEPS })
end
W.loadingBlizzard = false
if State.AfterBlizzard then State.AfterBlizzard() end

R.phase = "addons"
-- SavedVariables: aus dem Szenario (saved = { Addon = { Var = ... } }) oder
-- mit wtf = true aus Stephans Konto-Ordner (nur kontoweite Dateien).
local function savedFor(name)
    local out = {}
    if scn.wtf then
        local dirs = { Config.WtfSavedDir(), Config.WtfCharSavedDir() }
        if not dirs[1] then R.Note("WTF-Ordner nicht gefunden") end
        for _, dir in ipairs(dirs) do
            local src = U.readFile(dir .. "/" .. name .. ".lua")
            local chunk = src and loadstring(src, "=WTF/" .. name)
            if chunk then
                local env = {}
                setfenv(chunk, env)
                if pcall(chunk) then for k, v in pairs(env) do out[k] = v end end
            end
        end
    end
    for k, v in pairs(scn.saved and scn.saved[name] or {}) do out[k] = v end
    return out
end

for _, name in ipairs(scn.addons or {}) do
    local dir = Config.ADDONS[name]
    if not dir then R.Error("Addon unbekannt: " .. name, "") else Ld.LoadAddon(dir, name, savedFor(name)) end
end

-- Anmeldung wie im Client.
E.Fire("VARIABLES_LOADED")
E.Fire("PLAYER_LOGIN")
E.Fire("PLAYER_ENTERING_WORLD", true, false)
if State.AfterLogin then State.AfterLogin() end
E.Advance(scn.settle or 1)

R.phase = "scenario"
local Steps = require("steps")
if scn.theme then Steps.Theme(scn.theme, scn.color) E.Advance(0.5) end
for _, step in ipairs(scn.steps or {}) do Steps.Run(step, scn) end
E.Advance(scn.settleAfter or 0.5)

local items = Draw.Collect()
local out = {
    screen = { L.physW, L.physH },
    uiScale = scn.uiScale or 1,
    items = items,
    report = R.Summary(),
    crop = Steps.ResolveCrop(scn.crop),
    background = scn.background,
    addons = scn.addons,
}
U.writeFile(outPath, U.encode(out))
