-- InfoPanel: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "InfoPanel" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/infopanel" }, { advance = 0.5 } },
}
