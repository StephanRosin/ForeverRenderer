-- ForeverQuestLog: Fokusfenster mit Knopf fuer den Questgegenstand der fokussierten Quest.
local state = require("_data").Full()
for _, q in ipairs(state.quests) do
    if q.questID == 90001 then q.item = { link = "|cffffffff|Hitem:6948::::::::|h[Hearthstone]|h|r", icon = 134414, charges = 1 } end
end
return {
    addons = { "ForeverQuestLog" },
    uiScale = 0.77,
    crop = "auto",
    state = state,
}
