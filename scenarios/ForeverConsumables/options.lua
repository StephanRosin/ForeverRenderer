-- ForeverConsumables: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverConsumables" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fcon" }, { advance = 0.5 } },
}
