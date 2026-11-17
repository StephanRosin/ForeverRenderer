-- ForeverDataBar: alle Nebenberufe sichtbar (Erste Hilfe, Kochen, Angeln eingeblendet).
local s = require("_data").Full()
table.insert(s.skills, { name = "Fishing", rank = 150, maxRank = 300, skillID = 356 })

return {
    extends = "ForeverDataBar/full",
    state = s,
    saved = { ForeverDataBar = { ForeverDataBarChar = { hidden = { Fishing = false } } } },
}
