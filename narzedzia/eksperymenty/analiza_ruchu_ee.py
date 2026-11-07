#!/usr/bin/env python3
"""Analiza trajektorii jednostek zapisanych przez MCP (ee_ruch.sledz → Testy_MCP/ee_ruch/*.json) – etap 9.

Wynik na grupę: czas startu i dojścia, prędkości (średnia, maks., wspólna/indywidualna), odchylenie od prostej,
minimalne odległości między jednostkami (kolizje), układ końcowy względem celu (przesunięcia, rozstaw, obrót
względem układu początkowego), liczba zatrzymań. Wejście: pliki JSON; wyjście: JSON na stdout (lub --md).
Użycie: python3 narzedzia/eksperymenty/analiza_ruchu_ee.py <plik.json> [...] [--cel=x,y] [--md]
"""
import json
import math
import sys


def _wektor(a, b):
    return (b[0] - a[0], b[1] - a[1])


def _dl(v):
    return math.hypot(v[0], v[1])


def analiza(d, cel=None):
    tr = {k: v for k, v in d["trajektorie"].items() if len(v) > 1}
    ids = sorted(tr)
    if not ids:
        return {"blad": "brak trajektorii"}
    n = len(ids)
    t_all = sorted({p[0] for v in tr.values() for p in v})
    start = {i: tr[i][0][1:3] for i in ids}
    kon = {i: tr[i][-1][1:3] for i in ids}
    sr0 = (sum(p[0] for p in start.values()) / n, sum(p[1] for p in start.values()) / n)
    sr1 = (sum(p[0] for p in kon.values()) / n, sum(p[1] for p in kon.values()) / n)
    kier = _wektor(sr0, sr1)
    dk = _dl(kier) or 1.0
    ux, uy = kier[0] / dk, kier[1] / dk           # kierunek marszu
    px, py = -uy, ux                              # prostopadły
    per = {}
    for i in ids:
        v = tr[i]
        droga = sum(_dl(_wektor(a[1:3], b[1:3])) for a, b in zip(v, v[1:]))
        ruch = [(a, b) for a, b in zip(v, v[1:]) if _dl(_wektor(a[1:3], b[1:3])) / max(b[0] - a[0], 1e-6) > 0.03]
        t0 = ruch[0][0][0] if ruch else None
        t1 = ruch[-1][1][0] if ruch else None
        # prędkość w środkowej części ruchu (bez rozpędzania i hamowania): mediana chwilowych
        vs = sorted(_dl(_wektor(a[1:3], b[1:3])) / max(b[0] - a[0], 1e-6) for a, b in ruch)
        vmed = vs[len(vs) // 2] if vs else 0.0
        prosta = _dl(_wektor(start[i], kon[i]))
        stop, w = 0, False
        for a, b in zip(v, v[1:]):
            mv = _dl(_wektor(a[1:3], b[1:3])) / max(b[0] - a[0], 1e-6) > 0.03
            if mv: w = True
            elif w and t1 is not None and b[0] < t1: stop += 1; w = False
        per[i] = {"start": [round(x, 3) for x in start[i]], "koniec": [round(x, 3) for x in kon[i]],
                  "t_start": t0, "t_koniec": t1, "droga": round(droga, 3), "prosta": round(prosta, 3),
                  "kretosc": round(droga / prosta, 3) if prosta > 0.05 else None, "v_mediana": round(vmed, 3),
                  "v_maks": round(vs[-1], 3) if vs else 0.0, "zatrzymania_w_drodze": stop}
    # minimalna odległość par w czasie (próbki wspólne po indeksie)
    m = min(len(tr[i]) for i in ids)
    dmin, t_dmin = 1e9, None
    for k in range(m):
        for a in range(n):
            for b in range(a + 1, n):
                pa, pb = tr[ids[a]][k], tr[ids[b]][k]
                dd = _dl(_wektor(pa[1:3], pb[1:3]))
                if dd < dmin: dmin, t_dmin = dd, pa[0]

    def uklad(pos, sr):
        return {i: (( pos[i][0] - sr[0]) * ux + (pos[i][1] - sr[1]) * uy,
                    (pos[i][0] - sr[0]) * px + (pos[i][1] - sr[1]) * py) for i in ids}
    u0, u1 = uklad(start, sr0), uklad(kon, sr1)
    # zachowanie układu: średnie przesunięcie offsetów względnych start→koniec
    zm = sum(_dl(_wektor(u0[i], u1[i])) for i in ids) / n
    roz0 = [min(_dl(_wektor(start[a], start[b])) for b in ids if b != a) for a in ids] if n > 1 else []
    roz1 = [min(_dl(_wektor(kon[a], kon[b])) for b in ids if b != a) for a in ids] if n > 1 else []
    ts = [per[i]["t_start"] for i in ids if per[i]["t_start"] is not None]
    tk = [per[i]["t_koniec"] for i in ids if per[i]["t_koniec"] is not None]
    vm = [per[i]["v_mediana"] for i in ids if per[i]["v_mediana"] > 0]
    out = {"n": n, "srodek_start": [round(x, 3) for x in sr0], "srodek_koniec": [round(x, 3) for x in sr1],
           "przesuniecie_srodka": round(dk, 3),
           "start_t": [min(ts), max(ts)] if ts else None, "koniec_t": [min(tk), max(tk)] if tk else None,
           "v_mediana": [min(vm), max(vm)] if vm else None,
           "min_odleglosc_par": round(dmin, 3) if n > 1 else None, "t_min_odleglosci": t_dmin,
           "rozstaw_start_min_sr": [round(min(roz0), 3), round(sum(roz0) / n, 3)] if roz0 else None,
           "rozstaw_koniec_min_sr": [round(min(roz1), 3), round(sum(roz1) / n, 3)] if roz1 else None,
           "zmiana_ukladu_wzgl_sr": round(zm, 3),
           "uklad_koncowy_wzdluz_w_poprzek": {i: [round(a, 2), round(b, 2)] for i, (a, b) in u1.items()},
           "uklad_poczatkowy_wzdluz_w_poprzek": {i: [round(a, 2), round(b, 2)] for i, (a, b) in u0.items()},
           "jednostki": per}
    if cel:
        out["cel"] = cel
        out["srodek_koniec_od_celu"] = round(_dl(_wektor(cel, sr1)), 3)
        out["max_od_celu"] = round(max(_dl(_wektor(cel, kon[i])) for i in ids), 3)
    return out


def main():
    pliki = [a for a in sys.argv[1:] if not a.startswith("--")]
    op = dict(a[2:].split("=", 1) if "=" in a else (a[2:], "1") for a in sys.argv[1:] if a.startswith("--"))
    cel = [float(x) for x in op["cel"].split(",")] if "cel" in op else None
    w = {p: analiza(json.load(open(p)), cel) for p in pliki}
    print(json.dumps(w, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
