#!/usr/bin/env python3
"""Scenariusz testowy kolizji i prędkości (etap 13) w formacie Empire Earth 1.0 (SCN 231) – działa w EE i w AoC.

Podstawa: KOPIA scenariusza kampanii EE (np. „Wojna trojańska”, wersja 231) – plik oryginalny nie jest zmieniany.
Do gracza 1 dopisywane są kopie rekordu wskazanej jednostki (np. obywatela) w zadanych polach dużego, płaskiego
i pustego obszaru. Rekord jednostki jest kopiowany bajt w bajt; zmieniane są wyłącznie: identyfikator (instancja),
pole (X, Y), pozycja (x, y) i translacja macierzy. Liczniki gracza (liczba jednostek, następna instancja,
licznik kubełka instancja mod 128) są aktualizowane. Kawałek 5 jest pakowany DCL implode (biblioteka generatora
Riverlands – import bez zmian w jego plikach; jak narzedzia/eksperymenty/scenariusz_testowy_ruchu.py).

Użycie:
  python3 narzedzia/eksperymenty/scenariusz_testowy_kolizji.py zbadaj <wejście.scn>
  python3 narzedzia/eksperymenty/scenariusz_testowy_kolizji.py zbuduj <wejście.scn> <wyjście.scn> <uklad.json> [--riverlands=<.py>]
uklad.json: {"grupy": {"A": {"wzor": "0x100011a", "gracz": <numer gracza, domyślnie 1 – etap 30>,
             "zrodlo": <opcjonalnie inny plik .scn tej wersji>,
             "z": <opcjonalna wysokość>, "pozycje": [[x, y], ...]}, ...}} – pozycje mapy (x = kolumna, y = wiersz).
Wynik: plik .scn i <wyjście>.uklad.json z identyfikatorami jednostek każdej grupy. Pliki wynikowe zostają lokalnie
(dane scenariusza z gry nie są publikowane).
"""
import importlib.util
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # narzedzia/ – eeformaty
from eeformaty import gracze as G          # noqa: E402
from eeformaty import scn as S             # noqa: E402
from eeformaty.dcl import maybe_unpack     # noqa: E402


class _RO(G._R):
    """Czytnik z zapisem położenia pól."""


def _jednostka_z_offsetami(d, o, wersja):
    """Rekord jednostki: (początek, koniec, {pole: offset}) – ta sama gramatyka co gracze.czytaj_jednostke."""
    r = _RO(d, o)
    off, u = {}, {}
    for el in G.GRAMATYKA_JEDNOSTKI:
        k = el[0]
        if k == "koniec_jesli_prosty":
            if not u["complex"]:
                return o, r.o, off, u
        elif k == "lista":
            off[el[1]] = r.o
            n = r.get("i")
            pola = [p for p in el[2] if G._jest(p, wersja)]
            for _ in range(n):
                for p in pola:
                    r.get(p[0])
            u[el[1]] = n
        elif k == "cele":
            off["cele"] = r.o
            n = r.get("I")
            for _ in range(n):
                if r.get("I"):
                    raise G.BladFormatu("polimorficzny element listy celów")
                r.get("I"); r.get("I"); r.get("B")
            u["cele"] = n
        else:
            if not G._jest(el, wersja):
                continue
            off[el[1]] = r.o
            u[el[1]] = r.get(k)
            if el[1] == "valid" and not u["valid"]:
                return o, r.o, off, u
    return o, r.o, off, u


def _gracz_z_offsetami(d, o, wersja):
    """Struktura gracza: offsety liczników i rekordów jednostek (kubełki)."""
    r = _RO(d, o)
    G._prefiks(r)
    r.get("B"); r.get("B")
    off_nast = r.o; nast = r.get("I")
    r.get("I"); r.get("f"); r.get("f"); r.get("f"); r.get("wstr")
    off_liczba = r.o; liczba = r.get("I")
    kubelki = []
    for _ in range(G.KUBELKI):
        off_k = r.o
        k = r.get("I")
        rek = []
        for _ in range(k):
            a, b, off, u = _jednostka_z_offsetami(d, r.o, wersja)
            rek.append((a, b, off, u))
            r.o = b
        kubelki.append({"offset": off_k, "liczba": k, "rekordy": rek, "koniec": r.o})
    return {"off_nast": off_nast, "nast": nast, "off_liczba": off_liczba, "liczba": liczba, "kubelki": kubelki}


