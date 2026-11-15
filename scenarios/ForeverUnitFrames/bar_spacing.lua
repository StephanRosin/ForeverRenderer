-- ForeverUnitFrames: Spieler- und Zielfenster mit Portraet links, die Teile
-- auseinander (spacing*). Abstaende aus FOREVER_GAP_TITLE, _POWER,
-- _PORTRAIT, _DOCKED (Vorgabe 2, 4, 6, 3); FOREVER_SPACING=0 setzt alle auf 0
-- (das Fenster ohne). Rand der Kaesten: FOREVER_BOX_SIZE, FOREVER_BOX_COLOR
-- ("r,g,b" 0..1), FOREVER_BOX_RADIUS.
-- settle 16: ohne Spielstand lehnt FUF Themewechsel 15 s lang ab (FOREVER_THEME).
local function num(name, default)
    if os.getenv("FOREVER_SPACING") == "0" and name:find("^FOREVER_GAP_") then return 0 end
    return tonumber(os.getenv(name) or "") or default
end
local gaps = {
    spacingTitle = num("FOREVER_GAP_TITLE", 2), spacingPower = num("FOREVER_GAP_POWER", 4),
    spacingPortrait = num("FOREVER_GAP_PORTRAIT", 6), spacingDocked = num("FOREVER_GAP_DOCKED", 3),
}
local steps = {}
local function set(scope, key, value)
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, key, value } }
end
for _, scope in ipairs({ "player", "target" }) do
    set(scope, "portraitMode", "LEFT")
    for key, value in pairs(gaps) do set(scope, key, value) end
    if os.getenv("FOREVER_BOX_SIZE") then set(scope, "boxBorderSize", num("FOREVER_BOX_SIZE", 1)) end
    if os.getenv("FOREVER_BOX_RADIUS") then set(scope, "boxCornerRadius", num("FOREVER_BOX_RADIUS", 0)) end
    local color = os.getenv("FOREVER_BOX_COLOR")
    if color then
        local r, g, b = color:match("([%d.]+),([%d.]+),([%d.]+)")
        set(scope, "boxBorderColor", { tonumber(r), tonumber(g), tonumber(b), 1 })
    end
end
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/full", settle = 16, steps = steps }
