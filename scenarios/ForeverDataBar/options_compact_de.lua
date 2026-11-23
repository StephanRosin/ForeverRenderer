-- ForeverDataBar: Optionsseite "Elemente" auf Deutsch, beim Ruf (Schalter "Kompakt").
local base = dofile("scenarios/ForeverDataBar/options_parts.lua")
base.state.locale = "deDE"
base.steps[#base.steps + 1] = { run = function() ForeverDataBarOptionsScroll:SetVerticalScroll(1900) end }
base.steps[#base.steps + 1] = { advance = 0.3 }
return base
