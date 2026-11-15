-- ForeverCombatMeter: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverCombatMeter" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fcm" }, { advance = 0.5 } },
}
