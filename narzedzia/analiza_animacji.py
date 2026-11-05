#!/usr/bin/env python3
"""Etap 4 – analiza animacji modeli CEM i tabeli dbgraphics we wskazanej instalacji (tylko odczyt).

Użycie: analiza_animacji.py <instalacja_EE> <wynik.json>
Wynik (lokalny, niepublikowany – zawiera nazwy plików gry) trafia do wyniki/.
"""
import os, sys, json, struct, math, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, db, cem


def dekoduj_liste(dane, tabela):
    """Jak db.dekoduj, ale zwraca listę (nazwa, wartość) – pola o tych samych nazwach nie nadpisują się."""
    pola = db.schemat(tabela)
    n = struct.unpack_from("<I", dane, 0)[0]; p = 4; rek = []
    for _ in range(n):
        vals = []
        for nazwa, size, typ, extra in pola:
            if typ in ("STRING", "DYNAMIC_STRING"):
                sz = vals[extra][1] if typ == "DYNAMIC_STRING" else size
                s = dane[p:p + sz]; p += sz
                v = s.split(b"\0")[0].decode("latin-1") if s[:1] not in (b"\xcc", b"\xff") else ""
            elif typ == "FLOAT":
                v = struct.unpack_from("<f", dane, p)[0]; p += 4
            elif size == 1:
                v = dane[p]; p += 1
            else:
                v = struct.unpack_from("<i", dane, p)[0]; p += 4
            vals.append((nazwa, v))
        rek.append(vals)
    assert p == len(dane)
    return rek


def statystyka_modelu(m, glebokosc=0):
    kl = m["klatki"]; s = {"nazwa": m["nazwa"], "wersja": "%d.%d" % m["wersja"], "klatki": len(kl),
                          "tagi": m["tagi"], "potomne": [], "glebokosc": glebokosc}
    if m["wersja"] == (2, 0):
        s["wierzcholki"] = m["liczby"]["wierzcholki"]
        s["materialy"] = [x["nazwa"] for x in m["materialy"]]
        if len(kl) > 1:
            v0 = kl[0]["wierzcholki"]
            dmax = 0.0; uvzm = False
            for f in kl[1:]:
                v = f["wierzcholki"]
                for i in range(0, len(v), 8):
                    dmax = max(dmax, abs(v[i] - v0[i]), abs(v[i + 1] - v0[i + 1]), abs(v[i + 2] - v0[i + 2]))
                    if v[i + 6] != v0[i + 6] or v[i + 7] != v0[i + 7]:
                        uvzm = True
            s["max_przesuniecie_wierzcholka"] = round(dmax, 4)
            s["uv_zmienne"] = uvzm
    mac = [f["macierz"] for f in kl]
    s["macierz_0"] = [round(x, 4) for x in mac[0]] if mac else None
    s["macierz_zmienna"] = any(any(abs(a - b) > 1e-5 for a, b in zip(x, mac[0])) for x in mac[1:])
    s["tag_zmienny"] = any(any(abs(a - b) > 1e-5 for t1, t0 in zip(f["tagi"], kl[0]["tagi"]) for a, b in zip(t1, t0))
                           for f in kl[1:])
    for c in m["potomne"]:
        s["potomne"].append(statystyka_modelu(c, glebokosc + 1))
    return s


def main():
    root, wyj = sys.argv[1], sys.argv[2]
    wynik = {"dbgraphics": {}, "cem": {}, "podsumowanie": {}}
    for gra in ("Empire Earth", "Empire Earth - The Art of Conquest"):
        A = ssa.ArchiwumSSA(os.path.join(root, gra, "Data", "data.ssa"))
        g = "ee" if gra == "Empire Earth" else "aoc"
        if "db/dbgraphics.dat" in A:
            rek = dekoduj_liste(A.czytaj("db/dbgraphics.dat"), "dbgraphics")
            wynik["dbgraphics"][g] = [[[n, v] for n, v in r] for r in rek]
        licz = collections.Counter(); hist_kl = collections.Counter(); bledy = []
        for k in sorted(A.wpisy):
            if not k.endswith(".cem"):
                continue
            try:
                m = cem.czytaj_cem(A.czytaj(k))
            except Exception as e:
                bledy.append([k, str(e)[:100]]); continue
            st = statystyka_modelu(m); st["reszta"] = m["reszta_bajtow"]
            wynik["cem"][g + ":" + k] = st
            licz["modele"] += 1; hist_kl[st["klatki"]] += 1
            if st["potomne"]: licz["z_potomnymi"] += 1
            if st.get("max_przesuniecie_wierzcholka", 0) > 0: licz["anim_wierzcholkowa"] += 1
            if st["macierz_zmienna"]: licz["macierz_zmienna"] += 1
            if st["tagi"]: licz["z_tagami"] += 1
        wynik["podsumowanie"][g] = {"liczniki": dict(licz), "klatki_hist": dict(sorted(hist_kl.items())),
                                     "bledy": bledy}
    json.dump(wynik, open(wyj, "w"), ensure_ascii=False)
    print(json.dumps(wynik["podsumowanie"], ensure_ascii=False, indent=1)[:3000])


if __name__ == "__main__":
    main()
