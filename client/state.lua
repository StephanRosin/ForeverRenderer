-- Spielzustand aus dem Szenario: Einheiten, Gruppe, Auren, Geld, Quests,
-- Ruf, Berufe, Taschen, CVars. Die einzelnen Bereiche liegen in api/*.lua.
local S = {}

S.MODULES = { "core" }

function S.Install(state, env)
    S.state = state
    env.state = state
    for _, name in ipairs(S.MODULES) do
        local m = require(name)
        if m.Install then m.Install(state, env) end
    end
end

return S
