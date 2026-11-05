#!/usr/bin/env python3
"""Test dekodera tabel db (zużycie co do bajta) w archiwach EE i AoC wskazanej instalacji + eksport układu."""
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, db
root = sys.argv[1]; wyn = {}
for gra in ("Empire Earth", "Empire Earth - The Art of Conquest"):
    A = ssa.ArchiwumSSA(os.path.join(root, gra, "Data", "data.ssa"))
    for t in db.OBSLUGIWANE:
        k = f"db/{t}.dat"
        if k not in A: continue
        try:
            r = db.dekoduj(A.czytaj(k), t); wyn[f"{gra}:{t}"] = {"ok": True, "rekordy": len(r)}
        except Exception as e:
            wyn[f"{gra}:{t}"] = {"ok": False, "blad": str(e)[:120]}
for k, v in wyn.items(): print(("OK  " if v["ok"] else "BŁĄD"), k, v.get("rekordy", v.get("blad")))
if len(sys.argv) > 2:
    json.dump(wyn, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
    db.eksportuj_uklad(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dane", "uklad_db.json"))
