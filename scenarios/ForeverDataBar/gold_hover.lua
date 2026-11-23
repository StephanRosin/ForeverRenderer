-- ForeverDataBar: Goldfenster (Übersicht), Maus über dem vorletzten Tag der Kurve: Punkt und Tooltip mit dem Betrag.
return {
    extends = "ForeverDataBar/gold",
    addons = { "ForeverDataBar" }, uiScale = 0.77, crop = "auto", -- extends wirkt nur eine Stufe tief
    steps = {
        { call = "ForeverDataBar:GoldWindow.Toggle" }, { advance = 0.5 },
        { run = function()
            local c = require("loader").namespaces.ForeverDataBar.GoldWindow.Frame().pages.OVERVIEW.chart
            local h = c.hover
            local s = c:GetEffectiveScale()
            require("widgets").cursor = { (c:GetLeft() + h.X(#h.points - 1)) * s, 0 }
            c:GetScript("OnEnter")(c)
            c:GetScript("OnUpdate")(c)
        end },
        { advance = 0.3 },
    },
}
