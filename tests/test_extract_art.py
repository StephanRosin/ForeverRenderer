#!/usr/bin/env python3
"""Tests fuer tools/extract-art: WDC5-Parser, Atlas-Koordinaten, BLP-Format.

    python3 -I tests/test_extract_art.py

Werte stammen aus WoW Forever 1.60.1.70938 (UiTextureAtlas*.db2, gegen wago.tools geprueft).
"""
import importlib.machinery
import importlib.util
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


def member(name, l, r, t, b, flags=0, ow=0, oh=0, atlas=2060, element=1, id_=1):
    return {"CommittedName": name, "ID": id_, "UiTextureAtlasID": atlas, "CommittedLeft": l, "CommittedRight": r,
            "CommittedTop": t, "CommittedBottom": b, "CommittedFlags": flags, "OverrideWidth": ow,
            "OverrideHeight": oh, "UiTextureAtlasElementID": element}


ATLAS_2060 = {"ID": 2060, "FileDataID": 4631591, "AtlasWidth": 1024, "AtlasHeight": 512}


def test_atlas_koordinaten():
    e = ea.atlas_eintrag(member("ui-hud-unitframe-player-portraiton", 1, 199, 87, 158), ATLAS_2060, "x.png")
    assert (e["width"], e["height"]) == (198, 71), e
    assert (e["left"], e["right"], e["top"], e["bottom"]) == (1 / 1024, 199 / 1024, 87 / 512, 158 / 512), e
    assert not e["tilesH"] and not e["tilesV"]


def test_atlas_override_und_kacheln():
    # vignetteloot: Pixel 32x32, Override 24x24; Flag 8 ist kein Kachel-Bit
    e = ea.atlas_eintrag(member("vignetteloot", 583, 615, 752, 784, flags=8, ow=24, oh=24), ATLAS_2060, "x.png")
    assert (e["width"], e["height"]) == (24, 24) and not e["tilesH"] and not e["tilesV"]
    # _BattleBar-Mid kachelt waagrecht (4), !Garr_InfoBox-Left senkrecht (2), Garr_InfoBox-BackgroundTile beides (6)
    assert ea.atlas_eintrag(member("_battlebar-mid", 0, 256, 0, 124, flags=4), ATLAS_2060, "x")["tilesH"]
    links = ea.atlas_eintrag(member("!garr_infobox-left", 1, 136, 0, 256, flags=2), ATLAS_2060, "x")
    assert links["tilesV"] and not links["tilesH"]
    beides = ea.atlas_eintrag(member("t", 0, 256, 0, 256, flags=6), ATLAS_2060, "x")
    assert beides["tilesH"] and beides["tilesV"]
    nie = ea.atlas_eintrag(member("t", 0, 256, 0, 256, flags=0x16), ATLAS_2060, "x")
    assert not nie["tilesH"] and not nie["tilesV"]


def test_atlas_doppelte_namen():
    # transmog-icon-hidden gibt es in zwei Atlanten; die hoehere ID gewinnt, ausser ihre Textur fehlt
    atlanten = {610: dict(ATLAS_2060, ID=610, FileDataID=1116940), 3543: dict(ATLAS_2060, ID=3543, FileDataID=7344437)}
    members = [member("transmog-icon-hidden", 276, 312, 154, 184, atlas=610, element=5493, id_=5647),
               member("transmog-icon-hidden", 988, 1017, 576, 600, atlas=3543, element=5493, id_=33891)]
    elemente = {5493: "Transmog-Icon-Hidden"}
    beide = {1116940: "a.png", 7344437: "b.png"}
    ergebnis, probleme = ea.atlas_json(atlanten, elemente, members, beide)
    assert ergebnis["transmog-icon-hidden"]["file"] == "b.png" and probleme["doppelt"] == 1
    ergebnis, _ = ea.atlas_json(atlanten, elemente, members, {1116940: "a.png"})
    assert ergebnis["transmog-icon-hidden"]["file"] == "a.png"


def test_atlas_committed_name_als_zusatzname():
    # Element "_Horde-NineSlice-EdgeTop" hat den Member "_UI-Frame-Horde-TileTop": beide Namen muessen gehen
    members = [member("_UI-Frame-Horde-TileTop", 0, 256, 0, 64, flags=4, element=7)]
    ergebnis, probleme = ea.atlas_json({2060: ATLAS_2060}, {7: "_Horde-NineSlice-EdgeTop"}, members, {4631591: "h.png"})
    assert set(ergebnis) == {"_horde-nineslice-edgetop", "_ui-frame-horde-tiletop"} and probleme["aliase"] == 1


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
