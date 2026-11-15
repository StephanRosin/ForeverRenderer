#!/usr/bin/env python3
"""Tests fuer tools/extract-art: WDC5-Parser, Atlas-Koordinaten, BLP-Format.

    python3 -I tests/test_extract_art.py

Werte stammen aus WoW Forever 1.60.1.70938 (UiTextureAtlas*, UiCanvas, Item, ItemSparse, SpellName,
SpellMisc; gegen wago.tools geprueft).
"""
import importlib.machinery
import importlib.util
import json
import os
import struct

PFAD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools", "extract-art")
_loader = importlib.machinery.SourceFileLoader("extract_art", PFAD)
_spec = importlib.util.spec_from_loader("extract_art", _loader)
ea = importlib.util.module_from_spec(_spec)
_loader.exec_module(ea)

ELEMENT_LAYOUT = 0x7CCBD18F


def wdc5_element(saetze):
    """Kleine UiTextureAtlasElement.db2 im echten Aufbau: Felder Name (String-Offset), ID; 8 Byte je Satz."""
    satzgroesse, feldzahl = 8, 2
    strings, offsets = b"", []
    for name, _ in saetze:
        offsets.append(len(strings))
        strings += name.encode() + b"\0"
    kopf = b"WDC5" + struct.pack("<I", 5) + b"\0" * 128
    kopf += ea.WDC5_HEADER.pack(len(saetze), feldzahl, satzgroesse, len(strings), 0, ELEMENT_LAYOUT,
                                0, 0, 0xFFFFFFFF, 0, 1, feldzahl, 0, 0, feldzahl * 24, 0, 0, 1)
    sektion_pos = len(kopf)
    felder = struct.pack("<hHhH", 0, 0, 0, 4)
    speicher = ea.WDC5_FIELD_STORAGE.pack(0, 32, 0, 0, 0, 0, 0) + ea.WDC5_FIELD_STORAGE.pack(32, 32, 0, 0, 0, 0, 0)
    satz_start = sektion_pos + ea.WDC5_SECTION.size + len(felder) + len(speicher)
    saetze_bytes = b""
    for i, (_, id_) in enumerate(saetze):
        # Offset relativ zur Feldposition: vom Satzanfang bis zum Tabellenende plus Stelle in der Tabelle
        rest = (len(saetze) - i) * satzgroesse
        saetze_bytes += struct.pack("<II", rest + offsets[i] if saetze[i][0] else 0, id_)
    sektion = ea.WDC5_SECTION.pack(0, satz_start, len(saetze), len(strings), 0, 0, 0, 0, 1)
    kopie = struct.pack("<2I", 99999, saetze[0][1])  # Kopiertabelle: neue ID 99999 = Kopie des ersten Satzes
    return kopf + sektion + felder + speicher + saetze_bytes + strings + kopie


def test_wdc5():
    zeilen, verschluesselt = ea.wdc5_lesen(wdc5_element([("BackArrow-Brown", 3517), ("UI-HUD-UnitFrame-Player-PortraitOn", 19918),
                                         ("", 14323)]))
    assert verschluesselt == 0
    assert zeilen[0] == {"Name": "BackArrow-Brown", "ID": 3517}, zeilen
    assert zeilen[1] == {"Name": "UI-HUD-UnitFrame-Player-PortraitOn", "ID": 19918}, zeilen
    assert zeilen[2] == {"Name": "", "ID": 14323}, zeilen  # Offset 0 = leerer String
    assert zeilen[3] == {"Name": "BackArrow-Brown", "ID": 99999}, zeilen


def test_wdc5_fremdes_layout():
    daten = bytearray(wdc5_element([("x", 1)]))
    struct.pack_into("<I", daten, ea.WDC5_HEADER_OFFSET + 20, 0x12345678)
    try:
        ea.wdc5_lesen(bytes(daten))
    except ValueError as f:
        assert "12345678" in str(f)
    else:
        raise AssertionError("unbekanntes Layout muss scheitern")


GLOBALSTRINGS_LAYOUT = 0xD40F6D96


