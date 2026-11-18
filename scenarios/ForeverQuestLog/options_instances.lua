-- ForeverQuestLog: Optionsseite "instances" (Sichtbarkeitsregeln bzw. Fokus folgt dem Fortschritt).
return {
    extends = "ForeverQuestLog/options",
    steps = {
        { slash = "/fql" }, { advance = 0.3 },
        { call = "ForeverQuestLog:Window.ShowPage", args = { "instances" } }, { advance = 0.5 },
    },
}
