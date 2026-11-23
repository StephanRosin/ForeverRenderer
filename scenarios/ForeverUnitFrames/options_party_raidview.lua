-- ForeverUnitFrames: Optionsfenster, Party > Group, gescrollt bis zum
-- Abschnitt Raid view (Schalter der Raid-Ansicht in der Gruppe).
return {
    extends = "ForeverUnitFrames/options",
    steps = {
        { call = "ForeverUnitFrames:Options.Reveal", args = { { scope = "party", tab = "group", key = "showInParty" } } },
        { advance = 0.5 },
    },
}
