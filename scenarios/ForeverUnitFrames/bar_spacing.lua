-- ForeverUnitFrames: Spieler- und Zielfenster mit Portraet links und Abstand
-- zwischen den Leisten (barSpacing); FOREVER_SPACING=0 zeigt das Fenster ohne.
-- settle 16: ohne Spielstand lehnt FUF Themewechsel 15 s lang ab (FOREVER_THEME).
local spacing = tonumber(os.getenv("FOREVER_SPACING") or "4")
local steps = {}
for _, scope in ipairs({ "player", "target" }) do
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitMode", "LEFT" } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "barSpacing", spacing } }
end
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/full", settle = 16, steps = steps }
