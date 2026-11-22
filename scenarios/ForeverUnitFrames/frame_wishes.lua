-- ForeverUnitFrames: Spieler und Ziel mit 2D-Portraet, das des Ziels
-- gespiegelt (portraitMirror); Zauberleiste des Ziels frei und 320 breit
-- (castbarWidth); Lebenstexte des Spielers versetzt (textHealth*X/Y);
-- Debuffs des Ziels frei auf dem Bildschirm (debuffsAnchor FREE).
local steps = {}
for _, scope in ipairs({ "player", "target" }) do
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitMode", "LEFT" } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitStyle", "2D" } }
end
local function set(scope, key, value)
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, key, value } }
end
set("target", "portraitMirror", true)
set("target", "castbarPosition", "DETACHED")
set("target", "castbarWidth", 320)
set("player", "textHealthLeftY", 8)
set("player", "textHealthRightX", -20)
set("player", "textHealthRightY", -6)
set("target", "debuffsAnchor", "FREE")
set("target", "debuffsFreeX", 300)
set("target", "debuffsFreeY", 60)
steps[#steps + 1] = { call = "ForeverUnitFrames:TestMode.Set", args = { true } }
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/full", settle = 16, steps = steps }
