-- ForeverDataBar: Ruf, Werte und Währungen kompakt (Symbol + Wort), Maus über dem Ruf: Tooltip im Theme.
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
            D.UpdateReps()
            local b = D.frame.repCompact
            require("widgets").cursor = { (b:GetLeft() + 5) * b:GetEffectiveScale(), 0 }
            b:GetScript("OnEnter")(b)
        end },
        { advance = 0.5 },
    },
}