def _kawalek(blob, tag):
    for k in S.kawalki(blob):
        if k["tag"] == tag:
            return k
    raise ValueError(f"brak kawałka {tag}")


def _start_gracza(d5, nr, wersja):
    gr = G.czytaj(d5, wersja)
    if nr >= len(gr):
        raise ValueError("brak gracza")
    # położenie gracza: wyszukanie kotwicy (jak gracze.czytaj) – gracz 0 zaczyna się od 12
    o = 12
    for i in range(1, nr + 1):
        koniec, _g = G._gracz(d5, o, wersja, True)
        wzor = struct.pack("<II", *gr[i - 1]["kotwica"])
        p = d5.find(wzor, koniec)
        while p >= 0:
            try:
                G._gracz(d5, p - 44, wersja, False)
                o = p - 44
                break
            except (G.BladFormatu, struct.error, UnicodeDecodeError):
                p = d5.find(wzor, p + 1)
        else:
            raise ValueError(f"nie znaleziono gracza {i}")
    return o


def zbadaj(sciezka):
    blob = Path(sciezka).read_bytes()
    k5 = _kawalek(blob, 5)
    wersja = k5["minor"]
    d5 = maybe_unpack(k5["surowe"])
    o1 = _start_gracza(d5, 1, wersja)
    g = _gracz_z_offsetami(d5, o1, wersja)
    jedn = [(u, a, b) for kb in g["kubelki"] for a, b, off, u in kb["rekordy"]]
    print(json.dumps({"wersja": wersja, "gracz1_offset": o1, "nastepna_instancja": g["nast"], "liczba": g["liczba"],
                      "rekordow": len(jedn)}))
    for u, a, b in jedn:
        if u.get("type") in (32, 422, 216, 173):
            print(hex(u["id"]), u["type"], u["X"], u["Y"], round(u.get("pos.x", 0), 3), round(u.get("pos.y", 0), 3),
                  round(u.get("pos.z", 0), 3), "listy", {k: u.get(k) for k in ("L_pairs", "L_u32a", "L_u32b", "L_pts", "L_f32", "L_b8", "cele")},
                  "bajtow", b - a)
    t = S.teren(_kawalek(blob, 4)["surowe"])
    print(json.dumps({"A": t["A"], "B": t["B"]}))


def _rekordy_gracza1(blob):
    k5 = _kawalek(blob, 5)
    wersja = k5["minor"]
    d5 = maybe_unpack(k5["surowe"])
    o1 = _start_gracza(d5, 1, wersja)
    return k5, wersja, d5, _gracz_z_offsetami(d5, o1, wersja)


def _wzor(blob_zrodla, wzor_id):
    _k5, wersja, d5, g = _rekordy_gracza1(blob_zrodla)
    for kb in g["kubelki"]:
        for a, b, off, u in kb["rekordy"]:
            if u.get("id") == wzor_id:
                if u.get("L_pts"):
                    raise SystemExit(f"jednostka wzorcowa {hex(wzor_id)} ma trasę (L_pts) – wybierz stojącą")
                return bytes(d5[a:b]), {k: v - a for k, v in off.items()}, wersja, u
    raise SystemExit(f"brak jednostki wzorcowej {hex(wzor_id)} u gracza 1")


