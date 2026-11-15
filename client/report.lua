-- Sammelt Lua-Fehler (wie BugGrabber, mit Stack und Zaehler) und Aufrufe
-- nicht nachgebauter APIs, jeweils dem Addon zugeordnet, aus dessen Datei
-- der Aufruf kam.
local R = { errors = {}, errorOrder = {}, missing = {}, notes = {}, addonRoots = {} }

local MAX_STACK_DEPTH = 40

-- root: absoluter Ordner eines Addons; Name fuer den Bericht.
function R.AddRoot(root, name)
    R.addonRoots[#R.addonRoots + 1] = { root = root, name = name }
end

local function ownerOfSource(src)
    if not src then return nil end
    src = src:gsub("^@", "")
    for _, r in ipairs(R.addonRoots) do
        if src:sub(1, #r.root) == r.root then return r.name end
    end
    return nil
end

-- Erstes Addon im Aufrufstapel (Blizzard-Code und der Client selbst zaehlen nicht).
function R.Caller()
    for level = 3, MAX_STACK_DEPTH do
        local info = debug.getinfo(level, "S")
        if not info then break end
        local owner = ownerOfSource(info.source)
        if owner then return owner end
    end
    return "(Blizzard/Client)"
end

function R.Missing(kind, name)
    local owner = R.Caller()
    local byOwner = R.missing[owner]
    if not byOwner then byOwner = {} R.missing[owner] = byOwner end
    local key = kind .. " " .. name
    byOwner[key] = (byOwner[key] or 0) + 1
end

function R.Note(text)
    if not R.notes[text] then
        R.notes[text] = true
        R.notes[#R.notes + 1] = text
    end
end

-- Kuerzt absolute Pfade im Stack auf Addon-relative.
local function tidy(s)
    for _, r in ipairs(R.addonRoots) do
        s = s:gsub(r.root:gsub("%p", "%%%0") .. "/", r.name .. "/")
    end
    return s
end

function R.Error(msg, stack)
    msg = tidy(tostring(msg))
    local e = R.errors[msg]
    if e then
        e.count = e.count + 1
        return
    end
    e = { message = msg, stack = tidy(stack or ""), count = 1, owner = ownerOfSource(msg:match("^([^:]+):")), phase = R.phase }
    R.errors[msg] = e
    R.errorOrder[#R.errorOrder + 1] = e
end

-- Ruft fn geschuetzt auf; ein Fehler bricht den Lauf nie ab.
function R.Call(fn, ...)
    local args, n = { ... }, select("#", ...)
    local res = { xpcall(function() return fn(unpack(args, 1, n)) end, function(err)
        R.Error(err, debug.traceback("", 2))
        return err
    end) }
    if res[1] then return unpack(res, 2, table.maxn(res)) end
    return nil
end

function R.Summary()
    local errs = {}
    for _, e in ipairs(R.errorOrder) do
        errs[#errs + 1] = { message = e.message, count = e.count, stack = e.stack, owner = e.owner, phase = e.phase }
    end
    local missing = {}
    for owner, t in pairs(R.missing) do
        local list = {}
        for k, n in pairs(t) do list[#list + 1] = { api = k, calls = n } end
        table.sort(list, function(a, b) return a.api < b.api end)
        missing[owner] = list
    end
    local notes = {}
    for i = 1, #R.notes do notes[i] = R.notes[i] end
    return { errors = errs, missing = missing, notes = notes }
end

return R
