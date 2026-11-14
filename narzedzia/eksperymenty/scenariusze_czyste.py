#!/usr/bin/env python3
"""Etap 42: generator wariantów czystej mapy testowej EE z opisu danymi (dane/testy_walki/e42_warianty.json).

Kroki: (1) baza – kopia scenariusza kampanii 231 oczyszczona `scenariusz_czysty.py` (jednostki graczy, obiekty Świata
w prostokącie, pusty kawałek 6); (2) każdy wariant – `scenariusz_testowy_kolizji.py zbuduj` z grupami opisanymi jako
[wzór, gracz, pozycje]. Bez ręcznych zmian w edytorze. Pliki wynikowe (dane gry) zostają lokalnie w katalogu map.

Użycie: python3 narzedzia/eksperymenty/scenariusze_czyste.py <katalog_map> [wariant ...]
"""
import json
import subprocess
import sys
from pathlib import Path

TU = Path(__file__).resolve().parent
OPIS = TU.parents[1] / "dane" / "testy_walki" / "e42_warianty.json"


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    mapy = Path(sys.argv[1]).resolve()
    opis = json.loads(OPIS.read_text(encoding="utf-8"))
    baza = mapy / "e42_czysta_troja.scn"
    konf = mapy / "e42_czysta_troja.czyszczenie.json"
    konf.write_text(json.dumps(opis["baza"]["czyszczenie"]), encoding="utf-8")
    subprocess.run([sys.executable, str(TU / "scenariusz_czysty.py"), str(mapy / opis["baza"]["zrodlo"]), str(baza), str(konf)], check=True)
    # etap 46: druga baza „bez_zwierzat” – ta sama oczyszczona mapa bez ruchomych obiektów Świata (zwierzęta, ryby), które
    # losują z generatora RTSPhysics poza nagrywanymi jednostkami [P: lista fizyki 644 – 22 obiekty = 3 testowe + 19]
    bazy = {"": baza}
    if "baza_bez_zwierzat" in opis:
        b2 = mapy / "e46_czysta_troja_bez_zwierzat.scn"
        k2 = mapy / "e46_czysta_troja_bez_zwierzat.czyszczenie.json"
        k2.write_text(json.dumps({**opis["baza"]["czyszczenie"], **opis["baza_bez_zwierzat"]["czyszczenie"]}), encoding="utf-8")
        subprocess.run([sys.executable, str(TU / "scenariusz_czysty.py"), str(mapy / opis["baza"]["zrodlo"]), str(b2), str(k2)], check=True)
        bazy["bez_zwierzat"] = b2
    wybrane = sys.argv[2:] or list(opis["warianty"])
    for nazwa in wybrane:
        grupy = {}
        baza_w = bazy[opis.get("bazy_wariantow", {}).get(nazwa, "")]
        for g, (wzor, gracz, poz, *reszta) in opis["warianty"][nazwa].items():
            grupy[g] = {"wzor": opis["wzory"][wzor], "zrodlo": str(mapy / opis["zrodlo_wzorow"]), "gracz": gracz,
                        "pozycje": poz}
            # etap 54: tryb wysokości wariantu; "*" = domyślny. Warianty sprzed etapu 54 mają "wzor" (z skopiowane ze
            # wzoru – tak powstały mapy wszystkich wcześniejszych nagrań), nowe – "teren" (obiekt stoi na terenie).
            ztw = opis.get("z_tryb_wariantow", {})
            zt = ztw.get(nazwa, ztw.get("*"))
            if zt:
                grupy[g]["z_tryb"] = zt
            if reszta:   # etap 47: nadpisanie pól rekordu (np. {"u3c": 0,3} – część HP)
                pola = dict(reszta[0])
                if "_z_tryb" in pola:                # etap 54: tryb wysokości jednej grupy
                    grupy[g]["z_tryb"] = pola.pop("_z_tryb")
                if pola:
                    grupy[g]["pola"] = pola
        wej = mapy / f"e42_{nazwa}.uklad_wej.json"
        dod = opis.get("surowce_wariantow", {}).get(nazwa)   # etap 51: surowce startowe graczy
        wej.write_text(json.dumps({"grupy": grupy, **({"surowce": dod, "surowce_obecne": opis.get("surowce_bazy")}
                                                      if dod else {})}, indent=1), encoding="utf-8")
        subprocess.run([sys.executable, str(TU / "scenariusz_testowy_kolizji.py"), "zbuduj", str(baza_w),
                        str(mapy / f"e42_{nazwa}.scn"), str(wej)], check=True)


if __name__ == "__main__":
    main()
