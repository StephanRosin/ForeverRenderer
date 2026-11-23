-- ForeverDataBar: Optionsseite "Elemente" (Spalte, Reihenfolge, Versatz je Teil).
return {
    addons = { "ForeverDataBar" },
    uiScale = 0.77,
    crop = "auto",
    state = require("_data").Full(),
    steps = { { slash = "/fdb" }, { advance = 0.5 }, { call = "ForeverDataBar:Window.ShowPage", args = { "parts" } },
        { advance = 0.5 } },
}
