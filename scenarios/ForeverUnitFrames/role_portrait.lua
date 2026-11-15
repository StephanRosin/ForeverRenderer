-- ForeverUnitFrames: Gruppe mit Rollensymbol am Portraet der Gruppenfenster
-- (groupRole + groupRolePortrait); FOREVER_PORTRAIT=LEFT|RIGHT|OFF statt
-- des Streifens oben (TOP).
-- settle 16: ohne Spielstand lehnt FUF Themewechsel 15 s lang ab (FOREVER_THEME).
local mode = os.getenv("FOREVER_PORTRAIT") or "TOP"
local steps = {}
for _, scope in ipairs({ "player", "party" }) do
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitMode", mode } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "groupRole", true } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "groupRolePortrait", true } }
end
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/group", settle = 16, steps = steps }
