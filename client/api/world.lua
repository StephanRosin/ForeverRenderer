-- Was die Figur hat und weiss, aus dem Szenario: Makros, Taschen und
-- Gegenstaende, Zauber, Fertigkeiten, Ruf, Waehrungen, Quests.
-- Fehlt ein Eintrag, antwortet die API wie ein leerer Spielstand.
--
-- shortcut: Zauber- und Gegenstandsnamen kommen nur aus dem Szenario (sonst
-- "Spell <id>" und das Fragezeichen-Symbol); fuer echte Namen SpellName/Item
-- aus den DB2 in tools/extract-art ziehen.
local W = require("widgets")

local X = {}

local QUESTION_MARK_ICON = 134400
local BAG_IDS = { 0, 1, 2, 3, 4 }

local state

local function list(name) state[name] = state[name] or {} return state[name] end

local function itemOf(id)
    local items = list("items")
    return items[id]
end

local function spellOf(id)
    if type(id) == "string" then
        for sid, sp in pairs(list("spells")) do
            if sp.name == id then return sp, sid end
        end
        return nil
    end
    local sp = list("spells")[id]
    if sp then return sp, id end
    if type(id) == "number" and id > 0 then return { name = "Spell " .. id, icon = QUESTION_MARK_ICON, unknown = true }, id end
    return nil
end