def wdc5_globalstrings(saetze):
    """GlobalStrings.db2 im echten Aufbau: ID-Liste, Flags als 3-Bit-Pallet-Index, zweite Sektion
    mit fehlendem TACT-Schluessel (1 Satz, nur Nullen) wie in 1.60.1.70938."""
    satzgroesse, feldzahl, pallet = 12, 3, [1, 2, 3]
    strings, offsets = b"", []
    for tag, text, _, _ in saetze:
        offsets.append((len(strings), len(strings) + len(tag) + 1))
        strings += tag.encode() + b"\0" + text.encode() + b"\0"
    gesamt = len(saetze) + 1  # Header zaehlt den verschluesselten Satz mit
    kopf = b"WDC5" + struct.pack("<I", 5) + b"\0" * 128
    kopf += ea.WDC5_HEADER.pack(gesamt, feldzahl, satzgroesse, len(strings), 0, GLOBALSTRINGS_LAYOUT,
                                0, 0, 1, ea.WDC5_FLAG_ID_LIST, 0, feldzahl, 0, 0, feldzahl * 24, 0, 4 * len(pallet), 2)
    felder = struct.pack("<hHhHhH", 0, 0, 0, 4, 0, 8)
    speicher = (ea.WDC5_FIELD_STORAGE.pack(0, 32, 0, 0, 0, 0, 0) + ea.WDC5_FIELD_STORAGE.pack(32, 32, 0, 0, 0, 0, 0)
                + ea.WDC5_FIELD_STORAGE.pack(64, 3, 4 * len(pallet), ea.WDC_KOMPRESSION_PALLET, 0, 3, 0))
    pallet_bytes = struct.pack("<3I", *pallet)
    satz_start = len(kopf) + 2 * ea.WDC5_SECTION.size + len(felder) + len(speicher) + len(pallet_bytes)
    saetze_bytes, n = b"", len(saetze)
    for i, (_, _, flags, _) in enumerate(saetze):
        # String-Offsets relativ zur Feldstelle, gerechnet gegen die Satzzahl ALLER Sektionen
        basis = (gesamt - i) * satzgroesse
        bits = (basis + offsets[i][0]) | (basis - 4 + offsets[i][1]) << 32 | pallet.index(flags) << 64
        saetze_bytes += bits.to_bytes(satzgroesse, "little")
    ids = b"".join(struct.pack("<I", id_) for *_, id_ in saetze)
    zweite_start = satz_start + len(saetze_bytes) + len(strings) + len(ids)
    sektionen = (ea.WDC5_SECTION.pack(0, satz_start, n, len(strings), 0, len(ids), 0, 0, 0)
                 + ea.WDC5_SECTION.pack(0x57AF1A, zweite_start, 1, 0, 0, 4, 0, 0, 0))
    return kopf + sektionen + felder + speicher + pallet_bytes + saetze_bytes + strings + ids + bytes(satzgroesse + 4)


def test_wdc5_id_liste_pallet_verschluesselt():
    zeilen, verschluesselt = ea.wdc5_lesen(wdc5_globalstrings([("PRESS_TAB", "Press Tab", 1, 9597),
                                                               ("EVERY_X_PERCENT", "Every %d%%", 3, 44346)]))
    assert verschluesselt == 1
    assert zeilen == [{"BaseTag": "PRESS_TAB", "TagText_lang": "Press Tab", "Flags": 1, "ID": 9597},
                      {"BaseTag": "EVERY_X_PERCENT", "TagText_lang": "Every %d%%", "Flags": 3, "ID": 44346}], zeilen


def test_farbe():
    # NORMAL_FONT_COLOR steht als 4294955520 (wago: -11776) im DB2
    assert ea.farbe(4294955520) == {"r": 1.0, "g": 210 / 255, "b": 0.0, "a": 1.0}
    assert ea.farbe(0xFFFF2020)["g"] == 32 / 255  # RED_FONT_COLOR


def member(name, l, r, t, b, flags=0, ow=0, oh=0, atlas=2060, element=1, id_=1, canvas=0):
    return {"CommittedName": name, "ID": id_, "UiTextureAtlasID": atlas, "CommittedLeft": l, "CommittedRight": r,
            "CommittedTop": t, "CommittedBottom": b, "CommittedFlags": flags, "OverrideWidth": ow,
            "OverrideHeight": oh, "UiTextureAtlasElementID": element, "Width": r - l, "Height": b - t,
            "UiCanvasID": canvas}


