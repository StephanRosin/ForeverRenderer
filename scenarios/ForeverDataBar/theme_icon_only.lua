-- ForeverDataBar: Hub "Forever Themes", Teil "Theme" nur als Symbol (dataBarThemeIconOnly), Tooltip im Theme Holz.
return {
    extends = "ForeverDataBar/full",
    crop = { frames = { "ForeverDataBarFrame", "ForeverDataBarTooltip" } },
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarThemeIconOnly = true } } },
    steps = {
        { run = function()
            local follows = { ForeverQuestLog = false }
            _G.ForeverThemes.ForeverQuestLog = { title = "Forever Quest Log" }
            LibForeverThemes.SetHub { Follows = function(f) return follows[f] ~= false end,
                Theme = function() return "PITWALL" end, Color = function() return LibForeverThemes.Colors("PITWALL")[2] end,
                OpenMenu = function() end, OpenOptions = function() end }
        end },
        { advance = 1.2 },
        { run = function() _G.FDBThemePart = ForeverDataBarFrame.parts.THEME end },
        { hover = "FDBThemePart" },
        { advance = 1 },
    },
}
