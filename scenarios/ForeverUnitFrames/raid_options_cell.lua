-- ForeverUnitFrames: Raid-Optionsfenster, Profil 10, Reiter Cell
-- (Groesse, Leisten, Form, Heilung und Schilde).
return {
    addons = { "ForeverUnitFrames" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = {
        { call = "ForeverUnitFrames:RaidOptions.Open", args = { 10, "cell" } },
        { advance = 0.5 },
    },
}
