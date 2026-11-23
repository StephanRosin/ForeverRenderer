-- ForeverLootFinder: a German druid, the widest spec row (four specs, "Wiederherstellung").
local base = dofile(debug.getinfo(1, "S").source:sub(2):gsub("druid_de%.lua$", "classic.lua"))
base.state.units.player.class = "DRUID"
base.state.locale = "deDE"
return base
