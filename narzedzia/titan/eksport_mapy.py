#!/usr/bin/env python3
"""Eksport mapy scenariusza SCN do neutralnego pliku dla OpenEE Core (etap 30) – BEZ interpretacji Titan.

Narzędzie tylko DEKODUJE dane (te same dekodery co Godot: narzedzia/eeformaty/scn.py, gracze.py, db.py).
Interpretację (teren komórki, przejezdność, zajęte pola) wykonuje wyłącznie Core: MapaTitan::z_scn
(cpp/core/src/mapa.cpp) – Godot dostaje ją przez GDExtension. Dzięki temu Core i Godot nie mają dwóch
niezależnych interpretacji tej samej mapy.

Wynik (JSON, LOKALNIE – dane pochodzą z plików gry, nie trafiają do repozytorium):
  A, B, tekstura[], flagi[], f10[], wysokosc[]  – kawałek 4 w kolejności rombu
  rodzina_tekstury {id: Terrain family}         – dbterrain
  typy {typ: {kwadrat, unit_type, collidable, nazwa}} – dbobjects (tylko typy obecne w scenariuszu)
  obiekty [{id, typ, gracz, X, Y, x, y, z}]     – kawałek 5 (gracze i jednostki)
  pamiec (opcjonalnie, --pamiec zrzut.json z Riverlands_MCP mapa_zrzut): teren komórek, typy (blokuje),
         listy obiektów komórek – dane referencyjne z gry.

Użycie: eksport_mapy.py SCENARIUSZ.scn --instalacja KATALOG_GRY [--wariant ee|aoc] [--pamiec ZRZUT.json] -o WYJ.json
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from eeformaty import db, gracze as G, scn as S  # noqa: E402
from eeformaty.dcl import maybe_unpack  # noqa: E402
from eeformaty.ssa import ArchiwumSSA  # noqa: E402

ARCHIWA = {"ee": "Empire Earth/Data/data.ssa", "aoc": "Empire Earth - The Art of Conquest/Data/data.ssa"}


def kawalek4_surowy(blob: bytes) -> dict:
    ch = {c["tag"]: c for c in S.kawalki(blob)}
    t = S.teren(ch[4]["surowe"])
    d = maybe_unpack(ch[4]["surowe"])
    A, B, K = struct.unpack_from("<iiI", d, 0)
    T = 2 * A * B + A + B
    blk = ((K + 1) // 2) * 4
    f10, p = [], 12
    for _ in range(T):
        f10.append(struct.unpack_from("<f", d, p)[0])
        p += 4 + blk + 4
    return {"A": A, "B": B, "tekstura": list(t["teren"]), "flagi": list(t["flagi"]), "f10": f10,
            "wysokosc": list(t["wysokosc"]), "wersja_kawalka5": ch[5]["minor"], "_ch": ch}


def obiekty(ch: dict) -> list[dict]:
    k5 = ch[5]
    gr = G.czytaj(maybe_unpack(k5["surowe"]), k5["minor"])
    out = []
    for nr, g in enumerate(gr):
        for u in g.get("jednostki", []):
            out.append({"id": u.get("id"), "typ": u.get("type"), "gracz": nr, "X": u.get("X"), "Y": u.get("Y"),
                        "x": u.get("pos.x"), "y": u.get("pos.y"), "z": u.get("pos.z")})
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("scn")
    ap.add_argument("--instalacja", required=True)
    ap.add_argument("--wariant", default="ee", choices=("ee", "aoc"))
    ap.add_argument("--pamiec")
    ap.add_argument("--teren-dozwolony", action="append", default=[],
                    help="TYP:b0,b1,…,b15 – tablica EEUnitClass+0x5D6 z pamięci (Riverlands_MCP mapa_typ_jednostki)")
    ap.add_argument("--probki-z", help="zapis obs_rejestruj: próbki (x, y, z) jednostek do kontroli wysokości")
    ap.add_argument("-o", "--wyjscie", required=True)
    a = ap.parse_args(argv)
    blob = Path(a.scn).read_bytes()
    k4 = kawalek4_surowy(blob)
    ch = k4.pop("_ch")
    arch = ArchiwumSSA(str(Path(a.instalacja) / ARCHIWA[a.wariant]))

    def tab(n):
        r = db.dekoduj(arch.czytaj(f"db/{n}.dat"), n)
        return r["rekordy"] if isinstance(r, dict) else r
    rodzina = {int(r["ID"]): int(r["Terrain family"]) for r in tab("dbterrain") if 0 <= int(r["ID"]) < 256}
    ob = obiekty(ch)
    typy_db = {int(r["ID"]): r for r in tab("dbobjects")}
    typy = {}
    for o in ob:
        t = typy_db.get(int(o["typ"]))
        if t and str(o["typ"]) not in typy:
            typy[str(o["typ"])] = {"kwadrat": int(t.get("Square occupied") or 1), "unit_type": t.get("Unit type"),
                                   "collidable": t.get("Collidable"), "nazwa": t.get("Name")}
    wynik = {"opis": "LOKALNE – dane z plików gry (nie publikować). Dekodowanie bez interpretacji Titan.",
             "zrodlo": Path(a.scn).name, "wariant": a.wariant, **k4, "rodzina_tekstury": rodzina, "typy": typy,
             "obiekty": ob}
    if a.teren_dozwolony:
        wynik["teren_dozwolony"] = {t.split(":")[0]: [int(v) for v in t.split(":")[1].split(",")] for t in a.teren_dozwolony}
    if a.probki_z:
        r = json.loads(Path(a.probki_z).read_text())
        pz = []
        for p in r["probki"][::5]:
            for i in r["jednostki"]:
                j = p.get(i)
                if j and j.get("tryb") == 0:
                    pz.append([j["x"], j["y"], j["z"]])
        wynik["probki_z"] = pz[:3000]
    if a.pamiec:
        p = json.loads(Path(a.pamiec).read_text())
        wynik["pamiec"] = {"naglowek": p.get("naglowek"), "teren": p.get("teren"), "typy": p.get("typy"),
                           "obiekty_komorek": p.get("obiekty")}
    Path(a.wyjscie).write_text(json.dumps(wynik))
    print(json.dumps({"plik": a.wyjscie, "A": k4["A"], "B": k4["B"], "obiektow": len(ob), "typow": len(typy),
                      "z_pamiecia": bool(a.pamiec)}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
