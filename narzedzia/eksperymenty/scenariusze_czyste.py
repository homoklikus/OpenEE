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
    wybrane = sys.argv[2:] or list(opis["warianty"])
    for nazwa in wybrane:
        grupy = {}
        for g, (wzor, gracz, poz) in opis["warianty"][nazwa].items():
            grupy[g] = {"wzor": opis["wzory"][wzor], "zrodlo": str(mapy / opis["zrodlo_wzorow"]), "gracz": gracz,
                        "pozycje": poz}
        wej = mapy / f"e42_{nazwa}.uklad_wej.json"
        wej.write_text(json.dumps({"grupy": grupy}, indent=1), encoding="utf-8")
        subprocess.run([sys.executable, str(TU / "scenariusz_testowy_kolizji.py"), "zbuduj", str(baza),
                        str(mapy / f"e42_{nazwa}.scn"), str(wej)], check=True)


if __name__ == "__main__":
    main()
