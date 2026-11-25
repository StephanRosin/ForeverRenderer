-- ForeverProgressBars mit drei angehakten Nebenberufen (Angeln eingeblendet).
local state = require("_data").Full()
table.insert(state.skills, { name = "Fishing", rank = 150, maxRank = 300, skillID = 356 })
return {
    addons = { "ForeverProgressBars" },
    uiScale = 0.77,
    crop = "auto",
    state = state,
    saved = { ForeverProgressBars = {
        ForeverProgressBarsProfiles = { profiles = { Default = { hidden = { Fishing = false } } } },
        ForeverProgressBarsChar = { active = "Default" },
    } },
}
