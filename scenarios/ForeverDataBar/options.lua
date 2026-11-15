-- ForeverDataBar: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverDataBar" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fdb" }, { advance = 0.5 } },
}
