-- ForeverLootFinder: the shopping list tab, three items (one in the bags
-- already), and its sticky note beside the window.
local s = require("_data").Full()
s.units.player.level = 60
s.items = require("ForeverLootFinder/_items")
s.items[990001].count = 1
s.items[990006].count = 1
return {
    addons = { "AtlasLootClassic", "AtlasLootClassic_DungeonsAndRaids", "AtlasLootClassic_Crafting", "ForeverDungeonJournal", "ForeverLootFinder" },
    uiScale = 0.77,
    crop = "auto",
    state = s,
    steps = { { call = "ForeverLootFinder:Window.Open" }, { advance = 0.3 }, { run = function()
        local ns = require("loader").namespaces.ForeverLootFinder
        ns.Shopping.Add(990001, 1)
        ns.Shopping.Add(990006, 3)
        ns.Shopping.Add(990003, 1)
        ns.Window.ShowTab("shop")
        ns.ShoppingUI.ShowNote(true)
    end }, { advance = 0.3 } },
}
