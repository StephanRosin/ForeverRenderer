-- ForeverQuestLog: Optionsseite "abandoned" mit zwei abgebrochenen Quests (erfundene Titel).
return {
    extends = "ForeverQuestLog/options",
    steps = {
        { call = "ForeverQuestLog:Abandoned.Add", args = { { id = 90001, title = "Raptor Trouble", level = 33,
            zone = "Stranglethorn Vale", mapID = 1434, x = 0.42, y = 0.65 } } },
        { call = "ForeverQuestLog:Abandoned.Add", args = { { id = 90002, title = "Lost Supplies", level = 30,
            zone = "Duskwood" } } },
        { slash = "/fql" }, { advance = 0.3 },
        { call = "ForeverQuestLog:Window.ShowPage", args = { "abandoned" } }, { advance = 0.5 },
    },
}
