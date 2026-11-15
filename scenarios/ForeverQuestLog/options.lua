-- ForeverQuestLog: Optionsfenster (erster Reiter) ueber den Slash-Befehl.
return {
    addons = { "ForeverQuestLog" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fql" }, { advance = 0.5 } },
}
