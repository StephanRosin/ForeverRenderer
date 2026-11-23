-- ForeverDataBar: Teil "Abklingzeiten" (Timed.lua) auf der Leiste, Spalte 2, mit Tooltip.
return {
    extends = "ForeverDataBar/full",
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarTimed = true, dataBarHearth = true, dataBarOwnIcons = true } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            ForeverDataBarChar = ForeverDataBarChar or {}
            ForeverDataBarChar.timed = { [17187] = true, [18560] = true, [11479] = true, [11480] = true }
        end },
        { call = "ForeverDataBar:DataBar.UpdateStats" },
        { advance = 1.5 },
    },
}
