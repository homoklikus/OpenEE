#!/usr/bin/env python3
"""Scenariusz testowy ruchu (etap 9): mapa Riverlands (rzeka z brodami) + grupy jednostek gracza 1 do badań
zaznaczania, rozkazów, ruchu grupowego i kolizji w oryginalnym EE.

Generator Riverlands jest używany WYŁĄCZNIE jako biblioteka (import, bez zmian w jego plikach): S5Model, rekord
„świeżego” obywatela edytora, zapis kawałka 5. Plik wynikowy jest kopią testową w Testy_MCP (nie w instalacji gry –
do gry trafia przez MCP gra_do_gry jako 000_EETEST_*).

Użycie:  python3 narzedzia/scenariusz_testowy_ruchu.py <wejście.scn> <wyjście.scn> [--riverlands=<plik .py>]
Układ grup: GRUPY (pasy S/D – opis przy liście; kolumny × wiersze, odstęp 1 pole); obywatele startowi → ZAPAS.
"""
import importlib.util
import json
import math
import struct
import sys
from pathlib import Path

# Pasy testowe (etap 9): grupa startuje w środku (U, V) = ((S − D)/2, (S + D)/2) – S = U + V, D = V − U.
# Ruch główny w pasie: (+8, +8) – wzdłuż osi „w prawo” ekranu EE (azymut kamery 135°), czyli w poprzek kadru.
# Pasy oddalone o ΔD = 12–18 (≈ 8,5–13 pól prostopadle). Mapa Riverlands (X, Y) ↔ pola gry: U = X + Y + 1,
# V = 99 + X − Y (pas = wiersz Y = (98 − D)/2; ruch główny = +8 w X). Rzeka: Y ≈ 47–51 ⇒ D ≈ −4…+4 (pomiar: G50 z D = −8
# stał na brzegu, rzeka w kadrze G25); brody: X ≈ 28 → (78, 78) i X ≈ 67 → (117, 117).
# nazwa, typ dbobjects, S, D, kolumn (wzdłuż U), wierszy (wzdłuż V)
GRUPY = [
    ("G1", 32, 125, 40, 1, 1),
    ("G2", 32, 125, 52, 2, 1),
    ("G5", 32, 125, 64, 5, 1),
    ("G10", 32, 125, 26, 5, 2),
    ("G25", 32, 125, 10, 5, 5),
    ("G50", 32, 125, -8, 10, 5),
    ("KAW5", 136, 122, -28, 5, 1),
    ("MIE5", 22, 128, -28, 5, 1),
    ("NAPRZ_A", 32, 125, -46, 5, 1),
    ("NAPRZ_B", 32, 150, -46, 5, 1),
    ("BROD10", 32, 172, 42, 5, 2),
    ("BUD5", 32, 107, 82, 1, 5),        # przed budynkiem (Capitol gracza 1 w (17, 99))
]
ZAPAS = (160, 90)                        # tu przenoszeni są obywatele startowi Riverlands (wolny teren przy Capitolu)


def _riverlands(sciezka):
    spec = importlib.util.spec_from_file_location("riverlands_bib", sciezka)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    opcje = dict(x[2:].split("=", 1) for x in sys.argv[1:] if x.startswith("--") and "=" in x)
    wej, wyj = Path(a[0]), Path(a[1])
    rl = _riverlands(opcje.get("riverlands", str(Path(__file__).resolve().parents[2] / "Riverlands" / "Riverlands_0_8_1.py")))
    blob = wej.read_bytes()
    raw5 = rl.raw_section(blob, rl.SECTION_PLAYERS)
    model = rl.S5Model.parse(raw5)
    slot = model.players[1]
    nast = slot.get("r458")
    wzor = list(rl._fresh_citizen_fields())
    uklad = {}
    n_obyw = 0
    # obywatele startowi: przeniesieni z otoczenia Capitolu do pasa ZAPAS (wolne przejście dla testu BUD5)
    zs, zd = ZAPAS
    for n, u in enumerate(rl.player_citizens(slot)):
        u.set_position(int((zs - zd) / 2) + n % 5, int((zs + zd) / 2) + n // 5, 0.5, 0.5)
    for nazwa, typ, ss, dd, kol, wie in GRUPY:
        u0 = int(round((ss - dd) / 2 - (kol - 1) / 2))
        v0 = int(round((ss + dd) / 2 - (wie - 1) / 2))
        ids = []
        for j in range(wie):
            for i in range(kol):
                unit = rl.S5Unit(list(wzor))
                unit.set("id", (slot.index << 24) | nast)
                unit.set("type", typ)
                unit.set_position(u0 + i, v0 + j, 0.5, 0.5)
                unit.set("angle", 0.0)
                slot.insert_unit(unit)
                ids.append(hex((slot.index << 24) | nast))
                nast += 1
                if typ == rl.CITIZEN_TYPE:
                    n_obyw += 1
        uklad[nazwa] = {"typ": typ, "U0": u0, "V0": v0, "kolumn": kol, "wierszy": wie, "S": ss, "D": dd,
                        "srodek": [u0 + (kol - 1) / 2 + 0.5, v0 + (wie - 1) / 2 + 0.5], "id": ids}
    k = sum(len(g["id"]) for g in uklad.values())
    slot.set("T.b14", slot.get("T.b14") + k)          # populacja (jak przy dodawaniu obywateli w edytorze)
    slot.set("T.b18", slot.get("T.b18") + k)
    first = slot.get("T.4a8[14].x0c")
    slot.stat_extend(14, [first + j for j in range(1, n_obyw + 1)])
    rl._refresh_type_statistic(slot)
    raw_nowy = model.to_bytes()
    rl.S5Model.parse(raw_nowy)                          # kontrola odczytu
    built = rl.replace_section(blob, rl.SECTION_PLAYERS, rl.pack_pk01(raw_nowy))
    built = rl.patch_internal_filename(built, wyj.name)
    built = struct.pack("<I", len(built) - 4) + built[4:]
    if rl.raw_section(built, rl.SECTION_PLAYERS) != raw_nowy:
        raise SystemExit("kawałek 5: błąd zapisu")
    wyj.write_bytes(built)
    wyj.with_suffix(".uklad.json").write_text(json.dumps(uklad, indent=1))
    print(json.dumps({"plik": str(wyj), "jednostek_dodanych": k, "grupy": {n: len(g["id"]) for n, g in uklad.items()}}))


if __name__ == "__main__":
    main()
