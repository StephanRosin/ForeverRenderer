-- ForeverDataBar: Tooltip eines Abklingzeit-Symbols, nur der Tooltip ausgeschnitten.
local base = dofile("scenarios/ForeverDataBar/timed_tip.lua")
base.crop = { frames = { "ForeverDataBarTooltip", "GameTooltip" } }
return base
