#!/usr/bin/env python3
"""Efekty obszarowe Titan z danych gry (etap 34): szablony dbareaeffect, zestawy jednostek dbunitset, budynki SCN.

Narzędzie OpenEE. Odtwarza z danych gry wejście dla Core (cpp/core/include/openee/efekty_obszaru.hpp):
  - szablon efektu = rekord dbareaeffect w układzie pamięci gry (loader EE 0x664C71): typ +0x20, kształt +0x24,
    relacja +0x28, rozmiar +0x2C, Max morale +0x3C, Heal effect +0x40, zestaw jednostek +0x38;
  - zestaw jednostek rozwiązany algorytmem EE 0x52BFA4 / 0x52BF39 dla typów 1…0x2FF: rodziny (1…0x38) i obiekty;
    gdy zestaw ma rodziny – należy typ z rodziną z listy i bez ID na liście obiektów; bez rodzin – typ z listy
    obiektów; inaczej „Include unit set” (rekurencyjnie); na końcu „Exclude unit set” (rekurencyjnie) [P: kod;
    przypisanie pól pliku 19/20 do +0x30/+0x34 – W];
  - budynki z kawałka 5 scenariusza: typ (ID dbobjects), gracz, pole kotwicy, rozmiar („Square occupied”),
    środek = kotwica + rozmiar/2 [W: zgodne z odczytem EEAEMoraleFromBuildings +0x08/+0x0C = (185, 110) dla
    Town Center (184, 109) o rozmiarze 2], efekty („Area Effect ID” 1–4); domy (ID 37) – zawsze.
  - „Alter max morale (dynamic)” wariantów gry (dbgamevariant).

Użycie:
  efekty_obszaru.py --instalacja KATALOG_GRY [--wariant ee|aoc] [--scn PLIK.scn] [-o WYJŚCIE.json] [--nazwy]
Wynik zawiera tylko liczby wyprowadzone z danych (bez zasobów gry); nazwy rekordów z bazy gry – tylko z --nazwy
(do pracy lokalnej, nie do repozytorium).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from eeformaty import db, dcl, gracze, scn  # noqa: E402
from eeformaty.ssa import ArchiwumSSA  # noqa: E402

KATALOG = {"ee": "Empire Earth", "aoc": "Empire Earth - The Art of Conquest"}
DOM = 37


def zestawy(us, obiekty):
    po_id = {int(s["ID"]): s for s in us}

    def nalezy(sid, t, glebokosc=0):
        s = po_id.get(sid)
        if s is None or glebokosc > 16:
            return False
        rodz = {int(s[k]) for k in s if k.startswith("Family ID") and 0 < int(s[k]) < 0x39}
        obj = {int(s[k]) for k in s if k.startswith("Object ID") and int(s[k]) != 0}
        fam = obiekty.get(t, {}).get("Family ID")
        glowny = False
        if rodz or obj:
            if rodz:
                glowny = (fam in rodz) and (t not in obj)
            else:
                glowny = t in obj
        else:
            glowny = True
        if not glowny:
            inc = int(s.get("Include unit set...", 0) or 0)
            if not (inc and nalezy(inc, t, glebokosc + 1)):
                return False
        exc = int(s.get("Exclude unit set", 0) or 0)
        return not (exc and nalezy(exc, t, glebokosc + 1))

    return nalezy


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--instalacja", required=True)
    ap.add_argument("--wariant", default="ee", choices=["ee", "aoc"])
    ap.add_argument("--scn")
    ap.add_argument("-o", "--wyjscie")
    ap.add_argument("--nazwy", action="store_true", help="dołącz nazwy rekordów z bazy gry (lokalnie)")
    a = ap.parse_args(argv)
    ar = ArchiwumSSA(os.path.join(a.instalacja, KATALOG[a.wariant], "Data", "data.ssa"))
    ob = {int(o["ID"]): o for o in db.dekoduj(ar.czytaj("db/dbobjects.dat"), "dbobjects")}
    for o in ob.values():
        o["Family ID"] = int(o["Family ID"])
    ae = db.dekoduj(ar.czytaj("db/dbareaeffect.dat"), "dbareaeffect")
    us = db.dekoduj(ar.czytaj("db/dbunitset.dat"), "dbunitset")
    gv = db.dekoduj(ar.czytaj("db/dbgamevariant.dat"), "dbgamevariant")
    nalezy = zestawy(us, ob)
    wyn = {"format": "openee_efekty_v1", "wariant": a.wariant,
           "warianty_gry": [{"id": int(g["ID"]), "nazwa": g["Name"], "premia_morale": int(g["Alter max morale (dynamic)"])}
                            for g in gv],
           "szablony": []}
    for r in ae:
        if int(r["ID"]) <= 0:
            continue
        sid = int(r["Apply on unit set"])
        wyn["szablony"].append({
            "id": int(r["ID"]), "nazwa": r["Name"], "typ": int(r["Effect type"]), "ksztalt": int(r["Unknown"]),
            "relacja": int(r["Unknown#2"]), "rozmiar": float(r["Area size"]), "maks_morale": int(r["Max morale"]),
            "wartosc_40": int(r["Heal effect"]), "zestaw_id": sid,
            "zestaw": [t for t in range(1, 0x300) if t in ob and nalezy(sid, t)]})
    if a.scn:
        d = open(a.scn, "rb").read()
        c5 = dcl.maybe_unpack([c for c in scn.kawalki(d) if c["tag"] == 5][0]["surowe"])
        G = None
        for wersja in (231, 250):   # wersja kawałka 5 zależy od pliku, nie od wariantu gry (EE 231, AoC 250)
            try:
                G = gracze.czytaj(c5, wersja)
                break
            except gracze.BladFormatu:
                continue
        if G is None:
            raise SystemExit("nie odczytano kawałka 5 scenariusza")
        bud = []
        for g, gr in enumerate(G):
            for u in gr["jednostki"]:
                o = ob.get(u["type"])
                if o is None:
                    continue
                ef = [int(o[k]) for k in o if k.startswith("Area Effect ID") and int(o[k]) > 0]
                if not ef and u["type"] != DOM:
                    continue
                n = int(o["Square occupied"]) or 1
                bud.append({"id": hex(u["id"]), "typ": u["type"], "nazwa": o["Name"].strip(), "gracz": g,
                            "pole": [u["X"], u["Y"]], "rozmiar": n, "srodek": [u["X"] + n / 2, u["Y"] + n / 2],
                            "efekty": ef})
        wyn["scenariusz"] = os.path.basename(a.scn)
        wyn["budynki"] = bud
    if not a.nazwy:
        for w in wyn["szablony"] + wyn.get("budynki", []) + wyn["warianty_gry"]:
            w.pop("nazwa", None)
    tekst = json.dumps(wyn, ensure_ascii=False, indent=1)
    if a.wyjscie:
        open(a.wyjscie, "w", encoding="utf-8").write(tekst + "\n")
    else:
        print(tekst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
