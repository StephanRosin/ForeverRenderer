-- Forever Unit Frames: Raid-Testmodus (Attrappen statt echter Gruppe).
return { addons = { "ForeverUnitFrames" }, uiScale = 0.77, crop = "auto", state = require("_data").Full(),
    steps = { { call = "ForeverUnitFrames:RaidTestMode.Set", args = { true } }, { advance = 0.5 } } }
