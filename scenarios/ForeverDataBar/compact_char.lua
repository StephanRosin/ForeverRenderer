-- ForeverDataBar: Werte kompakt, Maus darüber: die Werte im Tooltip im Theme.
return {
    extends = "ForeverDataBar/full",
    crop = { frames = { "ForeverDataBarFrame", "ForeverDataBarTooltip" } },
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarRepsCompact = true, dataBarChar = true, dataBarCharCompact = true,
        dataBarCurrency = true, dataBarCurrencyCompact = true, dataBarHearth = true } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            local D = require("loader").namespaces.ForeverDataBar.DataBar
            D.UpdateStats()
            local g = D.frame.parts.CHAR
            g:GetScript("OnEnter")(g)
        end },
        { advance = 0.5 },
    },
}
