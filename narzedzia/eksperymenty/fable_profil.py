#!/usr/bin/env python3
"""Eksperyment Fable 2: profil przejazdu jednostki wzdłuż osi X (porównanie tras z przeszkodą i bez).

Użycie:  fable_profil.py <nagranie.json> <id> [x1,x2,...]
Wypisuje dla pierwszej próbki po przekroczeniu każdego progu x: czas od przyjęcia rozkazu [ms gry], y, v, kurs [°],
liczbę kontaktów i k248; na końcu czas dojazdu (wejście w 9006) i pozycję końcową. Kierunek ruchu (rosnące albo
malejące x) wynika z trasy. Skrypt tylko czyta nagranie.
"""
import json, math, sys


def main():
    d = json.load(open(sys.argv[1])); P = d["probki"]
    U = sys.argv[2] if sys.argv[2].startswith("0x") else "0x1000" + sys.argv[2]
    progi = [float(a) for a in sys.argv[3].split(",")] if len(sys.argv) > 3 else [163.5, 164, 164.5, 165, 165.5, 166, 166.5, 167]
    t0 = None; kier = 1; i = 0; x0 = P[0][U]["x"]
    for p in P:
        s = p[U]
        if t0 is None:
            if s.get("trasa"):
                t0 = p["t"]; kier = 1 if s["trasa"][-1][0] >= x0 else -1
                if kier < 0: progi = sorted(progi, reverse=True)
                print("%s %s rozkaz t=%d" % (sys.argv[1].split("/")[-1], U, t0))
            continue
        while i < len(progi) and (s["x"] - progi[i]) * kier >= 0:
            print("  x>=%.2f  dt %6d  y %.3f  v %.3f  kurs %6.1f  kontakty %d  k248 %.0f" % (
                progi[i], p["t"] - t0, s["y"], s["v"], math.degrees(math.atan2(s["m11"], s["m01"])), s["kontakty"], s["k248"]))
            i += 1
        if s["stan"] == 9006:
            print("  dojazd dt %d  poz (%.3f,%.3f)" % (p["t"] - t0, s["x"], s["y"])); break


if __name__ == "__main__":
    main()
