#!/usr/bin/env python3
"""Etap 42: kontrolowane czyszczenie scenariusza EE 1.x (SCN 231) – baza czystej mapy testowej (wariant B).

Dlaczego 231, a nie 250: Empire Earth.exe odrzuca scenariusze SCN 250 (AoC) komunikatem „Plik z zapisaną grą jest
nieprawidłowy” [P] (zadania 197–199 etapu 12; zrzut okno_20261106_203425). Mapy Riverlands (250) nadają się tylko do
AoC, więc czysta mapa EE powstaje z KOPII scenariusza kampanii 231 (plik oryginalny nie jest zmieniany).

Operacje (wszystkie opisane danymi w pliku konfiguracji JSON):
  * kawałek 5 – usunięcie WSZYSTKICH rekordów jednostek graczy z listy "usun_graczy" (kubełki → 128 × 0, liczba
    jednostek 0; licznik następnej instancji bez zmian, więc nowe id nie kolidują z historią scenariusza);
  * kawałek 5 – usunięcie obiektów Świata (gracz 0) w prostokącie "swiat_usun" [x0, y0, x1, y1] (pola X, Y);
  * kawałek 6 (wyzwalacze, opis i cele scenariusza) – zastąpienie pustym stanem: lista wyzwalaczy 0 i puste opisy;
    układ pustego kawałka (115 B) jak w rodzimym scenariuszu bez wyzwalaczy (generator Riverlands); końcówka
    kawałka 6 (opis, cele, plik .lcl, 01 00 00 00 00) ma ten sam układ w 231 i 250 [P] porównanie plików kampanii.
Kontrola: ponowny odczyt całego kawałka 5 gramatyką, kontrola ramek pliku i kompresji (jak scenariusz_testowy_kolizji).

Użycie:
  python3 narzedzia/eksperymenty/scenariusz_czysty.py <wejście_231.scn> <wyjście.scn> <konfiguracja.json>
konfiguracja: {"usun_graczy": [1, 2, ...], "swiat_usun": [x0, y0, x1, y1] | null, "kawalek6_pusty": true}
Wynik zostaje lokalnie (dane scenariusza z gry nie są publikowane).
"""
import importlib.util
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import scenariusz_testowy_kolizji as T     # noqa: E402
from eeformaty import gracze as G          # noqa: E402
from eeformaty import scn as S             # noqa: E402
from eeformaty.dcl import maybe_unpack     # noqa: E402

# Pusty kawałek 6 (115 B) – rodzimy stan „bez wyzwalaczy” (Riverlands 0.8.1, e40_czysta_baza.scn).
KAWALEK6_PUSTY = bytes(56) + bytes.fromhex("0100000000" * 7 + "00" * 14 + "0100000000" * 2)


def _ramka(blob, k, dane, rl):
    spak = rl.pack_pk01(dane)
    if maybe_unpack(spak) != dane:
        raise SystemExit(f"kontrola kompresji kawałka {k['tag']}")
    q = k["offset"]
    return blob[:q] + struct.pack("<IIiI", k["major"], k["minor"], k["tag"], len(spak)) + spak + \
        blob[q + 16 + k["rozmiar"]:]


def wyczysc(wej, wyj, konf, riverlands):
    blob = Path(wej).read_bytes()
    k5 = T._kawalek(blob, 5)
    wersja = k5["minor"]
    if wersja != 231:
        raise SystemExit(f"oczekiwano SCN 231 (EE), jest {wersja}")
    d5 = bytearray(maybe_unpack(k5["surowe"]))
    n_graczy = len(G.czytaj(bytes(d5), wersja))
    usun = sorted({int(n) for n in konf.get("usun_graczy", [])})
    swiat = konf.get("swiat_usun")
    plan = []
    for nr in range(n_graczy):
        if nr in usun or (nr == 0 and swiat):
            plan.append((nr, T._gracz_z_offsetami(bytes(d5), T._start_gracza(bytes(d5), nr, wersja), wersja)))
    raport = {}
    for nr, g in sorted(plan, key=lambda p: -p[1]["kubelki"][0]["offset"]):   # od końca – offsety stałe
        a, b = g["kubelki"][0]["offset"], g["kubelki"][-1]["koniec"]
        nowe, usuniete = bytearray(), 0
        for kb in g["kubelki"]:
            zost = []
            for (ra, rb, off, u) in kb["rekordy"]:
                if nr in usun:
                    usuniete += 1
                    continue
                x0, y0, x1, y1 = swiat
                if x0 <= u.get("X", -1) <= x1 and y0 <= u.get("Y", -1) <= y1:
                    usuniete += 1
                    continue
                zost.append(bytes(d5[ra:rb]))
            nowe += struct.pack("<I", len(zost)) + b"".join(zost)
        d5[a:b] = nowe
        struct.pack_into("<I", d5, g["off_liczba"], g["liczba"] - usuniete)
        raport[nr] = {"bylo": g["liczba"], "usunieto": usuniete}
    gr = G.czytaj(bytes(d5), wersja)                     # kontrola odczytu całego kawałka 5
    for nr, r in raport.items():
        if len(gr[nr]["jednostki"]) != r["bylo"] - r["usunieto"]:
            raise SystemExit(f"kontrola: gracz {nr} ma {len(gr[nr]['jednostki'])} jednostek")
    spec = importlib.util.spec_from_file_location("riverlands_bib", riverlands)
    rl = importlib.util.module_from_spec(spec); spec.loader.exec_module(rl)
    nowy = _ramka(blob, k5, bytes(d5), rl)
    if konf.get("kawalek6_pusty", True):
        nowy = _ramka(nowy, T._kawalek(nowy, 6), KAWALEK6_PUSTY, rl)
    nowy = struct.pack("<I", len(nowy) - 4) + nowy[4:]
    S.kawalki(nowy)                                       # kontrola ramek do końca pliku
    Path(wyj).write_bytes(nowy)
    print(json.dumps({"plik": str(wyj), "gracze": raport, "kawalek6_pusty": bool(konf.get("kawalek6_pusty", True))}))


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    opcje = dict(x[2:].split("=", 1) for x in sys.argv[1:] if x.startswith("--") and "=" in x)
    if len(a) != 3:
        raise SystemExit(__doc__)
    konf = json.loads(Path(a[2]).read_text(encoding="utf-8"))
    wyczysc(a[0], a[1], konf, opcje.get("riverlands", str(Path(__file__).resolve().parents[3] / "Riverlands" / "Riverlands_0_8_1.py")))


if __name__ == "__main__":
    main()
