-- ForeverDataBar: Ruf kompakt mit drei Fraktionen, Maus darüber: Tabelle mit Balken im Tooltip.
return {
    extends = "ForeverDataBar/full",
    crop = { frames = { "ForeverDataBarTooltip", "GameTooltip" } },
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarRepsCompact = true },
        ForeverDataBarChar = { reps = { 529, 59, 576 } } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            local D = require("loader").namespaces.ForeverDataBar.DataBar
            D.UpdateReps()
            local b = D.frame.repCompact
            require("widgets").cursor = { (b:GetLeft() + 5) * b:GetEffectiveScale(), 0 }
            b:GetScript("OnEnter")(b)
        end },
        { advance = 0.5 },
    },
}
