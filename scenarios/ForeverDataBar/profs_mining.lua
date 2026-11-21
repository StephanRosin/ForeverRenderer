-- ForeverDataBar: Bergbau-Tooltip mit Adern und Verhütten, die noch Skillpunkte geben (dataBarSkillUps).
local state = require("_data").Full()
state.skills = {
    { name = "Professions", isHeader = true },
    { name = "Mining", rank = 112, maxRank = 150, skillID = 186 },
    { name = "Herbalism", rank = 160, maxRank = 225, skillID = 182 },
    { name = "Secondary Skills", isHeader = true },
    { name = "Cooking", rank = 225, maxRank = 300, skillID = 185 },
}
return {
    addons = { "ForeverDataBar" },
    uiScale = 0.77,
    crop = "auto",
    state = state,
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarSkillUps = true } } },
    steps = {
        { advance = 1.2 },
        { run = function() _G.FDBFirstProf = ForeverDataBarFrame.profs[1] end },
        { hover = "FDBFirstProf" },
        { advance = 1 },
    },
}