ATLAS_2060 = {"ID": 2060, "FileDataID": 4631591, "AtlasWidth": 1024, "AtlasHeight": 512, "UiCanvasID": 1}
LEINWAND = {1: {"ID": 1, "Width": 1024, "Height": 768}, 2: {"ID": 2, "Width": 2048, "Height": 1536}}


def test_atlas_koordinaten():
    e = ea.atlas_eintrag(member("ui-hud-unitframe-player-portraiton", 1, 199, 87, 158), ATLAS_2060, "x.png", LEINWAND)
    assert (e["width"], e["height"]) == (198, 71), e
    assert (e["left"], e["right"], e["top"], e["bottom"]) == (1 / 1024, 199 / 1024, 87 / 512, 158 / 512), e
    assert not e["tilesH"] and not e["tilesV"]


def test_atlas_override_und_kacheln():
    # vignetteloot: Pixel 32x32, Override 24x24; Flag 8 ist kein Kachel-Bit
    e = ea.atlas_eintrag(member("vignetteloot", 583, 615, 752, 784, flags=8, ow=24, oh=24), ATLAS_2060, "x.png", LEINWAND)
    assert (e["width"], e["height"]) == (24, 24) and not e["tilesH"] and not e["tilesV"]
    # _BattleBar-Mid kachelt waagrecht (4), !Garr_InfoBox-Left senkrecht (2), Garr_InfoBox-BackgroundTile beides (6)
    assert ea.atlas_eintrag(member("_battlebar-mid", 0, 256, 0, 124, flags=4), ATLAS_2060, "x", LEINWAND)["tilesH"]
    links = ea.atlas_eintrag(member("!garr_infobox-left", 1, 136, 0, 256, flags=2), ATLAS_2060, "x", LEINWAND)
    assert links["tilesV"] and not links["tilesH"]
    beides = ea.atlas_eintrag(member("t", 0, 256, 0, 256, flags=6), ATLAS_2060, "x", LEINWAND)
    assert beides["tilesH"] and beides["tilesV"]
    nie = ea.atlas_eintrag(member("t", 0, 256, 0, 256, flags=0x16), ATLAS_2060, "x", LEINWAND)
    assert not nie["tilesH"] and not nie["tilesV"]


def test_atlas_doppelte_namen():
    # transmog-icon-hidden gibt es in zwei Atlanten; die hoehere ID gewinnt, ausser ihre Textur fehlt
    atlanten = {610: dict(ATLAS_2060, ID=610, FileDataID=1116940), 3543: dict(ATLAS_2060, ID=3543, FileDataID=7344437)}
    members = [member("transmog-icon-hidden", 276, 312, 154, 184, atlas=610, element=5493, id_=5647),
               member("transmog-icon-hidden", 988, 1017, 576, 600, atlas=3543, element=5493, id_=33891)]
    elemente = {5493: "Transmog-Icon-Hidden"}
    beide = {1116940: "a.png", 7344437: "b.png"}
    ergebnis, probleme = ea.atlas_json(atlanten, elemente, members, beide, LEINWAND)
    assert ergebnis["transmog-icon-hidden"]["file"] == "b.png" and probleme["doppelt"] == 1
    ergebnis, _ = ea.atlas_json(atlanten, elemente, members, {1116940: "a.png"}, LEINWAND)
    assert ergebnis["transmog-icon-hidden"]["file"] == "a.png"


def test_atlas_committed_name_als_zusatzname():
    # Element "_Horde-NineSlice-EdgeTop" hat den Member "_UI-Frame-Horde-TileTop": beide Namen muessen gehen
    members = [member("_UI-Frame-Horde-TileTop", 0, 256, 0, 64, flags=4, element=7)]
    ergebnis, probleme = ea.atlas_json({2060: ATLAS_2060}, {7: "_Horde-NineSlice-EdgeTop"}, members, {4631591: "h.png"}, LEINWAND)
    assert set(ergebnis) == {"_horde-nineslice-edgetop", "_ui-frame-horde-tiletop"} and probleme["aliase"] == 1


