-- ForeverDataBar: Rezepte mit Skillpunkten (dataBarSkillUps): "+2" hinter dem Rang
-- des ersten Berufs und sein Tooltip mit der Rezeptliste (erfundene Rezepte).
return {
    extends = "ForeverDataBar/full",
    saved = { ForeverDataBar = { ForeverDataBarDB = { dataBarSkillUps = true } } },
    steps = {
        { advance = 1.2 },
        { run = function()
            local first = ForeverDataBarFrame.profs and ForeverDataBarFrame.profs[1]
                or select(2, next(ForeverDataBarFrame.profBox and { ForeverDataBarFrame.profBox:GetChildren() } or {}))
            ForeverDataBarChar = ForeverDataBarChar or {}
            ForeverDataBarChar.crafts = { [first.skillLine] = {
                [1] = { n = "Bolt of Dewcloth", d = 0, r = { 8766, 4 } },
                [2] = { n = "Swiss Satchel", d = 1, r = { 8932, 5, 13446, 1 } },
                [3] = { n = "Glovelets", d = 2, r = { 99999, 1 } },
            } }
            _G.FDBFirstProf = first
        end },
        { call = "ForeverDataBar:DataBar.UpdateProfessions" },
        { advance = 0.5 },
        { hover = "FDBFirstProf" },
        { advance = 1 },
    },
}
