-- ForeverDataBar: Optionsseite "Elemente" auf Deutsch, zu Berufe/Abklingzeiten gescrollt (Beschreibungen je Teil).
local base = dofile("scenarios/ForeverDataBar/options_parts.lua")
base.state.locale = "deDE"
base.steps[#base.steps + 1] = { run = function() ForeverDataBarOptionsScroll:SetVerticalScroll(1400) end }
base.steps[#base.steps + 1] = { advance = 0.3 }
return base
