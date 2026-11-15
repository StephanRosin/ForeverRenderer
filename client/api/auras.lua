-- Auren aus dem Szenario: units.<u>.auras = { { spellId = 139, duration = 15,
-- elapsed = 3, count = 1, harmful = false, fromPlayer = true, dispel = "Magic" } }.
-- Name und Symbol kommen aus spells.json, wenn das Szenario sie nicht nennt.
-- Forevers native Aura-Container (CustomAuraContainerTemplate) sind nicht
-- nachgebaut; Addons fallen dann auf diese Abfragen zurueck.
local W = require("widgets")
local G = require("game")

local A = {}

local QUESTION_MARK_ICON = 134400
local state

local function auraData(unit, a, index)
    local sp = a.spellId and C_Spell.GetSpellInfo(a.spellId)
    local now = W.now()
    return {
        name = a.name or (sp and sp.name) or "Aura", icon = a.icon or (sp and sp.iconID) or QUESTION_MARK_ICON,
        applications = a.count or 0, charges = 0, maxCharges = 0, dispelName = a.dispel,
        duration = a.duration or 0, expirationTime = a.duration and (now - (a.elapsed or 0) + a.duration) or 0,
        sourceUnit = a.fromPlayer and "player" or a.source, isFromPlayerOrPlayerPet = a.fromPlayer or false,
        isHelpful = not a.harmful, isHarmful = a.harmful or false, isStealable = false, isRaid = false,
        isBossAura = a.boss or false, nameplateShowAll = false, nameplateShowPersonal = false, canApplyAura = a.fromPlayer or false,
        spellId = a.spellId or 0, auraInstanceID = a.instance or (index * 1000 + #unit), timeMod = 1, points = {},
    }
end

local function list(unit, filter)
    local u = G.Resolve(unit)
    local out = {}
    if not u then return out end
    filter = (filter or "HELPFUL"):upper()
    local harmful = filter:find("HARMFUL") ~= nil
    local onlyMine = filter:find("PLAYER") ~= nil
    for i, a in ipairs(u.auras or {}) do
        if (a.harmful or false) == harmful and (not onlyMine or a.fromPlayer) then
            out[#out + 1] = auraData(unit, a, i)
        end
    end
    return out
end

function A.Install(st)
    state = st
    _G.C_UnitAuras = _G.C_UnitAuras or {}
    local UA = C_UnitAuras
    UA.GetUnitAuras = function(unit, filter, max)
        local l = list(unit, filter)
        if max and #l > max then for i = #l, max + 1, -1 do l[i] = nil end end
        return l
    end
    UA.GetAuraDataByIndex = function(unit, i, filter) return list(unit, filter)[i] end
    UA.GetAuraDataBySlot = function(unit, slot) return list(unit, "HELPFUL")[slot] end
    UA.GetAuraDataByAuraInstanceID = function(unit, id)
        for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
            for _, a in ipairs(list(unit, f)) do if a.auraInstanceID == id then return a end end
        end
        return nil
    end
    UA.GetAuraDataBySpellName = function(unit, name, filter)
        for _, a in ipairs(list(unit, filter)) do if a.name == name then return a end end
        return nil
    end
    UA.GetPlayerAuraBySpellID = function(id)
        for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
            for _, a in ipairs(list("player", f)) do if a.spellId == id then return a end end
        end
        return nil
    end
    UA.IsAuraFilteredOutByInstanceID = function(unit, id, filter)
        for _, a in ipairs(list(unit, filter)) do if a.auraInstanceID == id then return false end end
        return true
    end
    -- shortcut: Forevers Dauer-Objekt (C_DurationUtil) fehlt; nil laesst Addons auf expirationTime zurueckfallen.
    UA.GetAuraDuration = function() return nil end
    UA.GetAuraApplicationDisplayCount = function(unit, id)
        local a = UA.GetAuraDataByAuraInstanceID(unit, id)
        return a and a.applications > 1 and tostring(a.applications) or ""
    end
    UA.GetAuraDispelTypeColor = function() return nil end
    _G.C_Secrets = _G.C_Secrets or {}
    C_Secrets.ShouldAurasBeSecret = function() return state.secretAuras or false end
    C_Secrets.ShouldUnitIdentityBeSecret = function() return false end
    C_Secrets.GetSpellAuraSecrecy = function() return 0 end
end

return A
