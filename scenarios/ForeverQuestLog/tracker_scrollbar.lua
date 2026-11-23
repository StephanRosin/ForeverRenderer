-- ForeverQuestLog: Tracker niedrig, Scrollbalken gezogen (Griff 60 px nach unten, Balken breit unter der Maus).
return {
    extends = "ForeverQuestLog/full",
    steps = {
        { call = "ForeverQuestLog:Settings.Set", args = { "height", 160 } },
        { advance = 0.5 },
        { run = function()
            local grip = ForeverQuestLogScroll:GetParent().grip
            local real, s = GetCursorPosition, grip:GetEffectiveScale()
            GetCursorPosition = function() return 0, 500 * s end
            grip:GetScript("OnMouseDown")(grip, "LeftButton")
            GetCursorPosition = function() return 0, 440 * s end
            grip:GetScript("OnUpdate")(grip)
            GetCursorPosition = real
            grip:GetScript("OnEnter")(grip)
        end },
        { advance = 0.3 },
    },
}
