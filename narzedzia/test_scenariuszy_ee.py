#!/usr/bin/env python3
"""Etap 3: odczyt obiektów wszystkich scenariuszy kampanii EE (wersja 231) i AoC (250) z instalacji referencyjnej.
Wynik: wyniki/test_scenariuszy_ee_aoc.json (wzorzec dla testów GDScript). Użycie: test_scenariuszy_ee.py <instalacja>"""
import sys, os, json, glob
sys.path.insert(0, os.path.dirname(__file__))
from eeformaty.ssa import ArchiwumSSA
from eeformaty import scn, gracze
ref = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/mnt/Empire Earth Gold')
wyn = {"pliki": {}, "podsumowanie": {}}
for gra in ("Empire Earth", "Empire Earth - The Art of Conquest"):
    for arch in sorted(glob.glob(f"{ref}/{gra}/Data/Campaigns/*.ssa")):
        a = ArchiwumSSA(arch)
        for k in sorted(x for x in a.wpisy if x.endswith('.scn')):
            klucz = f"{os.path.basename(arch)}:{k}"
            try:
                kw = scn.kawalki(a.czytaj(k)); c5 = [c for c in kw if c['tag'] == 5][0]
                g = gracze.czytaj(scn.maybe_unpack(c5['surowe']), c5['minor'])
                wyn["pliki"][klucz] = {"wersja": c5['minor'], "gracze": len(g), "obiekty": sum(len(x['jednostki']) for x in g),
                                       "niepelni": [i for i, x in enumerate(g) if 'niepelny' in x]}
            except Exception as e:
                wyn["pliki"][klucz] = {"blad": repr(e)[:200]}
for w in (231, 250):
    pl = [v for v in wyn["pliki"].values() if v.get("wersja") == w]
    wyn["podsumowanie"][str(w)] = {"pliki": len(pl), "pelne": sum(1 for v in pl if not v["niepelni"]),
                                   "z_niepelnym_graczem": sum(1 for v in pl if v["niepelni"]), "obiekty": sum(v["obiekty"] for v in pl)}
wyn["podsumowanie"]["bledy"] = sum(1 for v in wyn["pliki"].values() if "blad" in v)
os.makedirs("wyniki", exist_ok=True)
json.dump(wyn, open("wyniki/test_scenariuszy_ee_aoc.json", "w"), indent=1, ensure_ascii=False)
print(json.dumps(wyn["podsumowanie"], ensure_ascii=False))
for k, v in wyn["pliki"].items():
    if "blad" in v or v.get("niepelni"): print(k, v)
