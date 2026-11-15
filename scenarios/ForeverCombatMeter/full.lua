-- ForeverCombatMeter mit vollem, erfundenem Spielstand (scenarios/_data.lua).
return {
    addons = { "ForeverCombatMeter" },
    uiScale = 0.77,
    crop = "auto",

    state = require("_data").Full(),
}
