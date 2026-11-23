-- ForeverLootFinder: a German paladin, the widest spec row (four specs, "Wiederherstellung").
local base = dofile(debug.getinfo(1, "S").source:sub(2):gsub("paladin_de%.lua$", "classic.lua"))
base.state.units.player.class = "PALADIN"
base.state.locale = "deDE"
return base
