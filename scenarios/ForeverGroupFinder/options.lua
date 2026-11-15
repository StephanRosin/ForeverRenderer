-- ForeverGroupFinder: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverGroupFinder" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fgf" }, { advance = 0.5 } },
}
