-- ForeverUnitFrames: Spieler- und Zielfenster mit 2D-Portraet links, eckig
-- (portraitSquare); FOREVER_SQUARE=0 zeigt das runde zum Vergleich.
local square = os.getenv("FOREVER_SQUARE") ~= "0"
local steps = {}
for _, scope in ipairs({ "player", "target" }) do
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitMode", "LEFT" } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitStyle", "2D" } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "portraitSquare", square } }
end
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/full", steps = steps }
