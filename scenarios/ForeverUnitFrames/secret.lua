-- Forever Unit Frames mit geheimen Werten (wie im Kampf in Instanzen):
-- Leben, Kraft und Name von Ziel und Gruppe kommen als Secret.
local D = require("_data")
local s = D.Group(D.Full())
s.combat = true
s.secretAll = { health = true, healthMax = true, power = true, powerMax = true }
return { addons = { "ForeverUnitFrames" }, uiScale = 0.77, crop = "auto", state = s,
    steps = { { event = "PLAYER_REGEN_DISABLED" }, { advance = 0.5 } } }
