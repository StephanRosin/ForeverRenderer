-- ForeverLootFinder: the sticky note minimised to its title.
local base = require("ForeverLootFinder/shopping")
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = base.state,
    steps = { base.steps[1], base.steps[2], base.steps[3], { advance = 0.2 }, { run = function()
        local note = _G.ForeverLootFinderShoppingNote
        note.fold:GetScript("OnClick")(note.fold)
    end }, { advance = 0.3 } },
}
