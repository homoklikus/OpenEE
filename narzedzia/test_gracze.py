#!/usr/bin/env python3
"""Test czytnika kawałka 5 (gracze/obiekty) na scenariuszach kampanii AoC instalacji referencyjnej;
porównanie liczby jednostek z czytnikiem laboratorium (jeśli dostępny) i eksport gramatyki do dane/."""
import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, scn, dcl, gracze
R = sys.argv[1]; wyn = {}
lab = os.path.expanduser("~/mnt/EmpireEarth test/eemap_re/tools")
eep = None
if os.path.isdir(lab):
    sys.path.insert(0, lab)
    try:
        import eeplayer as eep
    except Exception:
        eep = None
for kamp in ("AOCRoman", "AOCAsian", "AOCPacific"):
    A = ssa.ArchiwumSSA(os.path.join(R, "Empire Earth - The Art of Conquest/Data/Campaigns", kamp + ".ssa"))
    for k in sorted(A.wpisy):
        if not k.endswith(".scn"): continue
        d = A.czytaj(k); c5 = dcl.maybe_unpack([c for c in scn.kawalki(d) if c["tag"] == 5][0]["surowe"])
        try:
            g = gracze.czytaj(c5)
            n = sum(len(x["jednostki"]) for x in g)
            ref = None
            if eep:
                p = eep.parse(c5); ref = sum(len(b["units"]) for pl in p["players"] for b in pl["buckets"])
            wyn[k] = {"ok": True, "graczy": len(g), "obiektow": n, "zgodne_z_lab": (ref == n) if ref is not None else None,
                      "kolory": [x["kolor"] for x in g[:4]], "typy_top": collections.Counter(u["type"] for x in g for u in x["jednostki"]).most_common(5)}
        except Exception as e:
            wyn[k] = {"ok": False, "blad": repr(e)[:150]}
        print(k, json.dumps(wyn[k], ensure_ascii=False)[:220])
if len(sys.argv) > 2:
    json.dump(wyn, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
    gracze.eksportuj_gramatyke(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dane", "gramatyka_jednostki.json"))