local function installMacros()
    local macros = list("macros")
    local function index(name)
        for i, m in ipairs(macros) do if m.name == name then return i end end
        return 0
    end
    _G.GetMacroIndexByName = index
    _G.GetMacroBody = function(i)
        local m = macros[type(i) == "string" and index(i) or i]
        return m and m.body
    end
    _G.GetMacroInfo = function(i)
        local m = macros[type(i) == "string" and index(i) or i]
        if not m then return nil end
        return m.name, m.icon or QUESTION_MARK_ICON, m.body
    end
    _G.GetNumMacros = function() return #macros, 0 end
    _G.CreateMacro = function(name, icon, body)
        macros[#macros + 1] = { name = name, icon = icon, body = body }
        return #macros
    end
    _G.EditMacro = function(i, name, icon, body)
        i = type(i) == "string" and index(i) or i
        local m = macros[i]
        if not m then return nil end
        m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
        return i
    end
    _G.DeleteMacro = function(i)
        i = type(i) == "string" and index(i) or i
        if macros[i] then table.remove(macros, i) end
    end
    _G.GetMacroIcons = function() return {} end
    _G.GetMacroItemIcons = function() return {} end
    _G.MAX_ACCOUNT_MACROS, _G.MAX_CHARACTER_MACROS = 120, 18
end

local function installItems()
    local bags = list("bags")
    local function bag(id) return bags[id] or (id == 0 and { size = 16 } or nil) end
    _G.C_Container = _G.C_Container or {}
    C_Container.GetContainerNumSlots = function(id) local b = bag(id) return b and b.size or 0 end
    C_Container.GetContainerNumFreeSlots = function(id)
        local b = bag(id)
        if not b then return 0, 0 end
        local used = 0
        for _ in pairs(b.items or {}) do used = used + 1 end
        return b.size - used, b.family or 0
    end
    C_Container.GetContainerItemID = function(id, slot) local b = bag(id) local it = b and b.items and b.items[slot] return it and it.id end
    C_Container.GetContainerItemInfo = function(id, slot)
        local b = bag(id)
        local it = b and b.items and b.items[slot]
        if not it then return nil end
        local info = itemOf(it.id) or {}
        return { iconFileID = info.icon or QUESTION_MARK_ICON, stackCount = it.count or 1, isLocked = false, quality = info.quality or 1,
            isReadable = false, hasLoot = false, hyperlink = "|Hitem:" .. it.id .. "|h[" .. (info.name or "Item") .. "]|h",
            isFiltered = false, hasNoValue = false, itemID = it.id, isBound = false, itemName = info.name or "Item" }
    end
    C_Container.GetItemCooldown = function(id)
        local info = itemOf(id)
        local cd = info and info.cooldown
        if not cd then return 0, 0, 1 end
        return W.now() - (cd.elapsed or 0), cd.duration, 1
    end
    C_Container.GetBagName = function(id) local b = bag(id) return b and b.name end
    _G.GetContainerNumSlots = C_Container.GetContainerNumSlots
    _G.GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots

    local function count(id)
        local n = 0
        for _, bid in ipairs(BAG_IDS) do
            local b = bag(bid)
            for _, it in pairs(b and b.items or {}) do if it.id == id then n = n + (it.count or 1) end end
        end
        local info = itemOf(id)
        if n == 0 and info and info.count then n = info.count end
        return n
    end
    _G.C_Item = _G.C_Item or {}
    C_Item.GetItemCount = function(id) return count(id) end
    _G.GetItemCount = C_Item.GetItemCount
    local function itemInfo(id)
        if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) or id end
        local info = itemOf(id)
        if not info then return nil end
        local link = "|cffffffff|Hitem:" .. id .. "|h[" .. info.name .. "]|h|r"
        return info.name, link, info.quality or 1, info.itemLevel or 1, info.minLevel or 1, info.type or "Consumable",
            info.subType or "", info.stack or 20, info.equipLoc or "", info.icon or QUESTION_MARK_ICON, info.sellPrice or 0,
            info.classID or 0, info.subclassID or 0
    end
    C_Item.GetItemInfo = itemInfo
    _G.GetItemInfo = itemInfo
    C_Item.GetItemInfoInstant = function(id)
        local info = itemOf(id)
        if not info then return nil end
        return id, info.type or "Consumable", info.subType or "", info.equipLoc or "", info.icon or QUESTION_MARK_ICON, info.classID or 0, info.subclassID or 0
    end
    C_Item.GetItemNameByID = function(id) local i = itemOf(id) return i and i.name end
    C_Item.GetItemIconByID = function(id) local i = itemOf(id) return i and i.icon or QUESTION_MARK_ICON end
    C_Item.GetItemQualityByID = function(id) local i = itemOf(id) return i and i.quality end
    C_Item.IsItemDataCachedByID = function(id) return itemOf(id) ~= nil end
    C_Item.RequestLoadItemDataByID = function() end
    C_Item.GetItemSpell = function(id) local i = itemOf(id) if i and i.spell then local sp = spellOf(i.spell) return sp and sp.name, i.spell end return nil end
    C_Item.IsItemInRange = function() return true end
    C_Item.GetWeaponEnchantInfo = function() return false end
    _G.GetItemSpell = C_Item.GetItemSpell
    _G.GetItemIcon = C_Item.GetItemIconByID
end

