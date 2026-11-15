-- Schriftmetrik ueber FreeType (LuaJIT-FFI). Gemessen wird in physischen
-- Pixeln bei der Groesse, in der der Client die Schrift rastert; zurueck
-- gehen UI-Einheiten. Der Python-Zeichner rastert dieselben Glyphen mit
-- derselben Bibliothek an den Positionen, die hier entstehen.
local ffi = require("ffi")

ffi.cdef [[
typedef int FT_Error;
typedef long FT_Long;
typedef unsigned long FT_ULong;
typedef unsigned int FT_UInt;
typedef int FT_Int;
typedef int FT_Int32;
typedef long FT_Pos;
typedef long FT_Fixed;
typedef short FT_Short;
typedef unsigned short FT_UShort;
typedef void* FT_Library;
typedef struct { FT_Pos x, y; } FT_Vector;
typedef struct { FT_Pos xMin, yMin, xMax, yMax; } FT_BBox;
typedef struct { FT_Pos width, height, horiBearingX, horiBearingY, horiAdvance, vertBearingX, vertBearingY, vertAdvance; } FT_Glyph_Metrics;
typedef struct { void* data; void* finalizer; } FT_Generic;
typedef struct { FT_UShort x_ppem, y_ppem; FT_Fixed x_scale, y_scale; FT_Pos ascender, descender, height, max_advance; } FT_Size_Metrics;
typedef struct FT_SizeRec_ { void* face; FT_Generic generic; FT_Size_Metrics metrics; void* internal; } FT_SizeRec;
typedef struct FT_GlyphSlotRec_ {
  FT_Library library; void* face; void* next; FT_UInt glyph_index; FT_Generic generic;
  FT_Glyph_Metrics metrics; FT_Fixed linearHoriAdvance, linearVertAdvance; FT_Vector advance;
} FT_GlyphSlotRec;
typedef struct FT_FaceRec_ {
  FT_Long num_faces, face_index, face_flags, style_flags, num_glyphs;
  char* family_name; char* style_name;
  FT_Int num_fixed_sizes; void* available_sizes;
  FT_Int num_charmaps; void* charmaps;
  FT_Generic generic; FT_BBox bbox;
  FT_UShort units_per_EM; FT_Short ascender, descender, height;
  FT_Short max_advance_width, max_advance_height, underline_position, underline_thickness;
  FT_GlyphSlotRec* glyph; FT_SizeRec* size; void* charmap;
} FT_FaceRec;
typedef FT_FaceRec* FT_Face;
FT_Error FT_Init_FreeType(FT_Library* lib);
FT_Error FT_New_Face(FT_Library lib, const char* path, FT_Long index, FT_Face* face);
FT_Error FT_Set_Pixel_Sizes(FT_Face face, FT_UInt w, FT_UInt h);
FT_Error FT_Set_Char_Size(FT_Face face, FT_Long w, FT_Long h, FT_UInt hres, FT_UInt vres);
FT_UInt FT_Get_Char_Index(FT_Face face, FT_ULong code);
FT_Error FT_Load_Glyph(FT_Face face, FT_UInt index, FT_Int32 flags);
FT_Error FT_Get_Kerning(FT_Face face, FT_UInt left, FT_UInt right, FT_UInt mode, FT_Vector* out);
]]

local ft = ffi.load("freetype")
local F = {}

-- FT_LOAD_DEFAULT: Hinting wie bei einer gewoehnlichen Bitmap-Rasterung.
local FT_LOAD_DEFAULT = 0
local FT_KERNING_DEFAULT = 0
local FIXED_26_6 = 64
-- Der Client wendet Unterschneidung an (sichtbar bei "AV"/"To" in Friz).
F.KERNING = true

local lib
local faces = {}    -- Pfad -> FT_Face (oder false)
local metrics = {}  -- Pfad.."@"..px -> Tabelle

local function library()
    if not lib then
        local p = ffi.new("FT_Library[1]")
        assert(ft.FT_Init_FreeType(p) == 0, "FreeType laesst sich nicht starten")
        lib = p[0]
    end
    return lib
end

function F.Face(path)
    local f = faces[path]
    if f == nil then
        local p = ffi.new("FT_Face[1]")
        if ft.FT_New_Face(library(), path, 0, p) == 0 then
            f = p[0]
        else
            f = false
        end
        faces[path] = f
    end
    return f or nil
end

-- Pixelgroesse ganzzahlig wie beim Rastern im Client (Glyphen-Cache je Groesse).
function F.PixelSize(uiHeight, pixelScale)
    local px = math.floor(uiHeight * pixelScale + 0.5)
    if px < 1 then px = 1 end
    return px
end

-- Metrik je Schrift und Pixelgroesse: Vorschub je Zeichen, Ober-/Unterlaenge.
local function sized(path, px)
    local key = path .. "@" .. px
    local m = metrics[key]
    if m then return m end
    local face = F.Face(path)
    if not face then return nil end
    ft.FT_Set_Pixel_Sizes(face, 0, px)
    local sm = face.size.metrics
    m = { face = face, px = px, adv = {}, idx = {},
          ascender = tonumber(sm.ascender) / FIXED_26_6, descender = tonumber(sm.descender) / FIXED_26_6 }
    metrics[key] = m
    return m
end

local kern = ffi.new("FT_Vector[1]")

-- Vorschub (px) des Zeichens cp, optional mit Unterschneidung zum Vorgaenger.
function F.Advance(path, px, cp, prevCp)
    local m = sized(path, px)
    if not m then return px * 0.5 end
    local face = m.face
    local gi = m.idx[cp]
    if gi == nil then
        gi = ft.FT_Get_Char_Index(face, cp)
        m.idx[cp] = gi
    end
    local a = m.adv[cp]
    if a == nil then
        ft.FT_Set_Pixel_Sizes(face, 0, px)
        if gi ~= 0 and ft.FT_Load_Glyph(face, gi, FT_LOAD_DEFAULT) == 0 then
            a = tonumber(face.glyph.advance.x) / FIXED_26_6
        else
            a = 0
        end
        m.adv[cp] = a
    end
    if F.KERNING and prevCp then
        local pgi = m.idx[prevCp]
        if pgi and pgi ~= 0 and gi ~= 0 then
            ft.FT_Set_Pixel_Sizes(face, 0, px)
            if ft.FT_Get_Kerning(face, pgi, gi, FT_KERNING_DEFAULT, kern) == 0 then
                a = a + tonumber(kern[0].x) / FIXED_26_6
            end
        end
    end
    return a
end

function F.HasGlyph(path, px, cp)
    local m = sized(path, px)
    if not m then return false end
    local gi = m.idx[cp]
    if gi == nil then
        gi = ft.FT_Get_Char_Index(m.face, cp)
        m.idx[cp] = gi
    end
    return gi ~= 0
end

function F.Metrics(path, px)
    local m = sized(path, px)
    if not m then return nil end
    return m.ascender, m.descender
end

-- UTF-8 in Codepoints zerlegen (Lua 5.1 kennt kein utf8).
function F.Codepoints(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = s:byte(i)
        local cp, len
        if c < 0x80 then cp, len = c, 1
        elseif c < 0xE0 then cp, len = c % 0x20, 2
        elseif c < 0xF0 then cp, len = c % 0x10, 3
        else cp, len = c % 0x08, 4 end
        for j = 1, len - 1 do
            local b = s:byte(i + j) or 0x80
            cp = cp * 64 + b % 64
        end
        out[#out + 1] = cp
        i = i + len
    end
    return out
end

return F
