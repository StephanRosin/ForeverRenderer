-- Geheime Werte ("Secret Values") wie im Forever-Client: Addons duerfen sie
-- weiterreichen (SetText, StatusBar-Werte, string.format mit %s/%f), aber
-- nicht rechnen, vergleichen oder als Tabellenschluessel nutzen. Ein
-- Szenario markiert Werte als geheim; der Zeichner sieht den echten Wert.
local S = {}
local type = type -- vor dem Ersetzen von _G.type sichern

local raw = setmetatable({}, { __mode = "k" })
local proto = newproxy(true)
local meta = getmetatable(proto)

local function refuse(what)
    return function() error("attempt to " .. what .. " a secret value", 2) end
end
for _, op in ipairs({ "add", "sub", "mul", "div", "mod", "pow", "unm" }) do meta["__" .. op] = refuse("perform arithmetic on") end
meta.__lt = refuse("compare")
meta.__le = refuse("compare")
meta.__eq = refuse("compare")
meta.__len = refuse("get length of")
meta.__index = refuse("index")
meta.__newindex = refuse("index")
meta.__call = refuse("call")
-- Verkettung ist erlaubt und liefert wieder ein Geheimnis.
meta.__concat = function(a, b)
    return S.Wrap(tostring(S.Unwrap(a)) .. tostring(S.Unwrap(b)))
end
meta.__tostring = function(u) return tostring(raw[u][1]) end

function S.Wrap(v)
    if v == nil then return nil end
    local u = newproxy(proto)
    raw[u] = { v }
    return u
end

function S.Is(v) return type(v) == "userdata" and raw[v] ~= nil end

function S.Unwrap(v)
    if type(v) == "userdata" and raw[v] then return raw[v][1] end
    return v
end

function S.AnyArg(...)
    for i = 1, select("#", ...) do
        if S.Is((select(i, ...))) then return true end
    end
    return false
end

-- Wie der Client: type() meldet den Typ des verborgenen Werts.
local plainType = type
function S.Type(v)
    if plainType(v) == "userdata" and raw[v] then return plainType(raw[v][1]) end
    return plainType(v)
end

-- string.format nimmt Geheimnisse nur fuer %s und %f mit Genauigkeit
-- (so steht es in den Addon-Seiten im Vault); das Ergebnis ist geheim.
local plainFormat = string.format
function S.Format(fmt, ...)
    if not S.AnyArg(...) then return plainFormat(fmt, ...) end
    if S.Is(fmt) then error("secret value used as a format string", 2) end
    local args, n, i = { ... }, select("#", ...), 0
    for spec, conv in fmt:gmatch("%%([-+ #0]*%d*%.?%d*)([%a%%])") do
        if conv ~= "%" then
            i = i + 1
            if S.Is(args[i]) then
                local ok = conv == "s" or (conv == "f" and spec:find("%."))
                if not ok then error("secret value with %" .. spec .. conv .. " in string.format", 2) end
                args[i] = raw[args[i]][1]
            end
        end
    end
    return S.Wrap(plainFormat(fmt, unpack(args, 1, n)))
end

return S
