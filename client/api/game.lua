-- Spielzustand aus dem Szenario: Einheiten, Gruppe/Raid, CVars, Addon-Liste,
-- Geld, Zone, Zeit und Kleinkram. Felder einer Einheit koennen als geheim
-- markiert werden (unit.secret = { health = true, name = true, ... }); die
-- API liefert sie dann als Secret wie der Forever-Client im Kampf.
local Sec = require("secret")
local R = require("report")
local W = require("widgets")

local G = {}

-- Erfundene Standardfigur, damit jedes Addon ohne Szenario-Daten startet.
G.DEFAULT_PLAYER = {
    name = "Testfigur", class = "PRIEST", race = "Human", level = 60, sex = 3, faction = "Alliance",
    health = 4200, healthMax = 4200, power = 3500, powerMax = 5000, powerType = 0, guid = "Player-1-00000001",
}
G.DEFAULT_REALM = "Testrealm"
local CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest", SHAMAN = "Shaman",
    MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid", DEATHKNIGHT = "Death Knight", MONK = "Monk", DEMONHUNTER = "Demon Hunter", EVOKER = "Evoker",
}
local CLASS_IDS = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12, EVOKER = 13 }
G.CLASS_COLORS = {
    WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1.0, 0.96, 0.41 },
    PRIEST = { 1.0, 1.0, 1.0 }, SHAMAN = { 0.0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 },
    DRUID = { 1.0, 0.49, 0.04 }, DEATHKNIGHT = { 0.77, 0.12, 0.23 }, MONK = { 0.0, 1.0, 0.6 }, DEMONHUNTER = { 0.64, 0.19, 0.79 }, EVOKER = { 0.2, 0.58, 0.5 },
}
local POWER_TOKENS = { [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [6] = "RUNIC_POWER" }

local state

-- Einheit aufloesen: "target" darf auf eine andere Einheit zeigen ("party2").
local function resolve(unit)
    if type(unit) ~= "string" then return nil end
    unit = unit:lower()
    local u = state.units[unit]
    local hops = 0
    while type(u) == "string" and hops < 5 do
        unit, u = u, state.units[u]
        hops = hops + 1
    end
    if u == nil then
        -- "party1target" -> Ziel von party1
        local base, rest = unit:match("^(%a+%d*)(target)$")
        if base and state.units[base] and type(state.units[base]) == "table" and state.units[base].target then
            return resolve(state.units[base].target)
        end
    end
    if type(u) ~= "table" then return nil end
    return u, unit
end
G.Resolve = resolve

local function field(u, key, value)
    if u.secret and u.secret[key] then return Sec.Wrap(value) end
    if state.secretAll and state.secretAll[key] then return Sec.Wrap(value) end
    return value
end

local function groupMembers()
    local list = {}
    if state.group == "raid" then
        for i = 1, 40 do if state.units["raid" .. i] then list[#list + 1] = "raid" .. i end end
    elseif state.group then
        list[1] = "player"
        for i = 1, 4 do if state.units["party" .. i] then list[#list + 1] = "party" .. i end end
    end
    return list
end

function G.Install(st, env)
    state = st
    state.units = state.units or {}
    local player = state.units.player or {}
    for k, v in pairs(G.DEFAULT_PLAYER) do if player[k] == nil then player[k] = v end end
    state.units.player = player
    state.cvars = state.cvars or {}
    state.realm = state.realm or G.DEFAULT_REALM
    env.UnitExists = function(u) return resolve(u) ~= nil end

    _G.UnitExists = function(u) return resolve(u) ~= nil end
    _G.UnitIsUnit = function(a, b)
        local ua, ub = resolve(a), resolve(b)
        return ua ~= nil and ua == ub
    end
    _G.UnitGUID = function(u) local x = resolve(u) return x and field(x, "guid", x.guid or ("Creature-0-0-0-0-" .. tostring(x.npcID or 1) .. "-0")) end
    _G.UnitName = function(u)
        local x = resolve(u)
        if not x then return nil end
        return field(x, "name", x.name), x.realm
    end
    _G.UnitFullName = function(u)
        local x = resolve(u)
        if not x then return nil end
        return field(x, "name", x.name), x.realm or state.realm
    end
    _G.UnitNameUnmodified = _G.UnitName
    _G.GetUnitName = function(u, showServer)
        local x = resolve(u)
        if not x then return nil end
        if showServer and x.realm then return field(x, "name", x.name .. "-" .. x.realm) end
        return field(x, "name", x.name)
    end
    _G.UnitClass = function(u)
        local x = resolve(u)
        if not x or not x.class then return nil end
        return CLASS_NAMES[x.class] or x.class, x.class, CLASS_IDS[x.class]
    end
    _G.UnitClassBase = function(u) local x = resolve(u) return x and x.class, x and CLASS_IDS[x.class] end
    _G.UnitRace = function(u) local x = resolve(u) return x and x.race, x and x.race end
    _G.UnitSex = function(u) local x = resolve(u) return x and (x.sex or 2) end
    _G.UnitLevel = function(u) local x = resolve(u) return x and field(x, "level", x.level or 60) or 0 end
    _G.UnitEffectiveLevel = _G.UnitLevel
    _G.UnitFactionGroup = function(u) local x = resolve(u) return x and (x.faction or "Alliance"), x and (x.faction or "Alliance") end
    _G.UnitHealth = function(u) local x = resolve(u) return x and field(x, "health", x.health or 0) or 0 end
    _G.UnitHealthMax = function(u) local x = resolve(u) return x and field(x, "healthMax", x.healthMax or 1) or 1 end
    _G.UnitHealthMissing = function(u) local x = resolve(u) return x and field(x, "health", (x.healthMax or 1) - (x.health or 0)) or 0 end
    _G.UnitPower = function(u, t)
        local x = resolve(u)
        if not x then return 0 end
        if t and t ~= (x.powerType or 0) and x.powers then return field(x, "power", x.powers[t] or 0) end
        return field(x, "power", x.power or 0)
    end
    _G.UnitPowerMax = function(u, t)
        local x = resolve(u)
        if not x then return 0 end
        if t and t ~= (x.powerType or 0) and x.powersMax then return field(x, "power", x.powersMax[t] or 0) end
        return field(x, "powerMax", x.powerMax or 0)
    end
    _G.UnitPowerMissing = function(u) local x = resolve(u) return x and ((x.powerMax or 0) - (x.power or 0)) or 0 end
    _G.UnitPowerType = function(u)
        local x = resolve(u)
        local t = x and x.powerType or 0
        return t, POWER_TOKENS[t] or "MANA"
    end
    -- Forever: Prozent als Kurve auswertbar; ohne Kurve 0..100.
    _G.UnitHealthPercent = function(u, usePredicted, curve)
        local x = resolve(u)
        if not x then return 0 end
        local p = (x.health or 0) / math.max(1, x.healthMax or 1)
        if curve and curve.Evaluate then p = curve:Evaluate(p) else p = p * 100 end
        return field(x, "health", p)
    end
    _G.UnitPowerPercent = function(u, powerType, usePredicted, curve)
        local x = resolve(u)
        if not x then return 0 end
        local p = (x.power or 0) / math.max(1, x.powerMax or 1)
        if curve and curve.Evaluate then p = curve:Evaluate(p) else p = p * 100 end
        return field(x, "power", p)
    end
    _G.UnitGetTotalAbsorbs = function(u) local x = resolve(u) return x and field(x, "absorbs", x.absorbs or 0) or 0 end
    _G.UnitGetTotalHealAbsorbs = function(u) local x = resolve(u) return x and (x.healAbsorbs or 0) or 0 end
    _G.UnitGetIncomingHeals = function(u) local x = resolve(u) return x and (x.incomingHeals or 0) or 0 end
    _G.UnitIsDead = function(u) local x = resolve(u) return x and x.dead or false end
    _G.UnitIsGhost = function(u) local x = resolve(u) return x and x.ghost or false end
    _G.UnitIsDeadOrGhost = function(u) local x = resolve(u) return x and (x.dead or x.ghost) or false end
    _G.UnitIsConnected = function(u) local x = resolve(u) return x and x.connected ~= false end
    _G.UnitIsPlayer = function(u) local x = resolve(u) return x and (x.isPlayer ~= false and x.npcID == nil) or false end
    _G.UnitPlayerControlled = _G.UnitIsPlayer
    _G.UnitIsAFK = function(u) local x = resolve(u) return x and x.afk or false end
    _G.UnitIsDND = function() return false end
    _G.UnitIsPVP = function(u) local x = resolve(u) return x and x.pvp or false end
    _G.UnitIsPVPFreeForAll = function() return false end
    _G.UnitIsTapDenied = function(u) local x = resolve(u) return x and x.tapDenied or false end
    _G.UnitIsEnemy = function(u) local x = resolve(u) return x and x.hostile or false end
    _G.UnitCanAttack = function(a, b) local x = resolve(b) return x and x.hostile or false end
    _G.UnitCanAssist = function(a, b) local x = resolve(b) return x and not x.hostile or false end
    _G.UnitIsFriend = function(a, b) local x = resolve(b) return x and not x.hostile or false end
    _G.UnitReaction = function(a, b) local x = resolve(b) return x and (x.reaction or (x.hostile and 2 or 5)) end
    _G.UnitClassification = function(u) local x = resolve(u) return x and (x.classification or "normal") end
    _G.UnitCreatureType = function(u) local x = resolve(u) return x and x.creatureType end
    _G.UnitAffectingCombat = function(u) local x = resolve(u) return x and (x.combat or (u == "player" and state.combat)) or false end
    _G.UnitIsGroupLeader = function(u) local x = resolve(u) return x and x.leader or false end
    _G.UnitIsGroupAssistant = function(u) local x = resolve(u) return x and x.assistant or false end
    _G.UnitGroupRolesAssigned = function(u) local x = resolve(u) return x and field(x, "role", x.role or "NONE") or "NONE" end
    _G.UnitInRange = function(u) local x = resolve(u) if not x then return false, false end return x.inRange ~= false, true end
    _G.UnitIsVisible = function(u) return resolve(u) ~= nil end
    _G.UnitInParty = function(u) local _, t = resolve(u) return t ~= nil and (t == "player" or t:match("^party") ~= nil) end
    _G.UnitInRaid = function(u) local _, t = resolve(u) if t and t:match("^raid(%d+)") then return tonumber(t:match("%d+")) end return nil end
    _G.UnitThreatSituation = function(u) local x = resolve(u) return x and x.threat end
    _G.UnitDetailedThreatSituation = function(u, mob)
        local x = resolve(u)
        if not x or not x.threat then return nil end
        return x.threat >= 2, x.threat, x.threatPct or 0, x.threatPct or 0, 0
    end
    _G.UnitCastingInfo = function(u)
        local x = resolve(u)
        local c = x and x.casting
        if not c then return nil end
        local now = W.now()
        return c.name, c.name, c.icon, (now - (c.elapsed or 0)) * 1000, (now - (c.elapsed or 0) + c.duration) * 1000, false, "cast", c.notInterruptible or false, c.spellID
    end
    _G.UnitChannelInfo = function(u)
        local x = resolve(u)
        local c = x and x.channel
        if not c then return nil end
        local now = W.now()
        return c.name, c.name, c.icon, (now - (c.elapsed or 0)) * 1000, (now - (c.elapsed or 0) + c.duration) * 1000, false, c.notInterruptible or false, c.spellID
    end
    _G.UnitXP = function() return state.xp or 0 end
    _G.UnitXPMax = function() return state.xpMax or 1 end
    _G.GetXPExhaustion = function() return state.restedXP end
    _G.GetRestState = function() return state.restedXP and 1 or 2, state.restedXP and "Rested" or "Normal", 1 end
    _G.IsXPUserDisabled = function() return false end
    _G.GetMaxPlayerLevel = function() return 60 end
    _G.GetMaxLevelForPlayerExpansion = function() return 60 end
    _G.UnitOnTaxi = function() return false end
    _G.UnitInVehicle = function() return false end
    _G.UnitHasVehicleUI = function() return false end
    _G.UnitUsingVehicle = function() return false end
    _G.UnitIsCharmed = function() return false end
    _G.UnitIsPossessed = function() return false end
    _G.UnitPhaseReason = function() return nil end
    _G.UnitIsOtherPlayersPet = function() return false end
    _G.UnitHasIncomingResurrection = function() return false end
    _G.UnitAttackPower = function() return 1000, 0, 0 end
    _G.UnitRangedAttackPower = function() return 800, 0, 0 end
    _G.UnitStat = function() return 100, 100, 0, 0 end
    _G.UnitArmor = function() return 3000, 3000, 3000, 0, 0 end
    _G.UnitSelectionColor = function() return 1, 1, 1, 1 end
    _G.UnitIsQuestBoss = function() return false end
    _G.UnitIsBossMob = function(u) local x = resolve(u) return x and x.classification == "worldboss" or false end
    _G.UnitPVPName = _G.UnitName
    _G.UnitIsMercenary = function() return false end
    _G.UnitIsInMyGuild = function() return false end
    _G.UnitIsTrivial = function() return false end
    _G.UnitIsWildBattlePet = function() return false end
    _G.UnitIsBattlePetCompanion = function() return false end
    _G.UnitHasRelicSlot = function() return false end
    _G.GetComboPoints = function() return state.comboPoints or 0 end
    _G.UnitIsFeignDeath = function() return false end
    _G.GetUnitSpeed = function() return 0, 7, 7, 4.72 end
    _G.UnitPosition = function() return 0, 0, 0, 0 end
    _G.GetPlayerFacing = function() return state.facing or 0 end
    _G.GetReadyCheckStatus = function(u) local x = resolve(u) return x and x.readyCheck end
    _G.GetRaidTargetIndex = function(u) local x = resolve(u) return x and x.raidTarget end
    _G.UnitHasLFGRandomCooldown = function() return false end
    _G.UnitHasLFGDeserter = function() return false end

    -- Gruppe und Raid.
    _G.IsInGroup = function() return state.group ~= nil end
    _G.IsInRaid = function() return state.group == "raid" end
    _G.GetNumGroupMembers = function() return #groupMembers() end
    _G.GetNumSubgroupMembers = function()
        local n = 0
        for i = 1, 4 do if state.units["party" .. i] then n = n + 1 end end
        return n
    end
    _G.GetRaidRosterInfo = function(i)
        local x = state.units["raid" .. i]
        if type(x) ~= "table" then return nil end
        local cls = x.class
        return x.name, x.leader and 2 or (x.assistant and 1 or 0), x.subgroup or math.floor((i - 1) / 5) + 1, x.level or 60,
            CLASS_NAMES[cls] or cls, cls, x.zone, x.connected ~= false, x.dead or false, x.raidRole, x.masterLooter or false, x.role or "NONE"
    end
    _G.IsPartyLFG = function() return false end
    _G.HasLFGRestrictions = function() return false end
    _G.IsInInstance = function() return state.instance ~= nil, state.instance or "none" end
    _G.GetInstanceInfo = function()
        return state.zone or "Elwynn Forest", state.instance or "none", 0, "", 5, 0, false, 0, 0
    end
    _G.IsResting = function() return state.resting or false end
    _G.IsMounted = function() return false end
    _G.IsFlying = function() return false end
    _G.IsSwimming = function() return false end
    _G.IsStealthed = function() return false end
    _G.IsInGuild = function() return state.guild ~= nil end
    _G.GetGuildInfo = function() return state.guild end

    -- Geld, Zone, Zeit.
    _G.GetMoney = function() return state.money or 0 end
    _G.GetZoneText = function() return state.zone or "Elwynn Forest" end
    _G.GetRealZoneText = _G.GetZoneText
    _G.GetSubZoneText = function() return state.subzone or "" end
    _G.GetMinimapZoneText = function() return state.subzone or state.zone or "Elwynn Forest" end
    _G.GetZonePVPInfo = function() return state.pvpType or "friendly" end
    _G.GetRealmName = function() return state.realm end
    _G.GetNormalizedRealmName = function() return (state.realm:gsub("%s", "")) end
    _G.GetBindLocation = function() return state.bindLocation or "Goldshire" end
    _G.GetGameTime = function()
        local t = os.date("!*t", _G.time())
        return t.hour, t.min
    end
    _G.GetNetStats = function() return 0, 0, state.latency or 32, state.latency or 32 end
    _G.GetFramerate = function() return state.fps or 60 end
    _G.GetSessionTime = function() return 3600 end
    _G.RequestTimePlayed = function() end
    _G.HasNewMail = function() return state.mail or false end
    _G.GetLatestThreeSenders = function() return nil end
    _G.GetInboxNumItems = function() return 0, 0 end
    _G.GetRepairAllCost = function() return 0, false end
    _G.GetInventoryItemDurability = function(slot)
        local d = state.durability and state.durability[slot]
        if not d then return nil end
        return d[1], d[2]
    end
    _G.GetInventoryItemTexture = function(_, slot)
        local i = state.equipment and state.equipment[slot]
        return i and i.icon
    end
    _G.GetInventoryItemLink = function(_, slot)
        local i = state.equipment and state.equipment[slot]
        return i and i.link
    end
    _G.GetInventoryItemID = function(_, slot)
        local i = state.equipment and state.equipment[slot]
        return i and i.id
    end
    _G.GetInventorySlotInfo = function(name) return ({ HeadSlot = 1, ShoulderSlot = 3, ChestSlot = 5, WaistSlot = 6, LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18 })[name] end
    _G.GetWeaponEnchantInfo = function() return false end
    _G.GetTotemInfo = function(i)
        local t = state.totems and state.totems[i]
        if not t then return false, "", 0, 0, nil end
        return true, t.name, W.now() - (t.elapsed or 0), t.duration, t.icon
    end
    _G.GetTotemTimeLeft = function(i) local t = state.totems and state.totems[i] return t and (t.duration - (t.elapsed or 0)) or 0 end
    _G.GetShapeshiftForm = function() return state.form or 0 end
    _G.GetNumShapeshiftForms = function() return 0 end
    _G.GetPetHappiness = function() return nil end
    _G.HasPetUI = function() return state.units.pet ~= nil, false end
    _G.PetHasActionBar = function() return false end
    _G.GetSpellBonusDamage = function() return 500 end
    _G.GetSpellBonusHealing = function() return 800 end
    _G.GetSpellCritChance = function() return 5 end
    _G.GetCritChance = function() return 5 end
    _G.GetRangedCritChance = function() return 5 end
    _G.GetHitModifier = function() return 0 end
    _G.GetSpellHitModifier = function() return 0 end
    _G.GetRangedHitModifier = function() return 0 end
    _G.GetCombatRatingBonus = function() return 0 end
    _G.GetNumTalentPoints = function() return 0 end

    -- Eingaben: im Szenario gibt es keine gedrueckten Tasten.
    for _, fn in ipairs({ "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown", "IsModifierKeyDown", "IsLeftShiftKeyDown",
        "IsRightShiftKeyDown", "IsLeftControlKeyDown", "IsRightControlKeyDown", "IsLeftAltKeyDown", "IsRightAltKeyDown", "IsMetaKeyDown" }) do
        _G[fn] = function() return (state.keys and state.keys[fn]) or false end
    end
    _G.IsMouseButtonDown = function() return false end
    _G.IsModifiedClick = function() return false end
    _G.GetModifiedClick = function() return "SHIFT" end
    _G.GetCurrentKeyBoardFocus = function() return nil end
    _G.GetBindingKey = function() return nil end
    _G.GetBindingText = function(k) return k or "" end
    _G.GetBindingAction = function() return "" end
    _G.GetBindingFromClick = function() return nil end
    _G.GetCurrentBindingSet = function() return 1 end
    _G.SetBinding = function() return true end
    _G.SetBindingClick = function() return true end
    _G.SetOverrideBinding = function() end
    _G.SetOverrideBindingClick = function() end
    _G.ClearOverrideBindings = function() end
    _G.SaveBindings = function() end
    _G.IsKeyPressIgnoredForBinding = function() return false end

    -- CVars: Szenario-Werte, sonst registrierte Standardwerte.
    local defaults = {}
    local function getCVar(name)
        if name == nil then return nil end
        local v = state.cvars[name]
        if v == nil then v = defaults[name] end
        if v == nil then v = G.CVAR_DEFAULTS[name] end
        if type(v) == "boolean" then v = v and "1" or "0" end
        return v ~= nil and tostring(v) or nil
    end
    _G.C_CVar = _G.C_CVar or {}
    C_CVar.GetCVar = getCVar
    C_CVar.SetCVar = function(name, value) state.cvars[name] = value ~= nil and tostring(value) or nil return true end
    C_CVar.GetCVarBool = function(name) local v = getCVar(name) return v == "1" or v == "true" end
    C_CVar.GetCVarDefault = function(name) return defaults[name] or G.CVAR_DEFAULTS[name] end
    C_CVar.RegisterCVar = function(name, value) defaults[name] = value ~= nil and tostring(value) or nil end
    C_CVar.GetCVarInfo = function(name)
        local v = getCVar(name)
        if v == nil then return nil end
        return v, defaults[name] or v, false, false, false, false, false
    end
    _G.GetCVar = getCVar
    _G.SetCVar = C_CVar.SetCVar
    _G.GetCVarBool = C_CVar.GetCVarBool
    _G.GetCVarDefault = C_CVar.GetCVarDefault
    _G.RegisterCVar = C_CVar.RegisterCVar

    -- Klassenfarben (C_ClassColor) wie RAID_CLASS_COLORS.
    _G.C_ClassColor = _G.C_ClassColor or {}
    C_ClassColor.GetClassColor = function(cls)
        local c = G.CLASS_COLORS[cls]
        if not c then return nil end
        return CreateColor and CreateColor(c[1], c[2], c[3], 1) or { r = c[1], g = c[2], b = c[3] }
    end
end

-- CVars, die Blizzards Code und die Addons beim Start lesen.
G.CVAR_DEFAULTS = {
    useUiScale = "1", uiScale = "0.77", textLocale = "enUS", portal = "EU", colorblindMode = "0",
    scriptErrors = "1", ActionButtonUseKeyDown = "1", nameplateShowSelf = "0", cameraSmoothStyle = "0",
    statusText = "1", statusTextDisplay = "NUMERIC", showTargetOfTarget = "1", damageMeterEnabled = "1",
    UserTextScale = "1", userFontScale = "1", graphicsQuality = "7", lockActionBars = "1",
}

return G
