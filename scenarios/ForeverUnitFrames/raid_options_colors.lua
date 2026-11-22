-- ForeverUnitFrames: Raid-Optionsfenster, Reiter Colors (geteilt mit den
-- Unit Frames), eigene Klassenfarben an.
return {
    addons = { "ForeverUnitFrames" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = {
        { call = "ForeverUnitFrames:Config.Set", args = { "general", "classColorsCustom", true } },
        { call = "ForeverUnitFrames:RaidOptions.Open", args = { nil, "colors" } },
        { advance = 0.5 },
    },
}
