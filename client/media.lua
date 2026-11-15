-- Loest Textur- und Schriftpfade auf wie der Client: Addon-Pfade in die
-- Addon-Repos, alles andere ins Grafik-Archiv (tools/extract-art), Zahlen
-- als FileDataID. Dazu die Atlas-Tabelle.
local U = require("util")

local M = { addonDirs = {}, files = {}, byId = {}, atlas = {}, artDir = nil }

local ADDON_PREFIX = "interface/addons/"
local TEXTURE_EXTS = { ".tga", ".blp", ".png", ".jpg" }

-- Kleiner JSON-Leser fuer atlas.json (nur Objekte, Zahlen, Texte, Wahrheitswerte).
local function decodeJson(s)
    local pos = 1
    local function ws() pos = s:find("[^ \t\r\n]", pos) or #s + 1 end
    local value
    local function str()
        local out, i = {}, pos + 1
        while true do
            local c = s:sub(i, i)
            if c == '"' then break end
            if c == "\\" then
                local n = s:sub(i + 1, i + 1)
                if n == "u" then
                    out[#out + 1] = string.char(tonumber(s:sub(i + 2, i + 5), 16) % 256)
                    i = i + 6
                else
                    out[#out + 1] = ({ n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" })[n] or n
                    i = i + 2
                end
            else
                out[#out + 1] = c
                i = i + 1
            end
        end
        pos = i + 1
        return table.concat(out)
    end
    function value()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
            while true do
                ws()
                local k = str()
                ws()
                pos = pos + 1 -- ':'
                t[k] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return t end
            end
        elseif c == "[" then
            local t = {}
            pos = pos + 1
            ws()
            if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
            while true do
                t[#t + 1] = value()
                ws()
                local d = s:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return t end
            end
        elseif c == '"' then return str()
        elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
        elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
        elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
        else
            local num = s:match("^-?[%d.eE+-]+", pos)
            pos = pos + #num
            return tonumber(num)
        end
    end
    return value()
end
M.DecodeJson = decodeJson

-- Ordnername des Addons -> Repo-Ordner.
function M.AddAddonDir(name, dir)
    M.addonDirs[name:lower()] = dir
end

function M.LoadArt(artDir)
    M.artDir = artDir
    local tsv = artDir and U.readFile(artDir .. "/index.tsv")
    if not tsv then return false end
    for line in tsv:gmatch("[^\n]+") do
        local fdid, path, rel, w, h = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(%d+)\t(%d+)")
        if fdid then
            local e = { fdid = tonumber(fdid), file = artDir .. "/" .. rel, w = tonumber(w), h = tonumber(h) }
            M.files[path] = e
            M.byId[e.fdid] = e
        end
    end
    local atlas = U.readFile(artDir .. "/atlas.json")
    if atlas then M.atlas = decodeJson(atlas) end
    return true
end

-- Liefert { file = absoluter Pfad, w, h, fdid } oder nil.
function M.Texture(path)
    if type(path) == "number" then return M.byId[path] end
    if type(path) ~= "string" or path == "" then return nil end
    if path:match("^%d+$") then return M.byId[tonumber(path)] end
    local p = U.normPath(path)
    if p:sub(1, #ADDON_PREFIX) == ADDON_PREFIX then
        local rest = p:sub(#ADDON_PREFIX + 1)
        local addon, sub = rest:match("^([^/]+)/(.+)$")
        local dir = addon and M.addonDirs[addon]
        if dir then
            local base = dir .. "/" .. M.CaseInsensitive(dir, sub)
            if U.exists(base) and base:match("%.%w+$") then return { file = base } end
            for _, ext in ipairs(TEXTURE_EXTS) do
                local cand = dir .. "/" .. M.CaseInsensitive(dir, sub .. ext)
                if U.exists(cand) then return { file = cand } end
            end
        end
        return nil
    end
    local noExt = p:gsub("%.%w+$", "")
    return M.files[noExt]
end

-- Addon-Dateien liegen auf einem echten Dateisystem mit Gross-/Kleinschreibung;
-- WoW ignoriert sie. Pfad stueckweise gegen die Ordnerinhalte aufloesen.
local dirCache = {}
function M.CaseInsensitive(root, rel)
    local cur, out = root, {}
    for part in rel:gmatch("[^/]+") do
        local list = dirCache[cur]
        if not list then
            list = {}
            for _, n in ipairs(U.listDir(cur)) do list[n:lower()] = n end
            dirCache[cur] = list
        end
        local real = list[part:lower()] or part
        out[#out + 1] = real
        cur = cur .. "/" .. real
    end
    return table.concat(out, "/")
end

function M.Font(path)
    if type(path) ~= "string" or path == "" then return nil end
    local p = U.normPath(path)
    if p:sub(1, #ADDON_PREFIX) == ADDON_PREFIX then
        local addon, sub = p:sub(#ADDON_PREFIX + 1):match("^([^/]+)/(.+)$")
        local dir = addon and M.addonDirs[addon]
        if dir then
            local f = dir .. "/" .. M.CaseInsensitive(dir, sub)
            if U.exists(f) then return f end
        end
        return nil
    end
    if M.artDir then
        local name = p:match("([^/]+)$")
        local f = M.artDir .. "/fonts/" .. name
        if U.exists(f) then return f end
    end
    return nil
end

function M.Atlas(name)
    if type(name) ~= "string" then return nil end
    local a = M.atlas[name:lower()]
    if not a then return nil end
    if not a.abs and M.artDir then a.abs = M.artDir .. "/" .. a.file end
    return a
end

return M
