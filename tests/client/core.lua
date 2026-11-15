-- Renderer-Tests im echten Client: Anker-Loeser, Ebenenreihenfolge,
-- Textmessung, Atlas-Aufloesung, Pixelrundung, jeweils gegen bekannte Werte.
-- Lauf: tests/run (jede fehlgeschlagene Pruefung ist ein Lua-Fehler im Bericht).
local function near(a, b, tol, what)
    if math.abs(a - b) > (tol or 1e-6) then
        error(string.format("%s: %s statt %s", what, tostring(a), tostring(b)), 2)
    end
end

local checks = {}
local function check(name, fn) checks[#checks + 1] = { name = name, fn = fn } end

-- Bildschirm 3440x1440, uiScale 0.77: Welt 768 hoch, UIParent 768/0.77 Einheiten.
check("Anker: Bildschirm und UIParent", function()
    local L = require("layout")
    near(L.screenH, 768, 0, "Weltrhoehe")
    near(L.screenW, 768 * 3440 / 1440, 1e-9, "Weltbreite")
    near(UIParent:GetHeight(), 768 / 0.77, 1e-6, "UIParent-Hoehe")
    near(UIParent:GetEffectiveScale(), 0.77, 1e-9, "UIParent-Skalierung")
end)

check("Anker: Ecken, Versatz in eigenen Einheiten, Skalierung", function()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(100, 50)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -20)
    near(f:GetLeft(), 10, 1e-9, "links")
    near(f:GetTop(), 768 / 0.77 - 20, 1e-9, "oben")
    local c = CreateFrame("Frame", nil, f)
    c:SetScale(2)
    c:SetSize(10, 10)
    c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 5)
    -- Kind mit Skalierung 2: eigene Einheiten sind halb so viele Elternenheiten.
    near(c:GetRight() * 2, f:GetRight() - 10, 1e-9, "rechts skaliert")
    near(c:GetBottom() * 2, f:GetBottom() + 10, 1e-9, "unten skaliert")
end)

check("Anker: zwei Punkte spannen die Breite, CENTER", function()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetPoint("LEFT", UIParent, "LEFT", 100, 0)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -100, 0)
    f:SetHeight(10)
    near(f:GetWidth(), UIParent:GetWidth() - 200, 1e-9, "Breite aus zwei Ankern")
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetSize(40, 40)
    g:SetPoint("CENTER")
    local cx, cy = g:GetCenter()
    near(cx, UIParent:GetWidth() / 2, 1e-9, "Mitte x")
    near(cy, UIParent:GetHeight() / 2, 1e-9, "Mitte y")
end)

check("Anker: Schleife ergibt kein Rechteck", function()
    local a = CreateFrame("Frame", nil, UIParent)
    local b = CreateFrame("Frame", nil, UIParent)
    a:SetSize(10, 10) b:SetSize(10, 10)
    a:SetPoint("LEFT", b, "RIGHT")
    b:SetPoint("LEFT", a, "RIGHT")
    assert(a:GetLeft() == nil, "Ankerschleife muss nil liefern")
end)

check("Pixelrundung: Kanten auf das Pixelraster", function()
    local L = require("layout")
    -- 1440/768 = 1.875 px je Welteinheit.
    local x, y, w, h = L.PixelRect({ 10.3, 768 - 20, 100.1, 20 })
    near(x, 19, 0, "x") -- 10.3*1.875 = 19.31
    near(w, 188, 0, "w") -- (110.4*1.875 = 207) - 19
    near(y, 0, 0, "y")
    near(h, 38, 0, "h") -- 37.5 -> 38 (round half up)
end)

