-- ForeverLootFinder: the sticky note's "+" hovered: its tooltip sits under the title.
local base = require("ForeverLootFinder/shopping")
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = base.state,
    steps = { base.steps[1], base.steps[2], base.steps[3], { advance = 0.2 }, { run = function()
        local b = _G.ForeverLootFinderShoppingNote.add
        b:GetScript("OnEnter")(b)
    end }, { advance = 0.3 } },
}