local function installSpells()
    _G.C_Spell = _G.C_Spell or {}
    C_Spell.GetSpellInfo = function(id)
        local sp, sid = spellOf(id)
        if not sp then return nil end
        return { name = sp.name, iconID = sp.icon or QUESTION_MARK_ICON, originalIconID = sp.icon or QUESTION_MARK_ICON,
            castTime = sp.castTime or 0, minRange = 0, maxRange = sp.range or 0, spellID = sid }
    end
    C_Spell.GetSpellName = function(id) local sp = spellOf(id) return sp and sp.name end
    C_Spell.GetSpellTexture = function(id) local sp = spellOf(id) return sp and (sp.icon or QUESTION_MARK_ICON) end
    C_Spell.GetSpellIDForSpellIdentifier = function(id) local _, sid = spellOf(id) return sid end
    C_Spell.GetSpellDescription = function(id) local sp = spellOf(id) return sp and sp.description or "" end
    C_Spell.IsSpellUsable = function(id) local sp = spellOf(id) return sp ~= nil and not sp.unknown, false end
    C_Spell.IsSpellInRange = function() return true end
    C_Spell.GetSpellCooldown = function(id)
        local sp = spellOf(id)
        local cd = sp and sp.cooldown
        if not cd then return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end
        return { startTime = W.now() - (cd.elapsed or 0), duration = cd.duration, isEnabled = true, modRate = 1 }
    end
    C_Spell.GetSpellPowerCost = function(id) local sp = spellOf(id) return sp and sp.cost or {} end
    _G.C_SpellBook = _G.C_SpellBook or {}
    C_SpellBook.IsSpellKnown = function(id) local sp = list("spells")[id] return sp ~= nil and sp.known ~= false end
    C_SpellBook.IsSpellInSpellBook = C_SpellBook.IsSpellKnown
    _G.IsSpellKnown = C_SpellBook.IsSpellKnown
    _G.IsPlayerSpell = C_SpellBook.IsSpellKnown
    _G.GetSpellInfo = function(id)
        local info = C_Spell.GetSpellInfo(id)
        if not info then return nil end
        return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
    end
    _G.GetSpellTexture = C_Spell.GetSpellTexture
end