def zbuduj(wej, wyj, uklad_plik, riverlands):
    uklad = json.loads(Path(uklad_plik).read_text(encoding="utf-8"))
    blob = Path(wej).read_bytes()
    if struct.unpack_from("<I", blob, 0)[0] != len(blob) - 4:
        raise SystemExit("nagłówek: pierwsze słowo ≠ długość pliku − 4 (nieznany wariant zapisu)")
    k5 = _kawalek(blob, 5)
    wersja = k5["minor"]
    d5 = bytearray(maybe_unpack(k5["surowe"]))
    wynik_grup = {}
    # etap 30: grupa może należeć do innego gracza ("gracz": N, domyślnie 1) – np. przeciwnik w pojedynku.
    # Wzór jednostki zawsze z gracza 1 (kopia bajt w bajt); identyfikator = (N << 24) | następna instancja gracza N.
    # Graczy przetwarzamy od ostatniego: wstawki u gracza N nie przesuwają offsetów graczy wcześniejszych.
    po_graczach: dict[int, list] = {}
    for nazwa, grp in uklad["grupy"].items():
        po_graczach.setdefault(int(grp.get("gracz", 1)), []).append((nazwa, grp))
    nowe_ids = {}
    for nr in sorted(po_graczach, reverse=True):
        g = _gracz_z_offsetami(bytes(d5), _start_gracza(bytes(d5), nr, wersja), wersja)
        nast = g["nast"]
        wstawki: dict[int, list[bytes]] = {}
        for nazwa, grp in po_graczach[nr]:
            zr = Path(grp["zrodlo"]).read_bytes() if grp.get("zrodlo") else blob
            rek_wzor, off, w_wzoru, u = _wzor(zr, int(grp["wzor"], 16))
            if w_wzoru != wersja:
                raise SystemExit(f"wzór {grp['wzor']} z wersji {w_wzoru}, scenariusz {wersja}")
            ids = []
            for (x, y) in grp["pozycje"]:
                rec = bytearray(rek_wzor)
                nid = (nr << 24) | nast
                struct.pack_into("<I", rec, off["id"], nid)
                struct.pack_into("<i", rec, off["X"], int(x)); struct.pack_into("<i", rec, off["Y"], int(y))
                t = off["transform"]                    # macierz 4×4 f32 wierszami: translacja = elementy 3, 7, 11
                struct.pack_into("<f", rec, t + 12, float(x)); struct.pack_into("<f", rec, t + 28, float(y))
                if "z" in grp:
                    struct.pack_into("<f", rec, t + 44, float(grp["z"]))
                wstawki.setdefault(nast % G.KUBELKI, []).append(bytes(rec))
                ids.append(hex(nid))
                nast += 1
            wynik_grup[nazwa] = {"typ": u.get("type"), "wzor": grp["wzor"], "gracz": nr, "id": ids,
                                 "pozycje": grp["pozycje"]}
            nowe_ids.setdefault(nr, set()).update(int(i, 16) for i in ids)
        n_nowych = sum(len(v) for v in wstawki.values())
        for kb_nr in sorted(wstawki, reverse=True):          # od końca – wcześniejsze offsety bez zmian
            kb = g["kubelki"][kb_nr]
            d5[kb["koniec"]:kb["koniec"]] = b"".join(wstawki[kb_nr])
            struct.pack_into("<I", d5, kb["offset"], kb["liczba"] + len(wstawki[kb_nr]))
        struct.pack_into("<I", d5, g["off_liczba"], g["liczba"] + n_nowych)
        struct.pack_into("<I", d5, g["off_nast"], nast)
    gr = G.czytaj(bytes(d5), wersja)                     # kontrola odczytu całego kawałka
    for nr, nowe in nowe_ids.items():
        znal = [x for x in gr[nr]["jednostki"] if x.get("id") in nowe]
        if len(znal) != len(nowe):
            raise SystemExit(f"kontrola: gracz {nr}: odczytano {len(znal)} z {len(nowe)} nowych jednostek")
    n_nowych = sum(len(v) for v in nowe_ids.values())
    spec = importlib.util.spec_from_file_location("riverlands_bib", riverlands)
    rl = importlib.util.module_from_spec(spec); spec.loader.exec_module(rl)
    spak = rl.pack_pk01(bytes(d5))
    if maybe_unpack(spak) != bytes(d5):
        raise SystemExit("kontrola kompresji: rozpakowanie ≠ dane")
    q = k5["offset"]
    nowy = blob[:q] + struct.pack("<IIiI", k5["major"], k5["minor"], 5, len(spak)) + spak + blob[q + 16 + k5["rozmiar"]:]
    nowy = struct.pack("<I", len(nowy) - 4) + nowy[4:]
    S.kawalki(nowy)                                       # kontrola ramek do końca pliku
    Path(wyj).write_bytes(nowy)
    Path(wyj).with_suffix(".uklad.json").write_text(json.dumps({"grupy": wynik_grup}, indent=1))
    print(json.dumps({"plik": str(wyj), "dodano": n_nowych, "grupy": {k: len(v["id"]) for k, v in wynik_grup.items()}}))


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    opcje = dict(x[2:].split("=", 1) for x in sys.argv[1:] if x.startswith("--") and "=" in x)
    if a[0] == "zbadaj":
        zbadaj(a[1])
    elif a[0] == "zbuduj":
        zbuduj(a[1], a[2], a[3], opcje.get("riverlands", str(Path(__file__).resolve().parents[3] / "Riverlands" / "Riverlands_0_8_1.py")))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
