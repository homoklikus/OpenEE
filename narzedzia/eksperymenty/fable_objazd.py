#!/usr/bin/env python3
"""Eksperyment Fable 2: oś czasu objazdu przeszkody w nagraniu pełnego rejestratora (walka_rejestruj_*).

Użycie:  fable_objazd.py <nagranie.json> <id> [<id> ...] [--pelne]   (--pelne: także cykl stanów 10003/9000/2015)
Dla każdej wskazanej jednostki wypisuje (czas gry t w ms):
  * próbkę przyjęcia rozkazu i pierwszą trasę (punkty A*),
  * każdą aktualizację trasy, która nie jest zwykłym zdjęciem zaliczonego punktu,
  * pierwsze odchylenie boczne od prostej start→cel (> 0,02 pola) oraz stan/v/ω/push/kontakty w tej próbce,
  * pierwszy kontakt, pierwszy niezerowy push, pierwszą próbkę z ≥ 2 kontaktami (kolejność listy od głowy),
  * zmiany trybu, k330 i zerowania prędkości w ruchu, minimum odległości do pozostałych jednostek, pozycję końcową.
Skrypt tylko czyta nagranie; niczego nie zapisuje.
"""
import json, math, sys


def sufiks(nowa, stara):
    return len(nowa) <= len(stara) and stara[len(stara) - len(nowa):] == nowa


def main():
    arg = [a for a in sys.argv[1:] if not a.startswith("--")]
    pelne = "--pelne" in sys.argv
    d = json.load(open(arg[0])); P = d["probki"]; J = d["jednostki"]
    print("nagranie", arg[0].split("/")[-1], "| wariant", d.get("wariant"), "| próbek", len(P),
          "| t", P[0]["t"], "…", P[-1]["t"], "| luki", d.get("luki_taktow"))
    for u in arg[1:]:
        U = u if u.startswith("0x") else "0x1000" + u
        p0 = P[0][U]; x0, y0 = p0["x"], p0["y"]
        print("== %s typ %s start (%.3f,%.3f)" % (U, p0["typ"], x0, y0))
        trasa = None; cel = None; zd = {}
        mind = {}
        pop = None
        for i, p in enumerate(P):
            s = p[U]; t = p["t"]
            tr = [[round(a, 3) for a in q[:2]] for q in (s.get("trasa") or [])]
            for o in J:
                if o == U: continue
                q = p[o]; dd = math.hypot(s["x"] - q["x"], s["y"] - q["y"])
                if o not in mind or dd < mind[o][0]: mind[o] = (dd, t)
            if trasa is None:
                if tr:
                    trasa = tr; cel = tr[-1]
                    print("  t=%d rozkaz przyjęty: stan %s tryb %s trasa %s" % (t, s["stan"], s["tryb"], tr))
            elif tr != trasa:
                if tr and not sufiks(tr, trasa):
                    print("  t=%d AKTUALIZACJA TRASY: poz (%.3f,%.3f) v %.3f kontakty %s nowa %s" % (
                        t, s["x"], s["y"], s["v"], [k[-3:] for k in s.get("kontakty_lista") or []], tr))
                trasa = tr
            if cel and "odch" not in zd:
                dx, dy = cel[0] - x0, cel[1] - y0; L = math.hypot(dx, dy) or 1
                e = abs((s["x"] - x0) * dy - (s["y"] - y0) * dx) / L
                if e > 0.02:
                    zd["odch"] = 1
                    print("  t=%d pierwsze odchylenie boczne %.3f: poz (%.3f,%.3f) stan %s v %.3f w %.3f push %s kontakty %s punkt %s" % (
                        t, e, s["x"], s["y"], s["stan"], s["v"], s["w"], [round(a, 4) for a in s["push"]],
                        [k[-3:] for k in s.get("kontakty_lista") or []], s.get("punkt")))
            kl = s.get("kontakty_lista") or []
            if kl and "k1" not in zd:
                zd["k1"] = 1
                print("  t=%d pierwszy kontakt %s: poz (%.3f,%.3f) v %.3f" % (t, [k[-3:] for k in kl], s["x"], s["y"], s["v"]))
            if len(kl) >= 2 and "k2" not in zd:
                zd["k2"] = 1
                print("  t=%d pierwsza próbka z >=2 kontaktami (od głowy listy): %s poz (%.3f,%.3f)" % (t, [k[-3:] for k in kl], s["x"], s["y"]))
            if any(abs(a) > 0 for a in s["push"]) and "p1" not in zd:
                zd["p1"] = 1
                print("  t=%d pierwszy push %s: poz (%.3f,%.3f) v %.3f kontakty %s" % (
                    t, [round(a, 5) for a in s["push"]], s["x"], s["y"], s["v"], [k[-3:] for k in kl]))
            if pop is not None:
                for pole in ("tryb", "k330", "stan"):
                    if s[pole] != pop[pole] and (pelne or pole != "stan" or s[pole] not in (10003, 9000, 2015)):
                        print("  t=%d %s %s→%s poz (%.3f,%.3f) v %.3f k248 %.1f kontakty %s" % (
                            t, pole, pop[pole], s[pole], s["x"], s["y"], s["v"], s["k248"], [k[-3:] for k in kl]))
                if pop["v"] > 0.05 and s["v"] == 0.0 and trasa:
                    print("  t=%d prędkość wyzerowana w ruchu: poz (%.3f,%.3f) kontakty %s push %s" % (
                        t, s["x"], s["y"], [k[-3:] for k in kl], [round(a, 4) for a in s["push"]]))
            pop = s
        e = P[-1][U]
        print("  koniec (%.3f,%.3f) stan %s | cel trasy %s | min. odległości: %s" % (
            e["x"], e["y"], e["stan"], cel, {o[-3:]: (round(v[0], 3), v[1]) for o, v in mind.items()}))


if __name__ == "__main__":
    main()
