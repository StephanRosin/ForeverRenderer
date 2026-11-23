-- ForeverGroupFinder: das Bewertungsfenster (Sterne und Kommentar) über dem
-- Detailfeld, dessen Anführer schon bewertet ist. Erfundene Namen.
return {
    extends = "ForeverGroupFinder/full",
    steps = { { call = "ForeverGroupFinder:Settings.Set", args = { "layout", "SIDEBAR" } },
        { call = "ForeverGroupFinder:Window.Show" }, { advance = 0.3 }, { run = function()
        local ns = require("loader").namespaces.ForeverGroupFinder
        ns.Ratings.Set("Testarion", 4, "Ruhiger Tank, erklärt die Bosse")
        ns.Detail.Open({ id = 1, activityIDs = {}, age = 300, comment = "Erfundene Gruppe sucht Heiler",
            noRoom = true, leader = "Testarion", leaderName = "Testarion", members = {
                { name = "Testarion", class = "WARRIOR", level = 60, role = "TANK" },
                { name = "Probewyn", class = "MAGE", level = 59, role = "DAMAGER" } } })
        ns.Ratings.Open("Testarion")
    end }, { advance = 0.3 } },
}