def test_atlas_leinwand_2x():
    # ui-questpoi-questnumber: das @2x-Member (Atlas 2550, Leinwand 2) hat 64 Pixel, logisch 32 wie das 1x-Member
    atlas_2550 = {"ID": 2550, "FileDataID": 5320937, "AtlasWidth": 512, "AtlasHeight": 256, "UiCanvasID": 2}
    e = ea.atlas_eintrag(member("ui-questpoi-questnumber-2x", 131, 195, 67, 131), atlas_2550, "x", LEINWAND)
    assert (e["width"], e["height"], e["pxWidth"], e["pxHeight"]) == (32, 32, 64, 64), e
    # StoryHeader-BG: Leinwand 2 steht am Member, der Atlas ist 1x; im XML 304x69
    atlas_910 = dict(ATLAS_2060, FileDataID=904010, UiCanvasID=1)
    e = ea.atlas_eintrag(member("storyheader-bg", 0, 608, 0, 138, canvas=2), atlas_910, "x", LEINWAND)
    assert (e["width"], e["height"], e["pxWidth"]) == (304, 69, 608), e
    # ui-hud-actionbar-gryphon-left @2x: Override 200x200 ist in Leinwand-Pixeln, logisch 100 wie das 1x-Member
    e = ea.atlas_eintrag(member("g", 0, 356, 0, 356, ow=200, oh=200), atlas_2550, "x", LEINWAND)
    assert (e["width"], e["height"], e["pxWidth"]) == (100, 100, 356), e
    # Leinwand 0 am Atlas zaehlt als 1x
    assert ea.atlas_eintrag(member("t", 0, 75, 0, 75), dict(ATLAS_2060, UiCanvasID=0), "x", LEINWAND)["width"] == 75


SPARSE_LAYOUT = 0x5BA25E01  # Test-Layout: Ausschnitt aus ItemSparse


def wdc5_sparse(saetze, kopie):
    """Sparse-Tabelle (Offset-Map) im Aufbau von ItemSparse.db2 1.60.1: Strings stehen im Satz,
    Saetze auf 4 Byte aufgefuellt, hinter den Saetzen ID-Liste, Kopiertabelle, Offset-Map, Offset-ID-Liste."""
    feldzahl = 3
    kopf = b"WDC5" + struct.pack("<I", 5) + b"\0" * 128
    kopf += ea.WDC5_HEADER.pack(len(saetze), feldzahl, 9, 0, 0, SPARSE_LAYOUT, 0, 0, 1,
                                ea.WDC5_FLAG_SPARSE | ea.WDC5_FLAG_ID_LIST, 0, feldzahl, 0, 0, feldzahl * 24, 0, 0, 1)
    felder = struct.pack("<hHhHhH", 0, 0, 0, 4, 24, 8)
    speicher = (ea.WDC5_FIELD_STORAGE.pack(0, 32, 0, 0, 0, 0, 0) + ea.WDC5_FIELD_STORAGE.pack(32, 32, 0, 0, 0, 0, 0)
                + ea.WDC5_FIELD_STORAGE.pack(64, 8, 0, 0, 0, 0, 0))
    satz_start = len(kopf) + ea.WDC5_SECTION.size + len(felder) + len(speicher)
    saetze_bytes, offsets = b"", b""
    for name, stapel, qualitaet, _ in saetze:
        satz = name.encode() + b"\0" + struct.pack("<ib", stapel, qualitaet)
        satz += bytes(-len(satz) % 4)
        offsets += ea.WDC5_OFFSET_MAP_EINTRAG.pack(satz_start + len(saetze_bytes), len(satz))
        saetze_bytes += satz
    ids = b"".join(struct.pack("<I", id_) for *_, id_ in saetze)
    sektion = ea.WDC5_SECTION.pack(0, satz_start, len(saetze), 0, satz_start + len(saetze_bytes), len(ids), 0,
                                   len(saetze), 1)
    return kopf + sektion + felder + speicher + saetze_bytes + ids + struct.pack("<2I", *kopie) + offsets + ids


