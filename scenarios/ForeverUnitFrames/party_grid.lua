-- ForeverUnitFrames: Fuenfergruppe samt Spieler in zwei Spalten
-- (partyPerLine 2). FOREVER_PARTY_ORIENT=HORIZONTAL: zwei Zeilen;
-- FOREVER_PARTY_REVERSE=1: von unten (rechts) her.
local D = require("_data")
local steps = {
    { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyShowPlayer", true } },
    { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyPerLine", 2 } },
}
local orient = os.getenv("FOREVER_PARTY_ORIENT")
if orient then steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyOrientation", orient } } end
if os.getenv("FOREVER_PARTY_REVERSE") then
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyGrowReverse", true } }
end
-- FOREVER_PARTY_EXTRAS=1: Party-Targets rechts, Begleiter daneben.
if os.getenv("FOREVER_PARTY_EXTRAS") then
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyTargets", true } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyShowPets", true } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyPetLayout", "BESIDE" } }
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { "party", "partyPetSide", "LEFT" } }
end
steps[#steps + 1] = { advance = 0.5 }
return { addons = { "ForeverUnitFrames" }, uiScale = 0.77, crop = "auto", state = D.Group(D.Full()), steps = steps }
