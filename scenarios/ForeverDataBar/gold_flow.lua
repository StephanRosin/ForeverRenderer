-- ForeverDataBar: das Goldfenster mit den Daten aus gold.lua, Reiter FLOW.
return {
    extends = "ForeverDataBar/gold",
    addons = { "ForeverDataBar" }, uiScale = 0.77, crop = "auto", -- extends wirkt nur eine Stufe tief
    steps = { { call = "ForeverDataBar:GoldWindow.Toggle" }, { call = "ForeverDataBar:GoldWindow.ShowTab", args = { "FLOW" } },
        { advance = 0.5 } },
}
