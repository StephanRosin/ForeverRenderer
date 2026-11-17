-- ForeverLootFinder: in the Sunken Vault (its ring framed on the note), the
-- add dialog searching "ring".
local base = require("ForeverLootFinder/shopping")
local s = base.state
s.zone, s.instance = "Sunken Vault", "party"
return {
    addons = base.addons, uiScale = base.uiScale, crop = "auto", state = s,
    steps = { base.steps[1], base.steps[2], base.steps[3], { advance = 0.2 }, { run = function()
        local ns = require("loader").namespaces.ForeverLootFinder
        ns.ShoppingUI.OpenAdd()
        local d = _G.ForeverLootFinderShoppingAdd
        d.search:SetText("ring")
        d.search:GetScript("OnTextChanged")(d.search, true)
    end }, { advance = 0.3 } },
}
