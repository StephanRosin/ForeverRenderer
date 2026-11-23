-- ForeverQuestLog: Optionen, Scrollbalken gezogen (Daumen 200 px nach unten, breit unter der Maus).
return {
    extends = "ForeverQuestLog/options",
    steps = {
        { slash = "/fql" }, { advance = 0.3 },
        { call = "ForeverQuestLog:Window.ShowPage", args = { "appearance" } }, { advance = 0.5 },
        { run = function()
            local body = ForeverQuestLogOptionsScroll:GetParent()
            for _, c in ipairs({ body:GetChildren() }) do
                if c.bar then
                    local real = GetCursorPosition
                    local s = c:GetEffectiveScale()
                    GetCursorPosition = function() return 0, 500 * s end
                    c:GetScript("OnMouseDown")(c, "LeftButton")
                    GetCursorPosition = function() return 0, 300 * s end
                    c:GetScript("OnUpdate")(c)
                    GetCursorPosition = real
                    c:GetScript("OnEnter")(c)
                end
            end
        end },
        { advance = 0.3 },
    },
}
