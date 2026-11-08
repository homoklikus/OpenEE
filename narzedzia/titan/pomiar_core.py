#!/usr/bin/env python3
"""Pomiar oryginału (Riverlands_MCP obs_rejestruj / walka_rejestruj) → walidacja → seria Core → porównanie → raport.

Narzędzie OpenEE (etap 30). Zastępuje jednorazowe skrypty konwersji z etapu 29. Kroki:
  1. walidacja formatu i kompletności (brak próbki, duplikat taktu, błędny id, niespójny odczyt, zmiana wariantu,
     brak pola, nieznany parametr) – błąd = koniec z kodem 1 i opisem; NIC nie jest dopasowywane po cichu;
  2. konwersja do formatu openee_seria_v1 (start, rozkazy: trasa z gry z pełnej kolejki albo cel do A* w Core);
  3. uruchomienie cpp/tools/openee_porownaj (Core) i odczyt metryk;
  4. raport: pierwszy rozbieżny takt na jednostkę, metryki, RNG; JSON + Markdown w katalogu --wyniki (lokalnie).

Użycie:
  pomiar_core.py waliduj POMIAR.json [--wariant ee|aoc]
  pomiar_core.py konwertuj POMIAR.json -o SERIA.json [--wariant ee] [--parametry P.json] [--tryb trasa|astar]
  pomiar_core.py porownaj POMIAR.json --instalacja KATALOG_GRY [--mapa MAPA.json] [--wyniki KATALOG] [--bin openee_porownaj]
Dane pomiarowe są prywatne (lokalne) – narzędzie nie zapisuje nic w repozytorium.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

TAKT_MS = 1500.0 / 44.0
# Parametry ruchu (EEUnitClassUpgrade +0xA8…, typ +0x474/+0x488) – ruch_jednostki.md § 3, odczyty EE 508 [P].
PARAMETRY = {
    "422": {"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264, "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5},
    "173": {"a": 2.0, "vmax": 0.8, "alfa": 6.98132, "wmax": 6.98132, "rozmiar": 0.55, "c4": 0.5, "c8": 0.14324, "t488": 0.5},
}
KLUCZE_PARAMETROW = {"a", "vmax", "alfa", "wmax", "rozmiar", "c4", "c8", "t488"}
POLA_PROBKI = ("x", "y", "v", "stan", "kontakty", "k248", "m01", "m11", "typ")


class BladPomiaru(Exception):
    pass


def waliduj(d: dict, wariant: str | None = None, dopusc_luki: bool = False) -> dict:
    bl, ostr = [], []
    for k in ("wariant", "jednostki", "probki"):
        if k not in d:
            raise BladPomiaru(f"brak klucza '{k}' – to nie jest zapis obs_rejestruj")
    if wariant and d["wariant"] != wariant:
        bl.append(f"zmiana wariantu: plik {d['wariant']}, oczekiwano {wariant}")
    ids = d["jednostki"]
    for i in ids:
        if not (isinstance(i, str) and i.startswith("0x") and len(i) >= 9):
            bl.append(f"błędny identyfikator jednostki {i!r}")
    if d.get("pominiete_niespojne"):
        ostr.append(f"{d['pominiete_niespojne']} odczytów niespójnych odrzuconych przez rejestrator (takt w trakcie odczytu)")
    pr = d["probki"]
    if len(pr) < 2:
        bl.append("mniej niż 2 próbki")
    widziane = {}
    luki = []
    for n, p in enumerate(pr):
        t = p.get("t")
        if t in widziane:
            bl.append(f"duplikat taktu t={t} (próbki {widziane[t]} i {n})")
        widziane[t] = n
        if n:
            dt = t - pr[n - 1]["t"]
            if dt <= 0:
                bl.append(f"czas nie rośnie w próbce {n}")
            elif round(dt / TAKT_MS) > 1:
                luki.append((n, round(dt / TAKT_MS) - 1))
        for i in ids:
            j = p.get(i)
            if j is None:
                bl.append(f"brak jednostki {i} w próbce {n} (t={t})")
                continue
            brak = [k for k in POLA_PROBKI if k not in j]
            if brak:
                bl.append(f"brak pól {brak} jednostki {i} w próbce {n}")
    if luki:
        (ostr if dopusc_luki else bl).append(f"brakujące próbki: {len(luki)} luk, {sum(x[1] for x in luki)} taktów (pierwsza w próbce {luki[0][0]})")
    typy = {}
    for i in ids:
        ts = {p[i]["typ"] for p in pr if p.get(i) and "typ" in p[i]}
        if len(ts) > 1:
            bl.append(f"jednostka {i} zmienia typ: {ts}")
        typy[i] = next(iter(ts)) if ts else None
    return {"ok": not bl, "bledy": bl[:50], "liczba_bledow": len(bl), "ostrzezenia": ostr, "probek": len(pr),
            "jednostki": ids, "typy": typy, "pelna_kolejka": all("kolejka" in pr[0].get(i, {}) for i in ids)}


def _takt(t, t0):
    return int(round((t - t0) / TAKT_MS))
# Uwaga: takt w serii = indeks próbki (walidacja wyklucza luki); czas gry t bywa zaokrąglany do 34/35 ms, więc
# przeliczanie t → takt dawało przesunięcie o 1 takt (zadanie 554, etap 30).


def konwertuj(d: dict, nazwa: str, parametry: dict | None = None, tryb: str | None = None) -> dict:
    w = waliduj(d)
    if not w["ok"]:
        raise BladPomiaru("walidacja: " + "; ".join(w["bledy"][:5]))
    par = dict(PARAMETRY)
    for typ, p in (parametry or {}).items():
        nieznane = set(p) - KLUCZE_PARAMETROW
        if nieznane:
            raise BladPomiaru(f"nieznany parametr {sorted(nieznane)} dla typu {typ}")
        par[str(typ)] = p
    pr = d["probki"]
    t0 = pr[0]["t"]
    tryb = tryb or ("trasa" if w["pelna_kolejka"] else "astar")
    jedn, uzyte = [], {}
    for i in d["jednostki"]:
        typ = str(w["typy"][i])
        if typ not in par:
            raise BladPomiaru(f"nieznany typ {typ} jednostki {i} – brak parametrów ruchu (podaj --parametry)")
        uzyte[typ] = par[typ]
        p0 = pr[0][i]
        probki = []
        for p in pr:
            j = p[i]
            probki.append({"takt": len(probki), "t": p["t"], "x": j["x"], "y": j["y"], "v": j["v"], "stan": j["stan"],
                           "kontakty": j["kontakty"], "k248": j["k248"]})
        rozkazy = []
        ost_cel = None
        for n, p in enumerate(pr):
            j = p[i]
            if tryb == "trasa":
                k = j.get("kolejka") or {}
                cele = [c for poz in k.get("poziomy", []) for c in poz.get("cele", []) if not c.get("punkt_trasy")]
                rozk = cele[0].get("numer") if cele else None
                if rozk and rozk != ost_cel and j.get("trasa"):
                    rozkazy.append({"takt": n, "tryb": "trasa", "punkty": [q[:2] for q in j["trasa"]],
                                    "zrodlo": f"pełna trasa z pamięci, cel nr {rozk}"})
                    ost_cel = rozk
            else:
                if j["trasa_n"] and (n == 0 or not pr[n - 1][i]["trasa_n"]) and j.get("punkt_ost"):
                    rozkazy.append({"takt": n, "tryb": "rozkaz", "x": j["punkt_ost"][0], "y": j["punkt_ost"][1],
                                    "zrodlo": "cel = ostatni punkt trasy z pamięci; trasa z A* w Core"})
        jedn.append({"id": i, "typ": typ, "start": {"x": p0["x"], "y": p0["y"], "m01": p0["m01"], "m11": p0["m11"]},
                     "rozkazy": rozkazy, "probki": probki})
    return {"format": "openee_seria_v1", "nazwa": nazwa, "wariant": d["wariant"], "tryb_rozkazow": tryb,
            "parametry": uzyte, "jednostki": jedn, "rng": [p["rng"] for p in pr], "walidacja": w}


def raport_md(r: dict, w: dict) -> str:
    l = [f"# Porównanie Core ↔ oryginał: {r['nazwa']}", "", f"Wariant {r['wariant']}, teren: {r['teren']}, taktów {r['taktow']}, "
         f"tolerancja pozycji {r['tolerancja']}.", "", "| Jednostka | Próbek | Pozycja śr / max | Pierwszy rozbieżny takt | Inny stan | Inne kontakty |",
         "|---|---|---|---|---|---|"]
    for j in r["jednostki"]:
        l.append(f"| {j['id']} | {j['probek']} | {j['pozycja_sr']:.4f} / {j['pozycja_max']:.4f} | "
                 f"{j['pierwszy_rozbiezny'] if j['pierwszy_rozbiezny'] >= 0 else 'brak'} | {j['takty_inny_stan']} | {j['takty_inne_kontakty']} |")
    l += [""] + [f"- {j['id']}, takt {j['pierwszy_rozbiezny']}: {j['opis_rozbieznosci']}" for j in r["jednostki"] if j["pierwszy_rozbiezny"] >= 0]
    l += ["", f"RNG: gra {r['rng_kroki_gra']} kroków LCG, Core {r['rng_losowania_core']} losowań (Core nie ma AI i walki).",
          "", "Ostrzeżenia walidacji: " + ("; ".join(w["ostrzezenia"]) or "brak")]
    return "\n".join(l) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("polecenie", choices=("waliduj", "konwertuj", "porownaj"))
    ap.add_argument("pomiar")
    ap.add_argument("-o", "--wyjscie")
    ap.add_argument("--wariant")
    ap.add_argument("--parametry")
    ap.add_argument("--tryb", choices=("trasa", "astar"))
    ap.add_argument("--instalacja")
    ap.add_argument("--mapa")
    ap.add_argument("--wyniki")
    ap.add_argument("--dopusc-luki", action="store_true")
    ap.add_argument("--jednostki", help="lista id (przecinki) – porównanie tylko tych jednostek (pozostałe pominięte jawnie)")
    ap.add_argument("--bin", default=str(Path(__file__).resolve().parents[2] / "build" / "cpp" / "tools" / "openee_porownaj"))
    a = ap.parse_args(argv)
    try:
        d = json.loads(Path(a.pomiar).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print(json.dumps({"ok": False, "blad": f"nie można odczytać pomiaru: {exc}"}, ensure_ascii=False))
        return 1
    if a.jednostki:
        wyb = [x.strip().lower() for x in a.jednostki.split(",") if x.strip()]
        brak = [x for x in wyb if x not in d.get("jednostki", [])]
        if brak:
            print(json.dumps({"ok": False, "blad": f"błędny identyfikator jednostki: {brak} – nie ma w pomiarze"}, ensure_ascii=False))
            return 1
        d["jednostki"] = wyb
    try:
        if a.polecenie == "waliduj":
            w = waliduj(d, a.wariant, a.dopusc_luki)
            print(json.dumps(w, ensure_ascii=False, indent=1))
            return 0 if w["ok"] else 1
        par = json.loads(Path(a.parametry).read_text()) if a.parametry else None
        if a.wariant and d.get("wariant") != a.wariant:
            raise BladPomiaru(f"zmiana wariantu: plik {d.get('wariant')}, oczekiwano {a.wariant}")
        s = konwertuj(d, Path(a.pomiar).stem, par, a.tryb)
        if a.polecenie == "konwertuj":
            Path(a.wyjscie).write_text(json.dumps(s))
            print(json.dumps({"ok": True, "plik": a.wyjscie, "tryb": s["tryb_rozkazow"],
                              "rozkazy": {j["id"]: len(j["rozkazy"]) for j in s["jednostki"]}}, ensure_ascii=False))
            return 0
        if not a.instalacja:
            raise BladPomiaru("porownaj wymaga --instalacja (tablice z Low-Level Engine.dll)")
        wyn = Path(a.wyniki or Path(a.pomiar).parent / "porownania_core")
        wyn.mkdir(parents=True, exist_ok=True)
        sp = wyn / f"{Path(a.pomiar).stem}.seria.json"
        sp.write_text(json.dumps(s))
        cmd = [a.bin, "--seria", str(sp), "--instalacja", a.instalacja] + (["--mapa", a.mapa] if a.mapa else [])
        p = subprocess.run(cmd, capture_output=True, text=True)
        if p.returncode:
            raise BladPomiaru(f"openee_porownaj: kod {p.returncode}: {p.stderr.strip()}")
        r = json.loads(p.stdout)
        (wyn / f"{Path(a.pomiar).stem}.raport.json").write_text(json.dumps({"porownanie": r, "walidacja": s["walidacja"]}, ensure_ascii=False, indent=1))
        (wyn / f"{Path(a.pomiar).stem}.raport.md").write_text(raport_md(r, s["walidacja"]))
        print(json.dumps({"ok": True, "raport": str(wyn / f"{Path(a.pomiar).stem}.raport.md"), **r}, ensure_ascii=False))
        return 0
    except BladPomiaru as exc:
        print(json.dumps({"ok": False, "blad": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
