#!/usr/bin/env python3
"""Eksperyment Fable 2: warunek geometryczny gałęzi dużych jednostek (EE 0x548A3C / AoC 0x555247) liczony z nagrania.

Użycie:  fable_duze_bramka.py <nagranie.json> <u> <o> [--wszystko]
Dla każdej próbki z parą (u, o) na liście kontaktów u liczy wielkości odczytane statycznie z początku 0x548A3C [W]:
  * proste kursów: P_u + s·(kurs_u·rozmiar_u), P_o + t·(kurs_o·rozmiar_o); s, t = parametry przecięcia,
  * kąt między kursami złożony do [0, 90°],
  * przypadek „w linii”: kąt ≤ 5°, odległość boczna o od osi u ≤ 0,5 i odległość wzdłuż osi ≤ (ru + ro)/2,
  * przypadek „przecięcie”: |s| < 0,75 i |t| < 0,75.
Wypisuje pierwszą i ostatnią próbkę każdego spójnego przedziału, w którym warunek jest spełniony, oraz – dla porównania –
próbki, w których zmierzono reakcję (niezerowy push o, przyrost k248 u albo o). Rozmiary: R_TYPU (dbobjects).
To narzędzie diagnostyczne: zgodność przedziałów z reakcją jest testem odczytu [W], a nie implementacją gałęzi.
"""
import json, math, sys

R_TYPU = {102: 1.0, 422: 0.5, 37: 1.0, 128: 1.5, 158: 1.1}


def kurs(s):
    n = math.hypot(s["m01"], s["m11"]) or 1.0
    return s["m01"] / n, s["m11"] / n


def bramka(a, b):
    ra, rb = R_TYPU[a["typ"]], R_TYPU[b["typ"]]
    ha, hb = kurs(a), kurs(b)
    dx, dy = b["x"] - a["x"], b["y"] - a["y"]
    kat = math.degrees(math.acos(max(-1.0, min(1.0, ha[0] * hb[0] + ha[1] * hb[1]))))
    if kat > 90: kat = 180 - kat
    va = (ha[0] * ra, ha[1] * ra); vb = (hb[0] * rb, hb[1] * rb)
    cr = va[0] * vb[1] - va[1] * vb[0]
    s = t = None
    if abs(cr) > 1e-9:
        s = (dx * vb[1] - dy * vb[0]) / cr
        t = (dx * va[1] - dy * va[0]) / cr
    wzdluz = dx * ha[0] + dy * ha[1]; bok = abs(-dx * ha[1] + dy * ha[0])
    linia = kat <= 5.0 and bok <= 0.5 and 0 < wzdluz <= (ra + rb) / 2
    przec = s is not None and abs(s) < 0.75 and abs(t) < 0.75
    return linia, przec, s, t, kat, wzdluz, bok


def main():
    d = json.load(open(sys.argv[1])); P = d["probki"]
    U, O = [a if a.startswith("0x") else "0x1000" + a for a in sys.argv[2:4]]
    wsz = "--wszystko" in sys.argv
    print("nagranie", sys.argv[1].split("/")[-1], "wariant", d.get("wariant"), "para", U, "→", O)
    stan = None; pop = None; n_war = n_reak = 0
    for p in P:
        a, b = p[U], p[O]
        if O not in (a.get("kontakty_lista") or []):
            if stan: print("   … do t=%d (koniec kontaktu)" % pop["t"]); stan = None
            pop = p; continue
        li, pr, s, t, kat, wz, bok = bramka(a, b)
        war = "linia" if li else ("przecięcie" if pr else None)
        reak = any(abs(v) > 0 for v in b["push"]) or (pop is not None and (a["k248"] > pop[U]["k248"] or b["k248"] > pop[O]["k248"]))
        n_war += bool(war); n_reak += bool(reak)
        if war != stan or wsz:
            if stan and not wsz: print("   … do t=%d" % pop["t"])
            if war or wsz:
                print("  t=%d warunek %s: d %.3f s %s t %s kąt %.1f wzdłuż %.3f bok %.3f | v_u %.3f v_o %.3f push_o %s" % (
                    p["t"], war, math.hypot(a["x"] - b["x"], a["y"] - b["y"]),
                    None if s is None else round(s, 3), None if t is None else round(t, 3), kat, wz, bok, a["v"], b["v"],
                    [round(v, 4) for v in b["push"]]))
            stan = war
        if reak and not wsz:
            print("  t=%d REAKCJA: warunek %s s %s t %s kąt %.1f push_o %s k248 u %.0f o %.0f" % (
                p["t"], war, None if s is None else round(s, 3), None if t is None else round(t, 3), kat,
                [round(v, 4) for v in b["push"]], a["k248"], b["k248"]))
        pop = p
    print("  próbek z warunkiem: %d, z reakcją: %d" % (n_war, n_reak))


if __name__ == "__main__":
    main()
