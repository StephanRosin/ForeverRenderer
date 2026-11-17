-- ForeverLootFinder: the sticky note alone (the window never opened), then the
-- theme switched to Pitwall: the note follows.
local base = require("ForeverLootFinder/shopping")
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = base.state,
    steps = { { advance = 0.3 }, { run = function()
        local ns = require("loader").namespaces.ForeverLootFinder
        ns.Shopping.Add(990001, 1)
        ns.Shopping.Add(990006, 3)
        ns.ShoppingUI.ShowNote(true)
    end }, { advance = 0.3 }, { run = function()
        require("loader").namespaces.ForeverLootFinder.Settings.Set("theme", "PITWALL")
    end }, { advance = 0.3 } },
}
