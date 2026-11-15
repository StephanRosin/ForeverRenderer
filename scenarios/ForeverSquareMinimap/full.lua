-- ForeverSquareMinimap mit vollem, erfundenem Spielstand (scenarios/_data.lua).
return {
    addons = { "ForeverSquareMinimap" },
    uiScale = 0.77,
    crop = "auto",
    drawBlizzard = { "MinimapCluster" },
    state = require("_data").Full(),
}
