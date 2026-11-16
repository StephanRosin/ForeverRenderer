-- ForeverDataBar: das Goldfenster (Themes faerben es) ueber der Leiste,
-- mit einer erfundenen Woche Gold und Auktionsgegenstaenden.
local s = require("_data").Full()
s.items[2589] = { name = "Linen Cloth", icon = 132889, quality = 1 }
s.items[12360] = { name = "Arcanite Bar", icon = 133230, quality = 2 }
s.items[20725] = { name = "Nexus Crystal", icon = 132872, quality = 4 }
s.items[7910] = { name = "Star Ruby", icon = 134134, quality = 2 }

local DAY = 86400
local now = 1794700800 + 12 * 3600 -- die feste Szenario-Zeit (client/env.lua), mittags

-- Tagesschluss je Tag rueckwaerts (heute zuletzt), Einnahmen/Ausgaben je Quelle.
local closes = { 1180000, 1210000, 1195000, 1260000, 1238000, 1301000 }
local days = {}
for i, close in ipairs(closes) do
    local key = os.date("%Y-%m-%d", now - (#closes + 1 - i) * DAY)
    days[key] = { gained = 60000, spent = 30000, close = close,
        inc = { LOOT = 30000, AH_SALE = 30000 }, out = { REPAIR = 30000 } }
end
days[os.date("%Y-%m-%d", now)] = { gained = 92000, spent = 18000,
    inc = { AH_SALE = 52000, LOOT = 21000, QUEST = 14000, VENDOR_SALE = 5000 },
    out = { REPAIR = 9000, AH_FEES = 6000, FLIGHT = 3000 } }
s.money = 1234567

return {
    extends = "ForeverDataBar/full",
    state = s,
    saved = { ForeverDataBar = {
        ForeverDataBarChar = { goldDays = days, goldSession = { start = now - 5400, gained = 74000, spent = 18000, last = s.money } },
        ForeverDataBarDB = { goldItems = { [s.realm or "Testrealm"] = {
            ["Nexus Crystal"] = { buyCost = 0, buyQty = 0, sellNet = 184000, sellQty = 4 },
            ["Arcanite Bar"] = { buyCost = 60000, buyQty = 2, sellNet = 142000, sellQty = 3 },
            ["Linen Cloth"] = { buyCost = 0, buyQty = 0, sellNet = 9600, sellQty = 120 },
            ["Star Ruby"] = { buyCost = 0, buyQty = 0, sellNet = 31000, sellQty = 5 },
        } } },
    } },
    epoch = now,
    steps = { { call = "ForeverDataBar:GoldWindow.Toggle" }, { advance = 0.5 } },
}
