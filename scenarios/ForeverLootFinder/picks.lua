-- ForeverLootFinder: Rechtsklick auf "Dungeons": Menü mit allen Dungeons, zwei gewählt (Mehrfachauswahl).
local base = require("ForeverLootFinder/classic")
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = base.state,
    steps = { { call = "ForeverLootFinder:Window.Open" }, { advance = 0.5 }, { run = function()
        local ns = require("loader").namespaces.ForeverLootFinder
        local names = ns.Source.Instances(false)
        ns.Settings.Set("pickDungeons", { [names[1] or "?"] = true, [names[2] or "?"] = true })
        local chip = ForeverLootFinderWindow.sourceChips[1]
        chip:GetScript("OnClick")(chip, "RightButton")
    end }, { advance = 0.3 } },
}