check("Ebenen: Strata vor Level vor Ebene vor Unterebene", function()
    local Draw = require("draw")
    local function tex(parent, layer, sub, r)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetAllPoints()
        t:SetColorTexture(r, 0, 0, 1)
        return t
    end
    local low = CreateFrame("Frame", "FRTestLow", UIParent)
    low:SetFrameStrata("HIGH") low:SetFrameLevel(50) low:SetSize(5, 5) low:SetPoint("CENTER")
    local high = CreateFrame("Frame", "FRTestHigh", UIParent)
    high:SetFrameStrata("DIALOG") high:SetFrameLevel(1) high:SetSize(5, 5) high:SetPoint("CENTER")
    tex(high, "BACKGROUND", 0, 0.5)
    tex(low, "OVERLAY", 7, 0.1)
    tex(low, "ARTWORK", 2, 0.3)
    tex(low, "ARTWORK", -3, 0.2)
    local order = {}
    for _, it in ipairs(Draw.Collect()) do
        if it.k == "tex" and it.color and it.color[2] == 0 and it.color[3] == 0 and it.color[1] < 0.6 then
            order[#order + 1] = it.color[1]
        end
    end
    near(#order, 4, 0, "Anzahl")
    near(order[1], 0.2, 1e-9, "1.") near(order[2], 0.3, 1e-9, "2.")
    near(order[3], 0.1, 1e-9, "3.") near(order[4], 0.5, 1e-9, "4.")
    low:Hide() high:Hide()
end)

check("Text: FreeType-Breite wie freetype-py", function()
    local f = CreateFrame("Frame", nil, UIParent)
    local fs = f:CreateFontString(nil, "OVERLAY")
    -- 12 Einheiten * 0.77 * 1.875 = 17.325 -> 17 px; "Hello AV To" = 95 px (freetype-py, FRIZQT__, Kerning an).
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    fs:SetText("Hello AV To")
    near(fs:GetStringWidth() * 0.77 * 1.875, 95, 1e-6, "Breite in px")
end)

check("Text: Umbruch bei fester Breite", function()
    local f = CreateFrame("Frame", nil, UIParent)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    fs:SetWidth(60)
    fs:SetText("eins zwei drei vier fuenf")
    assert(fs:GetNumLines() >= 2, "muss umbrechen, Zeilen: " .. tostring(fs:GetNumLines()))
    assert(fs:GetStringHeight() > 12, "Hoehe waechst mit den Zeilen")
end)

check("Atlas: logische Groesse und Texturkoordinaten", function()
    local f = CreateFrame("Frame", nil, UIParent)
    local t = f:CreateTexture()
    t:SetAtlas("UI-QuestPoi-QuestNumber", true)
    near(t:GetWidth(), 32, 1e-9, "Breite (@2x halbiert)")
    near(t:GetHeight(), 32, 1e-9, "Hoehe")
    local ulx, uly = t:GetTexCoord()
    near(ulx, 0.255859375, 1e-6, "links")
    near(uly, 0.26171875, 1e-6, "oben")
    local info = C_Texture.GetAtlasInfo("ui-hud-unitframe-player-portraiton")
    near(info.width, 198, 0, "Portraet-Breite")
    near(info.height, 71, 0, "Portraet-Hoehe")
end)

check("Statusbar: Fuellung als Rechteck der Textur", function()
    local b = CreateFrame("StatusBar", nil, UIParent)
    b:SetSize(200, 10)
    b:SetPoint("CENTER")
    b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    b:SetMinMaxValues(0, 100)
    b:SetValue(25)
    near(b:GetStatusBarTexture():GetWidth(), 50, 1e-9, "Fuellbreite")
    b:SetValue(80)
    near(b:GetStatusBarTexture():GetWidth(), 160, 1e-9, "nach SetValue")
end)

-- Jede Pruefung ein eigener Schritt, damit ein Fehler die anderen nicht verdeckt.
local steps = {}
for _, c in ipairs(checks) do
    steps[#steps + 1] = { run = function()
        local ok, err = pcall(c.fn)
        if not ok then error("PRUEFUNG " .. c.name .. ": " .. tostring(err), 0) end
        io.stderr:write("ok  " .. c.name .. "\n")
    end }
end

return { addons = {}, uiScale = 0.77, screen = { 3440, 1440 }, steps = steps }
