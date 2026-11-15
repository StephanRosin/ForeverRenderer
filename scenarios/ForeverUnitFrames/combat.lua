-- Forever Unit Frames im Kampf: Ziel castet, Spieler angeschlagen.
local D = require("_data")
local s = D.Full()
s.combat = true
s.units.player.combat = true
s.units.player.threat = 3
return { addons = { "ForeverUnitFrames" }, uiScale = 0.77, crop = "auto", state = s,
    steps = { { event = "PLAYER_REGEN_DISABLED" }, { advance = 0.5 } } }
