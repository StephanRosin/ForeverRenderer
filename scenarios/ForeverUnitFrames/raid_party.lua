-- ForeverUnitFrames: Fuenfergruppe in der Raid-Ansicht (Profil Party),
-- Raid-Fenster offen auf dem gezeigten Profil.
local D = require("_data")
return {
    addons = { "ForeverUnitFrames" },
    uiScale = 0.77,
    crop = "auto",
    state = D.Group(D.Full()),
    steps = {
        { call = "ForeverUnitFrames:RaidConfig.Set", args = { "general", "showInParty", true } },
        { advance = 0.5 },
        { call = "ForeverUnitFrames:RaidOptions.Open" },
        { advance = 0.5 },
    },
}
