-- Orte und Ladelisten. Pfade sind Stephans Arbeitskopien; das Grafik-Archiv
-- liegt bewusst ausserhalb jedes Repos (Blizzard-Grafik, urheberrechtlich geschuetzt).
local U = require("util")

local C = {}
local HOME = os.getenv("HOME")
local DOCS = HOME .. "/Dokumente"
C.UI_SOURCE_ROOT = os.getenv("FOREVER_UI_SOURCE") or (DOCS .. "/wow-ui-source")
C.ART_ROOT = os.getenv("FOREVER_ART") or (DOCS .. "/wow-ui-source/art")
-- Forever-Linie: Schnappschuesse heissen 1.60.1.<build>.
C.FOREVER_PREFIX = "1.60.1."
-- Stephans Spielbilder sind 3440x1440 bei uiScale 0.77.
C.DEFAULT_SCREEN = { 3440, 1440 }

C.ADDONS = {
    ForeverUnitFrames = DOCS .. "/ForeverUnitFrames",
    ForeverQuestLog = DOCS .. "/ForeverQuestLog",
    ForeverCombatMeter = DOCS .. "/ForeverCombatMeter",
    ForeverDataBar = DOCS .. "/ForeverDataBar",
    ForeverGroupFinder = DOCS .. "/ForeverGroupFinder",
    ForeverSquareMinimap = DOCS .. "/ForeverSquareMinimap",
    ForeverConsumables = DOCS .. "/ForeverConsumables",
    ForeverProgressBars = DOCS .. "/ForeverProgressBars",
    InfoPanel = DOCS .. "/ForeverInfoPanel/InfoPanel",
    ScreenBackdrop = DOCS .. "/wow_addons_tbc/ScreenBackdrop",
}

local function newest(root, filter)
    local best, bestBuild
    for _, name in ipairs(U.listDir(root)) do
        local build = name:match("^" .. C.FOREVER_PREFIX:gsub("%.", "%%.") .. "(%d+)$")
        if build and (not filter or filter(root .. "/" .. name)) then
            if not bestBuild or tonumber(build) > bestBuild then best, bestBuild = root .. "/" .. name, tonumber(build) end
        end
    end
    return best
end

function C.UiSource()
    return assert(newest(C.UI_SOURCE_ROOT), "kein Forever-UI-Quelltext unter " .. C.UI_SOURCE_ROOT)
end

function C.ArtDir()
    return newest(C.ART_ROOT, function(p) return U.exists(p .. "/index.tsv") end)
end

-- Blizzard-Code, der wirklich geladen wird (samt Abhaengigkeiten).
-- Stephans echte SavedVariables (nur gelesen, nie ins Repo): Konto-Ordner
-- wird zur Laufzeit gesucht, damit kein Kontoname im Code steht.
C.WTF_ACCOUNT_ROOT = HOME .. "/Games/Battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/WTF/Account"

function C.WtfSavedDir()
    for _, name in ipairs(U.listDir(C.WTF_ACCOUNT_ROOT)) do
        local dir = C.WTF_ACCOUNT_ROOT .. "/" .. name .. "/SavedVariables"
        if name ~= "SavedVariables" and U.exists(dir) then return dir end
    end
    return nil
end

C.BLIZZARD_ADDONS = {
    "Blizzard_SharedXMLBase",
    "Blizzard_Fonts_Shared",
    "Blizzard_SharedXML",
    "Blizzard_SharedXMLGame",
    "Blizzard_FrameXMLUtil",
    "Blizzard_RestrictedAddOnEnvironment",
    "Blizzard_GameTooltip",
    "Blizzard_UIPanelTemplates",
    "Blizzard_AuraContainer",
    "Blizzard_FrameXML",
    "Blizzard_Minimap",
}
-- Abhaengigkeiten, die nur Spielfenster bauen, die kein Addon braucht.
C.BLIZZARD_SKIP = {
    Blizzard_ScriptErrors = true,
}
-- Von FrameXML nur die Vorlagen, nicht seine ~60 Abhaengigkeiten (Spielfenster).
C.BLIZZARD_NODEPS = { Blizzard_FrameXML = true, Blizzard_Minimap = true }
-- Von grossen Addons nur einzelne Dateien.
C.BLIZZARD_ONLY = {
    Blizzard_FrameXML = { "SecureTemplates.lua", "SecureTemplates.xml", "DeprecatedTemplates.xml" },
}

return C
