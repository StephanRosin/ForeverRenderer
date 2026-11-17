-- ForeverLootFinder: "Only Ember Halls" and "Better than worn": the upgrades that drop here.
local base = require("ForeverLootFinder/classic")
local s = base.state
s.zone, s.instance = "Ember Halls", "party"
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = s,
    steps = { { run = function()
        require("loader").namespaces.ForeverLootFinder.Settings.Set("filterHere", true); require("loader").namespaces.ForeverLootFinder.Settings.Set("filterBetter", true)
    end }, { call = "ForeverLootFinder:Window.Open" }, { advance = 0.5 } },
}
