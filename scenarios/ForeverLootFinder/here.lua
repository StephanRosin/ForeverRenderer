-- ForeverLootFinder: inside the Ember Halls, "Only Ember Halls" on: its bosses' loot only.
local base = require("ForeverLootFinder/classic")
local s = base.state
s.zone, s.instance = "Ember Halls", "party"
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = s,
    steps = { { run = function()
        require("loader").namespaces.ForeverLootFinder.Settings.Set("filterHere", true)
    end }, { call = "ForeverLootFinder:Window.Open" }, { advance = 0.5 } },
}
