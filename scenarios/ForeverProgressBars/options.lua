-- ForeverProgressBars: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverProgressBars" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fpb" }, { advance = 0.5 } },
}