def test_wdc5_sparse():
    ea.DB2_LAYOUTS[SPARSE_LAYOUT] = [("Display_lang", "s"), ("Stackable", "i"), ("OverallQualityID", "i")]
    try:
        daten = wdc5_sparse([("Hearthstone", 1, 1, 6948), ("Linen Cloth", 20, 1, 2589), ("X", -1, -1, 7)], (99999, 2589))
        zeilen, verschluesselt = ea.wdc5_lesen(daten)
        assert verschluesselt == 0
        assert zeilen == [{"Display_lang": "Hearthstone", "Stackable": 1, "OverallQualityID": 1, "ID": 6948},
                          {"Display_lang": "Linen Cloth", "Stackable": 20, "OverallQualityID": 1, "ID": 2589},
                          {"Display_lang": "X", "Stackable": -1, "OverallQualityID": -1, "ID": 7},
                          {"Display_lang": "Linen Cloth", "Stackable": 20, "OverallQualityID": 1, "ID": 99999}], zeilen
        # Satzgroesse in der Offset-Map passt nicht zum Layout: klarer Fehler statt geratener Werte
        kaputt = bytearray(daten)
        offset_map = len(daten) - 3 * 4 - 3 * ea.WDC5_OFFSET_MAP_EINTRAG.size  # vor der Offset-ID-Liste
        struct.pack_into("<H", kaputt, offset_map + 4, 24)  # Hearthstone-Satz ist 20 Byte
        try:
            ea.wdc5_lesen(bytes(kaputt))
        except ValueError as f:
            assert "Sparse-Satz" in str(f), f
        else:
            raise AssertionError("falsche Satzgroesse muss scheitern")
    finally:
        del ea.DB2_LAYOUTS[SPARSE_LAYOUT]


RELATION_LAYOUT = 0x5BA25E02  # Test-Layout: Ausschnitt aus SpellMisc


def test_wdc5_relationship_map():
    """SpellMisc-artig: SpellID steht nicht im Satz, sondern in der Relationship-Map (Satzindex -> SpellID).
    DifficultyID ist vorzeichenlos gepackt (4 Bit): 8 bleibt 8."""
    ea.DB2_LAYOUTS[RELATION_LAYOUT] = [("DifficultyID", "i"), ("SpellIconFileDataID", "i"), ("SpellID", "r")]
    try:
        feldzahl, satzgroesse = 2, 8
        kopf = b"WDC5" + struct.pack("<I", 5) + b"\0" * 128
        kopf += ea.WDC5_HEADER.pack(2, feldzahl, satzgroesse, 0, 0, RELATION_LAYOUT, 0, 0, 0xFFFFFFFF,
                                    ea.WDC5_FLAG_ID_LIST, 0, feldzahl, 0, 1, feldzahl * 24, 0, 0, 1)
        felder = struct.pack("<hHhH", 0, 0, 0, 4)
        speicher = (ea.WDC5_FIELD_STORAGE.pack(0, 4, 0, ea.WDC_KOMPRESSION_BITPACKED, 0, 4, 0)
                    + ea.WDC5_FIELD_STORAGE.pack(32, 32, 0, 0, 0, 0, 0))
        satz_start = len(kopf) + ea.WDC5_SECTION.size + len(felder) + len(speicher)
        saetze = struct.pack("<II", 0, 136085) + struct.pack("<II", 8, 136085)
        ids = struct.pack("<2I", 321073, 400000)
        relation = struct.pack("<3I", 2, 8936, 8937) + struct.pack("<4I", 8937, 1, 8936, 0)
        sektion = ea.WDC5_SECTION.pack(0, satz_start, 2, 0, 0, len(ids), len(relation), 0, 0)
        zeilen, _ = ea.wdc5_lesen(kopf + sektion + felder + speicher + saetze + ids + relation)
        assert zeilen == [{"DifficultyID": 0, "SpellIconFileDataID": 136085, "ID": 321073, "SpellID": 8936},
                          {"DifficultyID": 8, "SpellIconFileDataID": 136085, "ID": 400000, "SpellID": 8937}], zeilen
    finally:
        del ea.DB2_LAYOUTS[RELATION_LAYOUT]


def test_items_json():
    item = [{"ID": 6948, "IconFileDataID": 134414, "ClassID": 15, "SubclassID": 0},
            {"ID": 2589, "IconFileDataID": 132889, "ClassID": 7, "SubclassID": 5},
            {"ID": 1, "IconFileDataID": 5, "ClassID": 0, "SubclassID": 0}]
    sparse = [{"ID": 6948, "Display_lang": "Hearthstone", "OverallQualityID": 1},
              {"ID": 2589, "Display_lang": "Linen Cloth", "OverallQualityID": 1},
              {"ID": 3, "Display_lang": "Nur Sparse", "OverallQualityID": 2}]
    items = ea.items_json(item, sparse)
    assert list(items) == ["1", "3", "2589", "6948"]
    assert items["6948"] == {"name": "Hearthstone", "icon": 134414, "quality": 1, "classID": 15, "subclassID": 0}
    assert items["2589"] == {"name": "Linen Cloth", "icon": 132889, "quality": 1, "classID": 7, "subclassID": 5}
    assert items["1"]["name"] is None and items["3"]["icon"] is None


