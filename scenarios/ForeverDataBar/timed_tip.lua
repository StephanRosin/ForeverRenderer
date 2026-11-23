-- ForeverDataBar: Abklingzeiten, Maus über dem Transmutieren-Symbol: Tooltip nur für dieses Rezept.
return {
    extends = "ForeverDataBar/full",
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarTimed = true, dataBarHearth = true, dataBarOwnIcons = true } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            ForeverDataBarChar = ForeverDataBarChar or {}
            ForeverDataBarChar.timed = { [17187] = true, [18560] = true, [11479] = true, [11480] = true, [1225469] = true }
        end },
        { call = "ForeverDataBar:DataBar.UpdateStats" },
        { advance = 1.5 },
        { run = function()
            local g = require("loader").namespaces.ForeverDataBar.DataBar.frame.parts.TIMED
            require("widgets").cursor = { (g:GetLeft() + g.slots[2].from + 2) * g:GetEffectiveScale(), 0 }
            g:GetScript("OnEnter")(g)
        end },
        { advance = 0.3 },
    },
}
