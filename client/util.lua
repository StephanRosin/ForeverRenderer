-- Kleine Hilfen ohne WoW-Bezug: JSON-Ausgabe, Dateien, Pfade.
local U = {}

local function esc(s)
    return (s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
        elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" end
        return string.format("\\u%04x", c:byte())
    end))
end

-- Zahlen kurz halten: die Zeichenliste wird sonst unnoetig gross.
local function num(n)
    if n ~= n or n == math.huge or n == -math.huge then return "null" end
    if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%d", n) end
    return (string.format("%.4f", n):gsub("0+$", ""):gsub("%.$", ""))
end

local function isArray(t)
    local n = #t
    if n > 0 then return true end
    return next(t) == nil
end

function U.json(v, out)
    out = out or {}
    local t = type(v)
    if t == "table" then
        if isArray(v) and next(v) ~= nil then
            out[#out + 1] = "["
            for i = 1, #v do
                if i > 1 then out[#out + 1] = "," end
                U.json(v[i], out)
            end
            out[#out + 1] = "]"
        elseif next(v) == nil then
            out[#out + 1] = "{}"
        else
            out[#out + 1] = "{"
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = '"' .. esc(k) .. '":'
                local val = v[k]
                if val == nil then val = v[tonumber(k)] end
                U.json(val, out)
            end
            out[#out + 1] = "}"
        end
    elseif t == "string" then out[#out + 1] = '"' .. esc(v) .. '"'
    elseif t == "number" then out[#out + 1] = num(v)
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    else out[#out + 1] = "null" end
    return out
end

function U.encode(v) return table.concat(U.json(v)) end

function U.readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

function U.writeFile(path, s)
    local f = assert(io.open(path, "wb"))
    f:write(s)
    f:close()
end

function U.exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

-- Verzeichnisinhalt (nur Namen); ls ist hier verlaesslicher als lfs, das fehlt.
function U.listDir(path)
    local out = {}
    local p = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

-- WoW-Pfade sind gross/klein-unabhaengig und nutzen Backslashes.
function U.normPath(p)
    return (p:gsub("\\", "/"):gsub("//+", "/"):lower())
end

function U.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function U.split(s, sep)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
    return out
end

return U
