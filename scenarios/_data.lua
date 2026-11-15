-- Gemeinsamer, frei erfundener Spielstand fuer die "full"-Szenarien.
-- Keine echten Figuren-, Spieler- oder Gildennamen.
local D = {}

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local NAMES = { "Brannoc", "Elwyra", "Feyndra", "Gorvin", "Ilsabet", "Juno", "Kestrel", "Lunari", "Morwen", "Nyssa",
    "Orrin", "Pellam", "Quilla", "Rhosyn", "Sorrel", "Tamsin", "Ulric", "Vesna", "Wren", "Yorick" }
local ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }

local function member(i, extra)
    local cls = CLASSES[(i - 1) % #CLASSES + 1]
    local u = { name = NAMES[(i - 1) % #NAMES + 1] .. (i > #NAMES and tostring(i) or ""), class = cls, level = 60,
        health = 3000 + (i * 397) % 3000, healthMax = 6000, power = 2000 + (i * 211) % 3000, powerMax = 5000,
        powerType = (cls == "WARRIOR") and 1 or ((cls == "ROGUE") and 3 or 0), role = ROLES[(i - 1) % #ROLES + 1],
        guid = string.format("Player-1-%08d", 1000 + i), isPlayer = true }
    for k, v in pairs(extra or {}) do u[k] = v end
    return u
end
D.Member = member

-- Figur samt Ziel, Geld, XP, Taschen, Berufen, Ruf, Quests.
function D.Full()
    return {
        money = 12345678, xp = 61000, xpMax = 100000, restedXP = 20000, zone = "Elwynn Forest", subzone = "Goldshire",
        units = {
            player = { name = "Testfigur", class = "PRIEST", level = 57, health = 3100, healthMax = 4200, power = 3500, powerMax = 5000,
                auras = { { spellId = 10938, duration = 1800, elapsed = 600, fromPlayer = true }, { spellId = 139, duration = 15, elapsed = 4, fromPlayer = true },
                    { spellId = 17, duration = 30, elapsed = 10, fromPlayer = true }, { spellId = 11426, duration = 60, elapsed = 50, harmful = true, dispel = "Magic" } } },
            target = { name = "Ausbildungsattrappe", level = 60, health = 30000, healthMax = 50000, hostile = true, npcID = 31146, classification = "elite",
                auras = { { spellId = 10894, duration = 24, elapsed = 6, harmful = true, fromPlayer = true }, { spellId = 10890, duration = 8, elapsed = 2, harmful = true, count = 3 } },
                casting = { name = "Schattenblitz", duration = 2.5, elapsed = 1.0, icon = 136197 } },
            pet = { name = "Flauschi", level = 57, health = 900, healthMax = 1500, npcID = 1 },
        },
        bags = {
            [0] = { size = 16, items = { [1] = { id = 6948 }, [2] = { id = 8766, count = 20 }, [3] = { id = 8932, count = 12 } } },
            [1] = { size = 14, items = { [1] = { id = 13446, count = 5 } } },
            [2] = { size = 14 }, [3] = { size = 14 }, [4] = { size = 16 },
        },
        items = {
            [6948] = { name = "Hearthstone", icon = 134414, quality = 1, cooldown = { duration = 3600, elapsed = 1200 } },
            [8766] = { name = "Morning Glory Dew", icon = 132794, quality = 1 },
            [8932] = { name = "Alterac Swiss", icon = 133948, quality = 1 },
            [13446] = { name = "Major Healing Potion", icon = 134833, quality = 1 },
        },
        skills = {
            { name = "Professions", isHeader = true },
            { name = "Tailoring", rank = 280, maxRank = 300, skillID = 197 },
            { name = "Enchanting", rank = 300, maxRank = 300, skillID = 333 },
            { name = "Secondary Skills", isHeader = true },
            { name = "Cooking", rank = 225, maxRank = 300, skillID = 185 },
            { name = "First Aid", rank = 300, maxRank = 300, skillID = 129 },
        },
        factions = {
            { name = "Classic", isHeader = true },
            { name = "Argent Dawn", factionID = 529, reaction = 6, min = 9000, max = 21000, value = 15400, isWatched = true },
            { name = "Thorium Brotherhood", factionID = 59, reaction = 5, min = 3000, max = 9000, value = 4100 },
            { name = "Timbermaw Hold", factionID = 576, reaction = 4, min = 0, max = 3000, value = 1200 },
        },
        currencies = {},
        quests = {
            { title = "Western Plaguelands", isHeader = true },
            { title = "Die verlorene Laterne", questID = 90001, level = 58, watched = true,
              objectives = { { text = "Laternenscherben: 3/8", have = 3, need = 8 }, { text = "Glimmender Docht: 0/1", have = 0, need = 1, type = "item" } } },
            { title = "Ein Brief fuer Goldhain", questID = 90002, level = 60, watched = true, complete = true, objectives = {} },
            { title = "Winterspring", isHeader = true },
            { title = "Frostsaebler im Schnee", questID = 90003, level = 59, watched = true,
              objectives = { { text = "Frostsaebler erlegt: 7/10", have = 7, need = 10 } } },
            { title = "Proben vom Quellwasser", questID = 90004, level = 55, objectives = { { text = "Wasserproben: 2/2", have = 2, need = 2 } } },
        },
        superTracked = 90001,
        spells = {
            [139] = { name = "Renew", icon = 135953, known = true },
            [17] = { name = "Power Word: Shield", icon = 135940, known = true },
            [8936] = { name = "Regrowth", icon = 136085, known = false },
        },
    }
end

-- Gruppe aus fuenf (Spieler + vier).
function D.Group(state)
    state.group = "party"
    for i = 1, 4 do state.units["party" .. i] = member(i, i == 1 and { leader = true } or nil) end
    state.units.party3.dead = true
    state.units.party3.health = 0
    return state
end

-- Raid mit n Mitgliedern (raid1 ist der Spieler).
function D.Raid(state, n)
    state.group = "raid"
    for i = 1, n do
        state.units["raid" .. i] = i == 1 and "player" or member(i, { subgroup = math.floor((i - 1) / 5) + 1 })
    end
    return state
end

return D