def test_spells_json():
    namen = [{"ID": 8936, "Name_lang": "Regrowth"}, {"ID": 5, "Name_lang": "Ohne Misc"}]
    misc = [{"ID": 400000, "SpellID": 8936, "DifficultyID": 0, "SpellIconFileDataID": 999},
            {"ID": 321073, "SpellID": 8936, "DifficultyID": 0, "SpellIconFileDataID": 136085},
            {"ID": 100, "SpellID": 8936, "DifficultyID": 2, "SpellIconFileDataID": 1},
            {"ID": 101, "SpellID": 7, "DifficultyID": 3, "SpellIconFileDataID": 2},
            {"ID": 102, "SpellID": 7, "DifficultyID": 1, "SpellIconFileDataID": 3}]
    spells = ea.spells_json(namen, misc)
    assert spells["8936"] == {"name": "Regrowth", "icon": 136085}
    assert spells["5"] == {"name": "Ohne Misc", "icon": None} and spells["7"] == {"name": None, "icon": 2}


def test_archiv_stichproben():
    """Fertiges Archiv 1.60.1.70938 gegen wago.tools; fehlt es, wird nichts geprueft."""
    ordner = os.path.join(ea.ART, "1.60.1.70938")
    pfade = [os.path.join(ordner, n) for n in ("items.json", "spells.json", "atlas.json")]
    if not all(os.path.exists(p) for p in pfade):
        print("  (Archiv fehlt, Stichproben uebersprungen)")
        return
    items, spells, atlas = (json.load(open(p, encoding="utf-8")) for p in pfade)
    assert items["6948"] == {"name": "Hearthstone", "icon": 134414, "quality": 1, "classID": 15, "subclassID": 0}
    assert items["2589"] == {"name": "Linen Cloth", "icon": 132889, "quality": 1, "classID": 7, "subclassID": 5}
    assert spells["8936"] == {"name": "Regrowth", "icon": 136085}
    q = atlas["ui-questpoi-questnumber"]
    assert (q["width"], q["height"]) == (32, 32), q
    p = atlas["ui-hud-unitframe-player-portraiton"]
    assert (p["width"], p["height"], p["pxWidth"]) == (198, 71, 198), p
    s = atlas["storyheader-bg"]
    assert (s["width"], s["height"]) == (304, 69), s


def test_blp_format():
    def kopf(kodierung, alpha_tiefe, alpha_typ):
        return b"BLP2" + struct.pack("<I4B2I", 1, kodierung, alpha_tiefe, alpha_typ, 1, 4, 4)
    assert ea.blp_format(kopf(2, 8, 7)) == "BLP2/DXT5"
    assert ea.blp_format(kopf(2, 0, 0)) == "BLP2/DXT1"
    assert ea.blp_format(kopf(1, 8, 0)) == "BLP2/PAL"
    assert ea.blp_format(kopf(3, 8, 0)) == "BLP2/BGRA"
    assert ea.png_pfad("Interface\\Buttons\\WHITE8X8.BLP") == "interface/buttons/white8x8.png"


def test_blp2_roh():
    breite, hoehe = 2, 1
    daten = bytearray(b"BLP2" + struct.pack("<I4B2I", 1, 3, 8, 0, 0, breite, hoehe) + b"\0" * (16 * 4 * 2))
    struct.pack_into("<I", daten, ea.BLP2_MIP0_OFFSET, len(daten))
    daten += bytes([10, 20, 30, 40, 1, 2, 3, 4])  # BGRA
    bild = ea.blp2_roh(bytes(daten))
    assert bild.mode == "RGBA" and list(bild.get_flattened_data()) == [(30, 20, 10, 40), (3, 2, 1, 4)]


if __name__ == "__main__":
    for name, test in list(globals().items()):
        if name.startswith("test_"):
            test()
            print("ok", name)
