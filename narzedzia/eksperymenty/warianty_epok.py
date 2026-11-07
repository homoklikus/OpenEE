#!/usr/bin/env python3
"""Tabela wariantów grafiki wg epok z danych EE/AoC (etap 8) i przewidywane grafiki obiektów scenariusza.

Użycie:
  python3 narzedzia/eksperymenty/warianty_epok.py --gra "<katalog Empire Earth Gold>" [--md docs/WARIANTY_EPOK.md]
         [--scn plik.scn ...] [--json wynik.json]
Wynik zawiera wyłącznie nazwy i identyfikatory z tabel gry (bez zasobów graficznych).
"""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import ssa, db, epoki, scn, dcl, gracze  # noqa: E402


def _archiwa(gra):
    out = []
    for inst in ("Empire Earth - The Art of Conquest", "Empire Earth"):
        p = os.path.join(gra, inst, "Data", "data.ssa")
        if os.path.exists(p):
            out.append(ssa.ArchiwumSSA(p))
    return out


def _czytaj(arch, klucz):
    for a in arch:
        if klucz in a.wpisy:
            return a.czytaj(klucz)
    raise FileNotFoundError(klucz)


def wczytaj(gra):
    arch = _archiwa(gra)
    tech = epoki.techtree(_czytaj(arch, "db/dbtechtree.dat"))
    zd = epoki.zdarzenia(_czytaj(arch, "db/dbevents.dat"))
    ef = epoki.efekty(_czytaj(arch, "db/dbeffects.dat"))
    ob = {o["ID"]: o for o in db.dekoduj(_czytaj(arch, "db/dbobjects.dat"), "dbobjects")}
    gr = {g["ID"]: g for g in db.dekoduj(_czytaj(arch, "db/dbgraphics.dat"), "dbgraphics")}
    return epoki.Warianty(tech, zd, ef, ob), gr


def _sekwencje(g):
    """Liczba wypełnionych gniazd modelu (animacje) w wierszu dbgraphics."""
    n = 0
    for k, v in g.items():
        if k.startswith("Model path") and str(v).strip():
            n += 1
    return n


def tabela(W, G):
    """Wiersze: (epoka, nazwa epoki, obiekt, nazwa obiektu, grafika, nazwa grafiki, model, tekstura, gniazda)."""
    wiersze = []
    zmieniane = sorted({ob for ep in W.epoki for ob, _, _ in W.zmiany_zdarzenia(ep["event"])})
    for ob in zmieniane:
        poprz = None
        for ep in [None] + W.epoki:
            gid = W.grafika(ob, ep["id"] if ep else -1)
            if gid == poprz:
                continue
            poprz = gid
            g = G.get(gid, {})
            wiersze.append((ep["epoka"] if ep else 0, ep["nazwa"] if ep else "(bazowa – dbobjects)", ob,
                            W.obiekty.get(ob, {}).get("Name", "?"), gid, g.get("Name 1", "?"),
                            g.get("Model path", ""), g.get("Texture path", ""), _sekwencje(g)))
    return wiersze


def gracze_scn(sciezka):
    d = open(sciezka, "rb").read()
    for c in scn.kawalki(d):
        if c["tag"] == 5:
            return gracze.czytaj(dcl.maybe_unpack(c["surowe"]), c["minor"])
    return []


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gra", required=True)
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--scn", nargs="*", default=[])
    a = ap.parse_args()
    W, G = wczytaj(a.gra)
    rows = tabela(W, G)
    wynik = {"epoki": [{"id": e["id"], "nazwa": e["nazwa"], "numer": e["epoka"], "event": e["event"],
                        "zmian_grafiki": len(W.zmiany_zdarzenia(e["event"]))} for e in W.epoki],
             "tabela": rows, "scenariusze": {}}
    for s in a.scn:
        P = gracze_scn(s)
        opis = []
        for i, g in enumerate(P):
            ee = g.get("ee", {})
            et = ee.get("epoka_tech", -1)
            pozycje = {}
            for u in g["jednostki"]:
                t = int(u.get("type", -1))
                if t in pozycje:
                    continue
                gid = W.grafika(t, et, ee.get("zbadane", []))
                baz = int(W.obiekty.get(t, {}).get("Graphic ID", -1))
                if gid != baz:
                    pozycje[t] = (W.obiekty[t]["Name"], baz, G.get(baz, {}).get("Name 1"), gid, G.get(gid, {}).get("Name 1"))
            opis.append({"gracz": i, "nazwa": g["nazwa"], "epoka_tech": et,
                         "epoka": W.tech.get(et, {}).get("nazwa"), "obiektow": len(g["jednostki"]),
                         "zmienione_grafiki": list(pozycje.values())})
        wynik["scenariusze"][os.path.basename(s)] = opis
    if a.json:
        json.dump(wynik, open(a.json, "w"), ensure_ascii=False, indent=1)
    if a.md:
        L = ["# Warianty grafiki wg epok – tabela z danych EE/AoC (etap 8)", "",
             "Wygenerowano: `narzedzia/eksperymenty/warianty_epok.py` z `dbtechtree`, `dbevents`, `dbeffects` (kod 6 – zmiana grafiki),",
             "`dbobjects` i `dbgraphics` instalacji AoC. Wiersz = epoka, od której obiekt ma daną grafikę (stan po nałożeniu",
             "zmian wszystkich epok ≤ E). „Gniazda” = liczba wypełnionych ścieżek modelu w wierszu dbgraphics (sekwencje",
             "animacji należą do grafiki – zmiana grafiki zmienia model, teksturę i animacje razem).", "",
             "| Epoka | Nazwa epoki | Obiekt | Nazwa obiektu | Grafika | Nazwa grafiki | Model | Tekstura | Gniazda |",
             "|---|---|---|---|---|---|---|---|---|"]
        for r in rows:
            L.append("| " + " | ".join(str(x).replace("|", "/").replace("\\", "/") for x in r) + " |")
        L += ["", "## Epoki (dbtechtree → dbevents)", "", "| Tech ID | Epoka | Numer | Event ID | Zmian grafiki |",
              "|---|---|---|---|---|"]
        for e in wynik["epoki"]:
            L.append("| %d | %s | %d | %d | %d |" % (e["id"], e["nazwa"], e["numer"], e["event"], e["zmian_grafiki"]))
        open(a.md, "w").write("\n".join(L) + "\n")
    print(json.dumps({"epoki": len(W.epoki), "wierszy": len(rows),
                      "scenariusze": {k: [(g["nazwa"], g["epoka"]) for g in v if g["obiektow"]] for k, v in wynik["scenariusze"].items()}},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
