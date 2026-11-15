-- ForeverDataBar: Reiter "Teile", beim Abschnitt Uhr (12-Stunden-Uhr, Micro-Menue).
return {
    extends = "ForeverDataBar/options",
    steps = {
        { slash = "/fdb" }, { call = "ForeverDataBar:Window.ShowPage", args = { "parts" } }, { advance = 0.2 },
        { run = function()
            ForeverDataBarOptionsScroll:SetVerticalScroll(ForeverDataBarOptionsScroll:GetVerticalScrollRange() * 0.45)
        end },
        { advance = 0.3 },
    },
}
