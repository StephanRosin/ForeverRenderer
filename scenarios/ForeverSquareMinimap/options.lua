-- ForeverSquareMinimap: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverSquareMinimap" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/squareminimap" }, { advance = 0.5 } },
}
