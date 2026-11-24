-- ForeverUnitFrames: Raid-Optionsfenster, Reiter Cell, gescrollt zu den
-- Farben der Ressourcenleiste und der Heilung (FOREVER_REVEAL=<Schluessel>).
return {
    extends = "ForeverUnitFrames/raid_options_cell",
    steps = {
        { call = "ForeverUnitFrames:RaidOptions.Open", args = { 10, "cell" } },
        { advance = 0.5 },
        { call = "ForeverUnitFrames:RaidOptions.Reveal", args = { { tab = "cell", key = os.getenv("FOREVER_REVEAL") or "powerColorMana" } } },
        { advance = 0.5 },
    },
}
