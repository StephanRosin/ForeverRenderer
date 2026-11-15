-- ForeverQuestLog im Kampf.
local s = require("_data").Full()
s.combat = true
return { addons = { "ForeverQuestLog" }, uiScale = 0.77, crop = "auto", state = s,
    steps = { { event = "PLAYER_REGEN_DISABLED" }, { advance = 1 } } }
