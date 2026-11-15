-- ForeverDataBar: Uhr im 12-Stunden-Format.
return {
    extends = "ForeverDataBar/classic",
    steps = {
        { call = "ForeverDataBar:Settings.Set", args = { "dataBarClock12", true } }, { advance = 1.2 },
    },
}