local function installSkills()
    local skills = list("skills")
    _G.C_SkillInfo = _G.C_SkillInfo or {}
    local function visible()
        local out, collapsed = {}, false
        for _, s in ipairs(skills) do
            if s.isHeader then
                out[#out + 1] = s
                collapsed = s.isCollapsed
            elseif not collapsed then
                out[#out + 1] = s
            end
        end
        return out
    end
    C_SkillInfo.GetNumSkillLines = function() return #visible() end
    C_SkillInfo.GetSkillLineInfo = function(i)
        local s = visible()[i]
        if not s then return nil end
        return { skillID = s.skillID or 0, name = s.name, isHeader = s.isHeader or false, isCollapsed = s.isCollapsed or false,
            rank = s.rank or 0, tempPoints = 0, modifier = s.modifier or 0, maxRank = s.maxRank or 0, isAbandonable = not s.isHeader,
            stepCost = 0, rankCost = 0, minLevel = 0, costType = 0, parentSkillLineID = 0, skillLineCategoryID = 0, description = "" }
    end
    C_SkillInfo.ExpandSkillHeader = function(i) local s = visible()[i] if s then s.isCollapsed = false end end
    C_SkillInfo.CollapseSkillHeader = function(i) local s = visible()[i] if s then s.isCollapsed = true end end
    _G.GetProfessions = function() return nil end
end

local function installReputation()
    local factions = list("factions")
    _G.C_Reputation = _G.C_Reputation or {}
    local function visible()
        local out, collapsed = {}, false
        for _, f in ipairs(factions) do
            if f.isHeader then
                out[#out + 1] = f
                collapsed = f.isCollapsed
            elseif not collapsed then
                out[#out + 1] = f
            end
        end
        return out
    end
    local function data(f)
        return { factionID = f.factionID or 0, name = f.name, description = f.description or "", reaction = f.reaction or 4,
            currentReactionThreshold = f.min or 0, nextReactionThreshold = f.max or 3000, currentStanding = f.value or 0,
            atWarWith = false, canToggleAtWar = false, isChild = false, isHeader = f.isHeader or false, isHeaderWithRep = false,
            isCollapsed = f.isCollapsed or false, isWatched = f.isWatched or false, hasBonusRepGain = false, canSetInactive = false,
            isAccountWide = false }
    end
    C_Reputation.GetNumFactions = function() return #visible() end
    C_Reputation.GetFactionDataByIndex = function(i) local f = visible()[i] return f and data(f) end
    C_Reputation.GetFactionDataByID = function(id)
        for _, f in ipairs(factions) do if f.factionID == id then return data(f) end end
        return nil
    end
    C_Reputation.GetWatchedFactionData = function()
        for _, f in ipairs(factions) do if f.isWatched then return data(f) end end
        return nil
    end
    C_Reputation.ExpandFactionHeader = function(i) local f = visible()[i] if f then f.isCollapsed = false end end
    C_Reputation.CollapseFactionHeader = function(i) local f = visible()[i] if f then f.isCollapsed = true end end
    C_Reputation.IsFactionParagon = function() return false end
    C_Reputation.IsMajorFaction = function() return false end
end

local function installCurrencies()
    local cur = list("currencies")
    _G.C_CurrencyInfo = _G.C_CurrencyInfo or {}
    C_CurrencyInfo.GetCurrencyInfo = function(id)
        local c = cur[id]
        if not c then return nil end
        return { name = c.name, description = "", currencyID = id, isHeader = false, isHeaderExpanded = false, currencyListDepth = 0,
            isTypeUnused = false, isShowInBackpack = false, quantity = c.quantity or 0, trackedQuantity = 0,
            iconFileID = c.icon or QUESTION_MARK_ICON, maxQuantity = c.max or 0, canEarnPerWeek = false, quantityEarnedThisWeek = 0,
            isTradeable = false, quality = 1, maxWeeklyQuantity = 0, totalEarned = c.quantity or 0, discovered = true,
            useTotalEarnedForMaxQty = false, isAccountWide = false, isAccountTransferable = false, transferPercentage = 0,
            rechargingCycleDurationMS = 0, rechargingAmountPerCycle = 0 }
    end
    C_CurrencyInfo.GetCurrencyListSize = function() local n = 0 for _ in pairs(cur) do n = n + 1 end return n end
end

local function installQuests()
    local quests = list("quests")
    local byID = {}
    for i, q in ipairs(quests) do
        q.questLogIndex = i
        if q.questID then byID[q.questID] = q end
    end
    local watched = {}
    for _, q in ipairs(quests) do if q.watched then watched[#watched + 1] = q.questID end end
    _G.C_QuestLog = _G.C_QuestLog or {}
    local QL = C_QuestLog
    QL.GetNumQuestLogEntries = function()
        local n = 0
        for _, q in ipairs(quests) do if not q.isHeader then n = n + 1 end end
        return #quests, n
    end
    QL.GetInfo = function(i)
        local q = quests[i]
        if not q then return nil end
        return { title = q.title, questLogIndex = i, questID = q.questID or 0, campaignID = 0, level = q.level or 60,
            difficultyLevel = q.level or 60, suggestedGroup = q.suggestedGroup or 0, frequency = 0, isHeader = q.isHeader or false,
            useMinimalHeader = false, sortAsNormalQuest = false, isCollapsed = q.isCollapsed or false, startEvent = false,
            isTask = false, isBounty = false, isStory = false, isScaling = false, isOnMap = true, hasLocalPOI = false,
            isHidden = false, isAutoComplete = false, overridesSortOrder = false, readyForTranslation = true,
            isInternalOnly = false, isAbandonOnDisable = false, headerSortKey = 0, questClassification = 0 }
    end
    QL.GetLogIndexForQuestID = function(id) local q = byID[id] return q and q.questLogIndex end
    QL.GetTitleForQuestID = function(id) local q = byID[id] return q and q.title end
    QL.GetQuestDifficultyLevel = function(id) local q = byID[id] return q and q.level or 60 end
    QL.IsComplete = function(id) local q = byID[id] return q and q.complete or false end
    QL.IsFailed = function(id) local q = byID[id] return q and q.failed or false end
    QL.GetQuestObjectives = function(id)
        local q = byID[id]
        local out = {}
        for i, o in ipairs(q and q.objectives or {}) do
            out[i] = { text = o.text, type = o.type or "monster", finished = o.finished or (o.have and o.need and o.have >= o.need) or false,
                numFulfilled = o.have or 0, numRequired = o.need or 1, objectiveType = 0 }
        end
        return out
    end
    QL.GetNumQuestWatches = function() return #watched end
    QL.GetQuestIDForQuestWatchIndex = function(i) return watched[i] end
    QL.IsQuestFlaggedCompleted = function() return false end
    QL.GetAllCompletedQuestIDs = function() return {} end
    QL.GetMaxNumQuestsCanAccept = function() return 25 end
    QL.GetRequiredMoney = function() return 0 end
    QL.GetTimeAllowed = function() return nil end
    QL.GetQuestTagInfo = function(id) local q = byID[id] return q and q.tag end
    QL.IsPushableQuest = function() return true end
    QL.GetNextWaypointText = function() return nil end
    QL.AddQuestWatch = function(id) watched[#watched + 1] = id return true end
    QL.RemoveQuestWatch = function(id)
        for i, w in ipairs(watched) do if w == id then table.remove(watched, i) return true end end
        return false
    end
    QL.GetSelectedQuest = function() return state.selectedQuest or 0 end
    QL.SetSelectedQuest = function(id) state.selectedQuest = id end
    _G.C_SuperTrack = _G.C_SuperTrack or {}
    C_SuperTrack.GetSuperTrackedQuestID = function() return state.superTracked or 0 end
    C_SuperTrack.SetSuperTrackedQuestID = function(id) state.superTracked = id end
    C_SuperTrack.ClearAllSuperTracked = function() state.superTracked = 0 end
    _G.GetQuestLogSpecialItemInfo = function() return nil end
    _G.GetNumQuestLeaderBoards = function(i) local q = quests[i] return q and #(q.objectives or {}) or 0 end
end

local function installMisc()
    _G.C_ClassTalents = _G.C_ClassTalents or {}
    C_ClassTalents.HasUnspentTalentPoints = function() return (state.unspentTalents or 0) > 0 end
    _G.C_TradeSkillUI = _G.C_TradeSkillUI or {}
    C_TradeSkillUI.GetRecipesTracked = function() return {} end
    _G.IsPVPTimerRunning = function() return false end
    _G.GetPVPTimer = function() return 0 end
    _G.C_EventUtils = _G.C_EventUtils or {}
    C_EventUtils.IsEventValid = function(ev) return W.validEvent(ev) end
    -- Kampfmeter: Szenario setzt damageMeter = { sessions = ... } (siehe api/meter.lua).
    _G.C_DamageMeter = _G.C_DamageMeter or {}
    C_DamageMeter.IsDamageMeterAvailable = function() return state.damageMeter ~= false end
end

-- Minimap-Rahmen: Zoom und Maske speichern, die Karte zeichnet der Zeichner als Platzhalter.
local function installMinimapMethods()
    local M = W.classes.Minimap.methods
    local st = W.st
    function M:GetZoom() return st(self).zoom or 0 end
    function M:SetZoom(z) st(self).zoom = z end
    function M:GetZoomLevels() return 6 end
    function M:SetMaskTexture(t) st(self).mapMask = t end
    function M:SetBlipTexture() end
    function M:SetPlayerTexture() end
    function M:SetArchBlobRingScalar() end
    function M:SetQuestBlobRingScalar() end
    function M:SetTaskBlobRingScalar() end
    function M:SetArchBlobRingAlpha() end
    function M:SetQuestBlobRingAlpha() end
    function M:SetTaskBlobRingAlpha() end
    function M:SetStaticPOIArrowTexture() end
    function M:SetPOIArrowTexture() end
    function M:SetCorpsePOIArrowTexture() end
    function M:UpdateBlips() end
    function M:GetPingPosition() return 0, 0 end
    function M:PingLocation() end
    _G.GetMinimapShape = _G.GetMinimapShape or function() return "ROUND" end
end

function X.Install(st, env)
    state = st
    installMacros()
    installItems()
    installSpells()
    installSkills()
    installReputation()
    installCurrencies()
    installQuests()
    installMisc()
    installMinimapMethods()
end

return X
