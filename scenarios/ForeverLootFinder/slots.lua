-- ForeverLootFinder: a slot picked in the window (selection mark on the slot row).

return {
    extends = "ForeverLootFinder/classic",
    steps = { { call = "ForeverLootFinder:Window.Open" }, { advance = 0.2 }, { run = function()
        local W = require("loader").namespaces.ForeverLootFinder.Window
        W.OpenSlot("SHOULDER", 3)
    end }, { advance = 0.3 } },
}
