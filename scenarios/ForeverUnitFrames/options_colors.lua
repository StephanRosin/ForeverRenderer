-- ForeverUnitFrames: Optionsfenster, General > Colors (Klassen- und
-- Begleiterfarben), Schalter aus.
return {
    extends = "ForeverUnitFrames/options",
    steps = {
        { call = "ForeverUnitFrames:Options.Open", args = { "general", "colors" } },
        { advance = 0.5 },
    },
}
