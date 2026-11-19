-- ForeverUnitFrames: Zielfenster als Spiegelbild des Spielerfensters
-- (barReverse), mit Ueberheilungsspur; der Testmodus zeigt Heilung und Schild.
-- FOREVER_REVERSE=0 zeigt dasselbe ungespiegelt (Vergleich).
local reverse = os.getenv("FOREVER_REVERSE") ~= "0"
local steps = {}
for _, scope in ipairs({ "player", "target" }) do
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, "healOverflow", true } }
end
steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "target", "barReverse", reverse } }
steps[#steps + 1] = { call = "ForeverUnitFrames:TestMode.Set", args = { true } }
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/full", settle = 16, steps = steps }
