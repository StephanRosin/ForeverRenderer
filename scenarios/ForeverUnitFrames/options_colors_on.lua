-- ForeverUnitFrames: General > Colors mit eigenen Klassen- und
-- Begleiterfarben an, Hexenmeister dunkler.
return {
    extends = "ForeverUnitFrames/options",
    steps = {
        { call = "ForeverUnitFrames:Config.Set", args = { "general", "classColorsCustom", true } },
        { call = "ForeverUnitFrames:Config.Set", args = { "general", "classColorWARLOCK", { 0.35, 0.2, 0.7, 1 } } },
        { call = "ForeverUnitFrames:Config.Set", args = { "general", "petColorsCustom", true } },
        { call = "ForeverUnitFrames:Options.Open", args = { "general", "colors" } },
        { advance = 0.5 },
    },
}
