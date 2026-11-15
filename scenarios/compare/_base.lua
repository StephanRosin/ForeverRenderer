-- Grundlage der Vergleiche mit Stephans Screenshots (~/Downloads/screens):
-- alle Addons mit seinen echten SavedVariables (wtf = true, nur zur Laufzeit
-- gelesen). Die Screenshots sind 3433 px breit, rechts um 7 px beschnitten;
-- gerendert wird der ganze 3440er Bildschirm, Pixel 0 liegt in beiden gleich.
-- Nie als Referenzbild einchecken (enthaelt Kontodaten).
return {
    addons = { "ScreenBackdrop", "ForeverDataBar", "ForeverUnitFrames", "ForeverQuestLog", "ForeverCombatMeter",
        "ForeverGroupFinder", "ForeverSquareMinimap", "ForeverConsumables", "ForeverProgressBars", "InfoPanel" },
    screen = { 3440, 1440 },
    uiScale = 0.77,
    wtf = true,
    state = {
        money = 3025555, zone = "Stormwind City", xp = 61000, xpMax = 100000,
        units = { target = { name = "Ausbildungsattrappe", level = 60, health = 30000, healthMax = 50000, hostile = true, npcID = 31146, classification = "elite" } },
        quests = {
            { title = "Eastern Kingdoms", isHeader = true },
            { title = "Die verlorene Laterne", questID = 90001, level = 58, watched = true,
              objectives = { { text = "Laternenscherben: 3/8", have = 3, need = 8 } } },
            { title = "Ein Brief fuer Goldhain", questID = 90002, level = 60, watched = true, complete = true, objectives = {} },
        },
    },
}
