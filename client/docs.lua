-- Liest Blizzards generierte API-Doku (Blizzard_APIDocumentationGenerated).
-- Daraus kommen: Enum.*, Constants.*, die gueltigen Ereignisnamen, die
-- dokumentierten C_*-Funktionen und die Methoden je Widget-Typ. Was dort
-- steht, gibt es im echten Client; fehlt die Nachbildung, wird der Aufruf
-- protokolliert statt still verschluckt.
local U = require("util")

local D = { systems = {}, scriptObjects = {}, events = {}, enums = {}, constants = {}, globalFunctions = {}, loadErrors = {} }

-- Zwei Durchgaenge: Konstanten verweisen beim Laden auf Enum.*, die erst
-- aus allen Dateien zusammen entstehen.
local function loadAll(dir, enumTable, constTable)
    local tables = {}
    local env = setmetatable({
        Enum = enumTable,
        Constants = constTable,
        APIDocumentation = { AddDocumentationTable = function(_, t) tables[#tables + 1] = t end },
    }, { __index = _G })
    for _, f in ipairs(U.listDir(dir)) do
        if f:match("%.lua$") then
            local chunk = loadfile(dir .. "/" .. f)
            if chunk then
                setfenv(chunk, env)
                local ok, err = pcall(chunk)
                if not ok then D.loadErrors[#D.loadErrors + 1] = f .. ": " .. tostring(err) end
            end
        end
    end
    return tables
end

local function lazyEnum()
    return setmetatable({}, { __index = function(t, k)
        local e = setmetatable({}, { __index = function() return 0 end })
        rawset(t, k, e)
        return e
    end })
end

function D.Load(uiSource)
    local dir = uiSource .. "/Blizzard_APIDocumentationGenerated"
    -- Drei Durchgaenge: Enum und Constants verweisen aufeinander.
    local function collect(tables)
        local enum, consts = {}, {}
        for _, t in ipairs(tables) do
            for _, tab in ipairs(t.Tables or {}) do
                if tab.Type == "Enumeration" then
                    local e = {}
                    for _, f in ipairs(tab.Fields or {}) do e[f.Name] = f.EnumValue end
                    enum[tab.Name] = e
                    -- Der Client liefert zu jedem Enum X auch XMeta (Anzahl, Grenzen).
                    enum[tab.Name .. "Meta"] = { NumValues = tab.NumValues, MinValue = tab.MinValue, MaxValue = tab.MaxValue }
                elseif tab.Type == "Constants" then
                    local c = {}
                    for _, v in ipairs(tab.Values or {}) do c[v.Name] = v.Value end
                    consts[tab.Name] = c
                end
            end
        end
        return enum, consts
    end
    local enum, consts = collect(loadAll(dir, lazyEnum(), lazyEnum()))
    enum, consts = collect(loadAll(dir, enum, consts))
    D.loadErrors = {}
    local all = loadAll(dir, enum, consts)
    enum, consts = collect(all)
    D.enums = enum
    D.constants = consts
    for _, t in ipairs(all) do
        if t.Type == "ScriptObject" then
            D.scriptObjects[t.Name] = t
        else
            D.systems[#D.systems + 1] = t
            for _, fn in ipairs(t.Functions or {}) do
                if not t.Namespace then D.globalFunctions[fn.Name] = fn end
            end
        end
        for _, ev in ipairs(t.Events or {}) do D.events[ev.LiteralName] = ev end
    end
    return D
end

-- Nicht alle Ereignisse stehen in der Doku (VARIABLES_LOADED u. a.). Was
-- Blizzards eigener Code anmeldet, gibt es im Client sicher.
function D.ScanEvents(uiSource)
    local cmd = "grep -rhoE '(RegisterEvent|RegisterUnitEvent|UnregisterEvent)\\(\"[A-Z0-9_]+\"' --include='*.lua' '" .. uiSource .. "'"
    local p = io.popen(cmd)
    local n = 0
    for line in p:lines() do
        local ev = line:match('"([A-Z0-9_]+)"')
        if ev and not D.events[ev] then D.events[ev] = { LiteralName = ev, fromSource = true } n = n + 1 end
    end
    p:close()
    return n
end

-- Namen der dokumentierten Methoden einer ScriptObject-Doku ("SimpleFrameAPI").
function D.Methods(docName)
    local t = D.scriptObjects[docName]
    local out = {}
    if t then
        for _, fn in ipairs(t.Functions or {}) do out[#out + 1] = fn.Name end
    end
    return out
end

return D
