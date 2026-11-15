-- ForeverDataBar mit vollem, erfundenem Spielstand (scenarios/_data.lua).
return {
    addons = { "ForeverDataBar" },
    uiScale = 0.77,
    crop = "auto",

    state = require("_data").Full(),
}
