#!/usr/bin/env python3
"""Manifest wpisów archiwów SSA (data.ssa EE/AoC) + relacje nadpisań przez luźne pliki. Tylko odczyt.
Użycie: manifest_archiwow.py <instalacja> <wyjście.json>"""
import hashlib, json, os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa

PARY = [("Empire Earth/Data/data.ssa", "Empire Earth/Data"),
        ("Empire Earth - The Art of Conquest/Data/data.ssa", "Empire Earth - The Art of Conquest/Data")]


def main():
    root, out = sys.argv[1], sys.argv[2]
    wyn = {}
    for arch, data_dir in PARY:
        A = ssa.ArchiwumSSA(os.path.join(root, arch))
        wp = []
        for k, w in sorted(A.wpisy.items()):
            raw = A.czytaj_surowe(k)
            wp.append({"nazwa": w.nazwa, "rozmiar": w.rozmiar, "pk01": raw[:4] == b"PK01",
                       "sha256_surowe": hashlib.sha256(raw).hexdigest()})
        # luźne pliki w katalogach odpowiadających wpisom archiwum
        nadp = []
        for d, _, fn in os.walk(os.path.join(root, data_dir)):
            for n in fn:
                rel = os.path.relpath(os.path.join(d, n), os.path.join(root, data_dir)).replace(os.sep, "/").lower()
                if rel in A.wpisy:
                    loc = open(os.path.join(d, n), "rb").read()
                    rozp = A.czytaj(rel)
                    nadp.append({"wpis": rel, "luzny": f"{data_dir}/{os.path.relpath(os.path.join(d, n), os.path.join(root, data_dir))}",
                                 "identyczny_z_rozpakowanym": loc == rozp, "rozmiar_luzny": len(loc), "rozmiar_wpisu": len(rozp)})
        typy = collections.Counter(x["nazwa"].rsplit(".", 1)[-1].lower() for x in wp)
        wyn[arch] = {"liczba_wpisow": len(wp), "typy": dict(typy), "nadpisania_luznymi": nadp, "wpisy": wp}
        A.zamknij()
        print(arch, len(wp), dict(typy), "nadpisań:", len(nadp), "identycznych:", sum(x["identyczny_z_rozpakowanym"] for x in nadp))
    json.dump(wyn, open(out, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
