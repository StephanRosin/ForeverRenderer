-- ForeverUnitFrames: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverUnitFrames" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fuf" }, { advance = 0.5 } },
}
