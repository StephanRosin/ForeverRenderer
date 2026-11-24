-- ForeverUnitFrames: Optionsfenster, Party > Group, Abschnitt Anordnung.
return {
    extends = "ForeverUnitFrames/options",
    steps = {
        { call = "ForeverUnitFrames:Options.Reveal", args = { { scope = "party", tab = "group", key = "partyOrientation" } } },
        { advance = 0.5 },
    },
}
