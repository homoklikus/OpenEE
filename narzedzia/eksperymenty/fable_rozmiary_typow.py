#!/usr/bin/env python3
"""Eksperyment Fable 2: typy dbobjects według rozmiaru kolizji i grupy typu („Unit type”).

Użycie:  fable_rozmiary_typow.py <instalacja Empire Earth Gold> [--grupa=N] [--rozmiar=X]
Czyta db/dbobjects.dat z Data/data.ssa obu gier (tylko odczyt) i wypisuje:
  * histogram „Size of collider” typów ruchomych (Speed > 0) w EE i AoC,
  * przedstawicieli progów < 1, 1.0, 1.5, 2.0, 3.0 z promieniem okna kontaktów R i warunkiem gałęzi dużych jednostek,
  * typy o zadanej grupie (--grupa=34 → grupa 0x22 z filtra kontaktów AoC),
  * typy, których rozmiar, prędkość albo grupa różnią się między EE i AoC.
Niczego nie zapisuje.
"""
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from eeformaty import db
from eeformaty.ssa import ArchiwumSSA

EE, AOC = "Empire Earth", "Empire Earth - The Art of Conquest"


def wczytaj(inst):
    w = {}
    for g in (EE, AOC):
        a = ArchiwumSSA(os.path.join(inst, g, "Data", "data.ssa"))
        w[g] = {int(o["ID"]): o for o in db.dekoduj(a.czytaj("db/dbobjects.dat"), "dbobjects")}
    return w


def promien(s):
    return s if s >= 1.0 else max(0.5, s / 2)


def opis(o):
    s = float(o["Size of collider"])
    return "%4d %-34s rozmiar %.2f R %.2f predkosc %.2f grupa %3d kolizyjny %s budynek %s" % (
        int(o["ID"]), str(o["Name"])[:34], s, promien(s), float(o["Speed"]), int(o["Unit type"]),
        o["Collidable"], o["Is building?"])


def main():
    inst = sys.argv[1]
    grupa = rozm = None
    for a in sys.argv[2:]:
        if a.startswith("--grupa="): grupa = int(a[8:])
        if a.startswith("--rozmiar="): rozm = float(a[10:])
    w = wczytaj(inst)
    for g in (EE, AOC):
        hist = {}
        for o in w[g].values():
            if float(o["Speed"]) > 0:
                k = round(float(o["Size of collider"]), 3)
                hist[k] = hist.get(k, 0) + 1
        print(g, "— typy ruchome wg rozmiaru kolizji:", dict(sorted(hist.items())))
    if rozm is not None:
        for g in (EE, AOC):
            print("==", g, "rozmiar", rozm)
            for o in w[g].values():
                if abs(float(o["Size of collider"]) - rozm) < 1e-6 and float(o["Speed"]) > 0: print(" ", opis(o))
    if grupa is not None:
        for g in (EE, AOC):
            print("==", g, "grupa", grupa)
            for o in w[g].values():
                if int(o["Unit type"]) == grupa: print(" ", opis(o))
    print("== różnice EE/AoC (rozmiar, prędkość, grupa) dla wspólnych ID")
    n = 0
    for i in sorted(set(w[EE]) & set(w[AOC])):
        a, b = w[EE][i], w[AOC][i]
        r = [k for k in ("Size of collider", "Speed", "Unit type", "Collidable") if str(a[k]) != str(b[k])]
        if r:
            n += 1
            print(" ", i, a["Name"], {k: (a[k], b[k]) for k in r})
    print("  razem:", n, "| tylko AoC:", len(set(w[AOC]) - set(w[EE])), "| tylko EE:", len(set(w[EE]) - set(w[AOC])))


if __name__ == "__main__":
    main()
