-- ForeverConsumables: Optionsfenster, Reiter Anzeige (Zaehler, Auswahl).
return {
    extends = "ForeverConsumables/options",
    steps = { { slash = "/fcon" }, { advance = 0.2 }, { call = "ForeverConsumables:Window.ShowPage", args = { 4 } }, { advance = 0.3 } },
}
