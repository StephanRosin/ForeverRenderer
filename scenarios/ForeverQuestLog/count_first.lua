-- ForeverQuestLog: Anzahl vor dem Ziel ("3/8 Laternenscherben"), Tracker und Fokusfenster.
return {
    addons = { "ForeverQuestLog" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = {
        { call = "ForeverQuestLog:Settings.Set", args = { "countFirst", true } },
        { call = "ForeverQuestLog:Settings.Set", args = { "focusCountFirst", true } },
        { advance = 0.2 },
    },
}
