-- ForeverUnitFrames: Gruppe mit Rollensymbol am Portraet der Gruppenfenster
-- (groupRole + groupRolePortrait); FOREVER_PORTRAIT=LEFT|RIGHT|OFF statt
-- des Streifens oben (TOP). Eigene Groesse, Punkt und Versatz der Rolle:
-- FOREVER_ROLE_SIZE=28 FOREVER_ROLE_POINT=TOPLEFT FOREVER_ROLE_X=4 FOREVER_ROLE_Y=-4.
-- settle 16: ohne Spielstand lehnt FUF Themewechsel 15 s lang ab (FOREVER_THEME).
local mode = os.getenv("FOREVER_PORTRAIT") or "TOP"
local own = {
    groupRoleSize = tonumber(os.getenv("FOREVER_ROLE_SIZE") or ""),
    groupRolePortraitPoint = os.getenv("FOREVER_ROLE_POINT"),
    groupRoleX = tonumber(os.getenv("FOREVER_ROLE_X") or ""),
    groupRoleY = tonumber(os.getenv("FOREVER_ROLE_Y") or ""),
}
local steps = {}
local function set(scope, key, value)
    steps[#steps + 1] = { call = "ForeverUnitFrames:Config.Set", args = { scope, key, value } }
end
for _, scope in ipairs({ "player", "party" }) do
    set(scope, "portraitMode", mode)
    set(scope, "groupRole", true)
    set(scope, "groupRolePortrait", true)
    for _, key in ipairs({ "groupRoleSize", "groupRolePortraitPoint", "groupRoleX", "groupRoleY" }) do
        if own[key] ~= nil then set(scope, key, own[key]) end
    end
end
steps[#steps + 1] = { advance = 0.5 }
return { extends = "ForeverUnitFrames/group", settle = 16, steps = steps }
