-- ForeverDataBar: Abklingzeit-Rezepte (Timed.lua) im Tooltip des ersten Berufs.
return {
    extends = "ForeverDataBar/full",
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarSkillUps = true } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            local first = ForeverDataBarFrame.profs and ForeverDataBarFrame.profs[1]
                or select(2, next(ForeverDataBarFrame.profBox and { ForeverDataBarFrame.profBox:GetChildren() } or {}))
            ForeverDataBarChar = ForeverDataBarChar or {}
            ForeverDataBarChar.timed = { [17187] = true, [18560] = true, [11479] = true, [11480] = true }
            _G.FDBFirstProf = first
        end },
        { call = "ForeverDataBar:DataBar.UpdateProfessions" },
        { advance = 0.5 },
        { hover = "FDBFirstProf" },
        { advance = 1 },
    },
}
