-- ScreenBackdrop: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ScreenBackdrop" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/sbd" }, { advance = 0.5 } },
}
