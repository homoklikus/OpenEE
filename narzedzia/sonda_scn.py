#!/usr/bin/env python3
"""Sonda: wyodrębnia scenariusze z archiwów kampanii do cache i sprawdza czytnik terenu."""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, scn
root = sys.argv[1]; out = sys.argv[2]
os.makedirs(out, exist_ok=True)
wyn = []
for a in sys.argv[3:]:
    A = ssa.ArchiwumSSA(os.path.join(root, a))
    for k, w in A.wpisy.items():
        if not k.endswith(".scn"):
            continue
        d = A.czytaj(k)
        r = {"archiwum": a, "wpis": w.nazwa, "rozmiar": len(d)}
        try:
            ch = scn.kawalki(d)
            r["kawalki"] = [(c["tag"], c["major"], c["minor"], c["rozmiar"]) for c in ch]
            c4 = [c for c in ch if c["tag"] == 4][0]
            t = scn.teren(c4["surowe"])
            r.update(A=t["A"], B=t["B"], K=t["K"], ogon=t["ogon"],
                     tereny=dict(collections.Counter(t["teren"]).most_common(12)),
                     wys_min=round(min(t["wysokosc"]), 3), wys_max=round(max(t["wysokosc"]), 3),
                     klasy=dict(collections.Counter(t["klasa"]).most_common(8)))
        except Exception as ex:
            r["blad"] = repr(ex)[:300]
        wyn.append(r)
        print(json.dumps(r, ensure_ascii=False)[:400])
json.dump(wyn, open(os.path.join(out, "sonda_scn.json"), "w"), ensure_ascii=False, indent=1)
