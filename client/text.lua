-- Textsatz fuer FontStrings: Steuerzeichen (|c, |r, |T, |A, |H, |n), Umbruch,
-- Kuerzen mit "...", Zeilenabstand. Gemessen wird in Pixeln (font.lua); die
-- Zeilen tragen Glyph-Positionen fuer den Zeichner.
local F = require("font")

local T = {}

local ELLIPSIS = "..."
-- Abstand zwischen Text und |T-Symbol bleibt im Client 0; Symbole ohne Breite
-- sind quadratisch in Schrifthoehe.
T.colorByName = function() return nil end   -- wird vom Client gesetzt (|cn...:)
T.atlasSize = function() return nil end      -- Atlas-Groesse fuer |A ohne Angabe

local function hexColor(s)
    local a, r, g, b = tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16), tonumber(s:sub(7, 8), 16)
    if not (a and r and g and b) then return nil end
    return { r / 255, g / 255, b / 255, a / 255 }
end

-- Zerlegt Text in Bausteine: {k="g", cp, color} | {k="tex", ...} | {k="br"}.
function T.Parse(text, baseColor)
    local out, stack = {}, {}
    local color = baseColor
    local i, n = 1, #text
    local function addText(s)
        for _, cp in ipairs(F.Codepoints(s)) do
            out[#out + 1] = { k = "g", cp = cp, color = color }
        end
    end
    while i <= n do
        local bar = text:find("|", i, true)
        if not bar then addText(text:sub(i)) break end
        if bar > i then addText(text:sub(i, bar - 1)) end
        local c = text:sub(bar + 1, bar + 1)
        if c == "|" then
            addText("|")
            i = bar + 2
        elseif c == "c" then
            if text:sub(bar + 2, bar + 2) == "n" then
                local name, stop = text:match("^([%w_]+):()", bar + 3)
                if name then
                    stack[#stack + 1] = color
                    color = T.colorByName(name) or color
                    i = stop
                else
                    i = bar + 2
                end
            else
                local col = hexColor(text:sub(bar + 2, bar + 9))
                if col then
                    stack[#stack + 1] = color
                    color = col
                    i = bar + 10
                else
                    i = bar + 2
                end
            end
        elseif c == "r" then
            color = table.remove(stack) or baseColor
            i = bar + 2
        elseif c == "n" then
            out[#out + 1] = { k = "br" }
            i = bar + 2
        elseif c == "T" or c == "A" then
            local close = c == "T" and "|t" or "|a"
            local stop = text:find(close, bar + 2, true)
            if not stop then i = bar + 2 else
                local spec = text:sub(bar + 2, stop - 1)
                local parts = {}
                for p in (spec .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = p end
                out[#out + 1] = { k = "tex", atlas = c == "A", path = parts[1],
                    h = tonumber(parts[2]), w = tonumber(parts[3]), ox = tonumber(parts[4]) or 0, oy = tonumber(parts[5]) or 0,
                    tw = tonumber(parts[6]), th = tonumber(parts[7]),
                    l = tonumber(parts[8]), r = tonumber(parts[9]), t = tonumber(parts[10]), b = tonumber(parts[11]),
                    vr = tonumber(parts[12]), vg = tonumber(parts[13]), vb = tonumber(parts[14]) }
                i = stop + 2
            end
        elseif c == "H" then
            -- Link: |Hdaten|hText|h -> nur der Text bleibt.
            local stop = text:find("|h", bar + 2, true)
            i = stop and stop + 2 or bar + 2
        elseif c == "h" then
            i = bar + 2
        elseif c == "K" then
            local stop = text:find("|k", bar + 2, true)
            i = stop and stop + 2 or bar + 2
        else
            -- Unbekannte Folge: der Client zeigt sie nicht an.
            i = bar + 2
        end
    end
    return out
end

-- Satz in Pixeln. opts: font (Pfad), px, maxWidth (px oder nil), wordWrap,
-- nonSpaceWrap, maxLines, spacing (px), lineHeight (px), indent.
-- Liefert { lines = { {w, items = {...}} }, width, height }.
function T.Layout(tokens, opts)
    local font, px = opts.font, opts.px
    local lineH = opts.lineHeight
    local function adv(tok, prev)
        if tok.k == "g" then
            return F.Advance(font, px, tok.cp, prev and prev.k == "g" and prev.cp or nil)
        end
        if tok.k == "tex" then
            local h = (tok.h and tok.h > 0) and tok.h * opts.unitPx or lineH
            local w
            if tok.w and tok.w > 0 then w = tok.w * opts.unitPx
            elseif tok.atlas and (not tok.h or tok.h == 0) then
                local aw, ah = T.atlasSize(tok.path)
                if aw then w, h = aw * opts.unitPx, ah * opts.unitPx else w = h end
            else w = h end
            tok.pw, tok.ph = w, h
            return w
        end
        return 0
    end

    -- Erst in "Woerter" teilen (Leerzeichen bleibt am Wortende), dann umbrechen.
    local lines, cur = {}, { items = {}, w = 0 }
    local function newLine()
        lines[#lines + 1] = cur
        cur = { items = {}, w = 0 }
    end
    local word, wordW = {}, 0
    local maxW = opts.maxWidth
    local function place(list)
        local prev = cur.items[#cur.items]
        for _, tok in ipairs(list) do
            local a = adv(tok, prev)
            cur.items[#cur.items + 1] = { tok = tok, x = cur.w, a = a }
            cur.w = cur.w + a
            prev = tok
        end
    end
    local function wordWidth(list, prev)
        local w = 0
        for _, tok in ipairs(list) do w = w + adv(tok, prev) prev = tok end
        return w
    end
    local function flushWord()
        if #word == 0 then return end
        if opts.wordWrap and maxW and #cur.items > 0 then
            -- Leerzeichen am Wortende zaehlt fuer den Umbruch nicht.
            local trimmed = #word
            while trimmed > 0 and word[trimmed].k == "g" and word[trimmed].cp == 32 do trimmed = trimmed - 1 end
            local w = wordWidth({ unpack(word, 1, trimmed) }, cur.items[#cur.items].tok)
            if cur.w + w > maxW + 0.01 then newLine() end
        end
        if opts.wordWrap and maxW and opts.nonSpaceWrap and #cur.items == 0 and wordWidth(word) > maxW then
            for _, tok in ipairs(word) do
                local a = adv(tok)
                if cur.w + a > maxW and #cur.items > 0 then newLine() end
                place({ tok })
            end
        else
            place(word)
        end
        word, wordW = {}, 0
    end
    for _, tok in ipairs(tokens) do
        if tok.k == "br" then
            flushWord()
            newLine()
        else
            word[#word + 1] = tok
            if tok.k == "g" and tok.cp == 32 then flushWord() end
        end
    end
    flushWord()
    lines[#lines + 1] = cur

    -- Zeilenende-Leerzeichen zaehlen nicht zur Breite.
    for _, ln in ipairs(lines) do
        local w = ln.w
        for j = #ln.items, 1, -1 do
            local it = ln.items[j]
            if it.tok.k == "g" and it.tok.cp == 32 then w = it.x else break end
        end
        ln.w = w
    end

    -- Kuerzen: zu viele Zeilen oder zu breit ohne Umbruch.
    local truncated = false
    local limit = opts.maxLines and opts.maxLines > 0 and opts.maxLines or nil
    if opts.maxHeight and lineH > 0 then
        local fit = math.max(1, math.floor((opts.maxHeight + (opts.spacing or 0) + 0.01) / (lineH + (opts.spacing or 0))))
        if not limit or fit < limit then limit = fit end
    end
    if limit and #lines > limit then
        for j = #lines, limit + 1, -1 do lines[j] = nil end
        truncated = true
        lines[#lines].forceEllipsis = true
    end
    if maxW then
        for _, ln in ipairs(lines) do
            if ln.w > maxW + 0.01 or ln.forceEllipsis then
                truncated = true
                local dots = {}
                for _, cp in ipairs(F.Codepoints(ELLIPSIS)) do dots[#dots + 1] = { k = "g", cp = cp, color = ln.items[#ln.items] and ln.items[#ln.items].tok.color } end
                local dotsW = wordWidth(dots)
                while #ln.items > 0 do
                    local last = ln.items[#ln.items]
                    if last.x + last.a + dotsW <= maxW + 0.01 and not (last.tok.k == "g" and last.tok.cp == 32) then break end
                    ln.items[#ln.items] = nil
                end
                local x = 0
                if #ln.items > 0 then x = ln.items[#ln.items].x + ln.items[#ln.items].a end
                for _, d in ipairs(dots) do
                    local a = adv(d)
                    ln.items[#ln.items + 1] = { tok = d, x = x, a = a }
                    x = x + a
                end
                ln.w = x
            end
        end
    end

    local width = 0
    for _, ln in ipairs(lines) do if ln.w > width then width = ln.w end end
    local spacing = opts.spacing or 0
    local height = #lines * lineH + math.max(0, #lines - 1) * spacing
    return { lines = lines, width = width, height = height, truncated = truncated }
end

return T
