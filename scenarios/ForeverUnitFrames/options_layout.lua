-- ForeverUnitFrames: Optionsfenster, Reiter Layout des Spielerfensters,
-- gescrollt bis zu den Leistengroessen (barAlign, barSpacing).
return {
    extends = "ForeverUnitFrames/options",
    steps = {
        { call = "ForeverUnitFrames:Options.Reveal", args = { { scope = "player", tab = "layout", key = "barAlign" } } },
        { advance = 0.5 },
    },
}
