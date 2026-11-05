"""Kawałek 5 scenariusza (EEPPlayerHelper): gracze i obiekty mapy – czytnik OpenEE (tylko odczyt).

Gramatyka rekordu jednostki jest opisana DANYMI (lista pól GRAMATYKA_JEDNOSTKI), eksportowanymi do
dane/gramatyka_jednostki.json – ten sam opis wykorzystuje czytnik GDScript (silnik/importery/scenariusz.gd).
Źródło opisu: dokumentacja laboratorium RAPORT_EEPPLAYER.md / RAPORT_EEOBJECTS*.md (kolejność pól ustalona
tam na podstawie analizy i zweryfikowana round-tripem 29/29 plików); implementacja OpenEE jest własna.

Typy pól: I/i (u32/i32), f (f32), B (u8), H (u16), raw:N, wstr (u32 długość + bajty),
          lista:<nazwa>:<pola elementu> (licznik i32), cele (lista celów – element polimorficzny ⇒ błąd).
"""
import json, os, struct

P3 = [["f", "x"], ["f", "y"], ["f", "z"]]
GRAMATYKA_JEDNOSTKI = (
    [["I", "type"], ["B", "valid"], ["B", "complex"], ["i", "X"], ["i", "Y"], ["I", "id"],
     ["B", "u28"], ["B", "u29"], ["B", "u2b"], ["I", "u38"], ["f", "u3c"], ["i", "u40"], ["i", "u_ignored"],
     ["koniec_jesli_prosty"],
     ["lista", "L_pairs", [["i", "a"], ["I", "b", {"od": 248}]]],
     ["lista", "L_u32a", [["I", "v"]]],
     ["lista", "L_u32b", [["I", "v"]]],
     ["lista", "L_pts", P3 + [["f", "a"], ["f", "b"]]]]
    + [["f", "pos." + c] for c in "xyz"] + [["raw:64", "transform"]]
    + [["B", "c34e"], ["f", "c174"], ["I", "c178"]] + [["f", "orient1." + c] for c in "xyz"] + [["f", "orient2." + c] for c in "xyz"]
    + [["i", "c1a4"], ["i", "c1a8"], ["I", "c1c0"], ["I", "c1c4"], ["I", "c1cc"], ["I", "c1d0"], ["I", "c1d4"], ["I", "c1d8"],
       ["I", "l2c"], ["lista", "L_f32", [["f", "v"]]],
       ["f", "c210"], ["f", "c238"], ["f", "angle"], ["f", "c21c"], ["i", "c260"],
       ["I", "c264"], ["I", "c268"], ["I", "c26c"], ["I", "c270"],
       ["f", "c224"], ["f", "c2a0"], ["i", "c298"], ["i", "c27c"], ["i", "c280"], ["f", "c290"],
       ["i", "c2a4"], ["i", "c2a8"], ["i", "c2ac"], ["i", "c2b0"], ["i", "c2bc"], ["i", "c294"],
       ["f", "c22c"], ["f", "c248"], ["i", "c2b8"], ["i", "c284"],
       ["I", "c2e8"], ["I", "c300"], ["I", "c_loc78"], ["I", "c2ec"], ["I", "c308"], ["I", "c304"],
       ["H", "c33c"]]
    + [["B", n] for n in ("c347", "c340", "c341", "c343", "c34b", "c34a", "c342", "c34c")]
    + [["f", "c218"], ["B", "c346"], ["I", "c1f8"], ["i", "c2b4"], ["I", "c2fc"], ["I", "c1dc"], ["I", "c1e0"],
       ["f", "c288"], ["i", "c28c"], ["B", "c344"], ["i", "c278"], ["I", "c1fc"], ["f", "c53c8_a"], ["f", "c53c8_b"],
       ["B", "c34d"], ["f", "color.r"], ["f", "color.g"], ["f", "color.b"], ["B", "c349"], ["B", "c348"],
       ["I", "c274"], ["f", "c228"], ["cele"],
       ["i", "c2c0"], ["i", "c2c4"], ["I", "c200"], ["I", "c1e4"], ["lista", "L_b8", [["I", "v"]]],
       ["f", "c240"], ["B", "c34f"], ["B", "c350"], ["I", "c31c"], ["I", "c318"], ["I", "c314"], ["I", "c310"],
       ["B", "c_loc15"], ["i", "c2e04_a"], ["i", "c2e04_b"], ["i", "c2c8"], ["i", "c2cc"], ["f", "c2d4"], ["i", "c2d0"],
       ["B", "c345"], ["f", "c118"], ["f", "c11c"], ["f", "c120"], ["f", "c214"], ["I", "c208"], ["H", "c33e"], ["I", "c1f4"],
       ["B", "c351"], ["lista", "L_d0", [["i", "v"]]], ["i", "c2e0"], ["i", "c2e4"]]
    + [["f", "pt_d4." + c] for c in "xyz"]
    + [["I", "c320", {"od": 226}], ["I", "c328", {"od": 232}], ["B", "c355", {"od": 235, "zapis": True}],
       ["I", "c358", {"od": 235, "zapis": True}], ["H", "c35c", {"od": 243}], ["f", "c250", {"od": 244, "zapis": True}],
       ["I", "c32c", {"od": 245, "zapis": True}]])
# Warunki wersji (etap 3, analiza EEComplexUnit::Load w EE-AOC.exe – RAPORT_ETAP_3 §4): pole czytane tylko, gdy
# wersja kawałka 5 >= "od" (lub, przy "zapis", gdy plik jest zapisem gry – flaga param_1 ≠ 0; scenariusze: 0).
# Wersje: EE 1.x = 231 (0xE7), AoC = 250 (0xFA).

KUBELKI = 128
POZIOMY_ULEPSZEN = 16


class BladFormatu(Exception):
    pass


class _R:
    def __init__(self, d, o=0):
        self.d, self.o = d, o

    def get(self, t):
        if t == "wstr":
            n = struct.unpack_from("<I", self.d, self.o)[0]
            if n > 4096:
                raise BladFormatu(f"napis {n} @ {self.o}")
            v = self.d[self.o + 4:self.o + 4 + n]; self.o += 4 + n
            return v
        if t.startswith("raw:"):
            n = int(t[4:]); v = self.d[self.o:self.o + n]; self.o += n
            if len(v) != n:
                raise BladFormatu("koniec danych")
            return v
        f = {"I": "<I", "i": "<i", "f": "<f", "B": "<B", "H": "<H"}[t]
        try:
            v = struct.unpack_from(f, self.d, self.o)[0]
        except struct.error:
            raise BladFormatu("koniec danych")
        self.o += struct.calcsize(f)
        return v


def _jest(el, wersja, zapis=False):
    w = el[2] if len(el) > 2 and isinstance(el[2], dict) else None
    return w is None or wersja >= w["od"] or (zapis and w.get("zapis"))


def czytaj_jednostke(r, wersja=250):
    u = {}
    for el in GRAMATYKA_JEDNOSTKI:
        k = el[0]
        if k == "koniec_jesli_prosty":
            if not u["complex"]:
                return u
        elif k == "lista":
            n = r.get("i")
            if n < 0 or n > 100000:
                raise BladFormatu(f"lista {el[1]}: {n}")
            pola = [p for p in el[2] if _jest(p, wersja)]
            u[el[1]] = [{p[1]: r.get(p[0]) for p in pola} for _ in range(n)]
        elif k == "cele":
            n = r.get("I")
            for _ in range(n):
                if r.get("I"):
                    raise BladFormatu("polimorficzny element listy celów – format nieodtworzony")
                r.get("I"); r.get("I"); r.get("B")
        else:
            if not _jest(el, wersja):
                continue
            u[el[1]] = r.get(k)
            if el[1] == "valid" and not u["valid"]:
                return u
    return u


def _prefiks(r):
    typ = r.get("i")
    if typ not in (0, 1):
        raise BladFormatu(f"typ gracza {typ}")
    for _ in range(10):
        r.get("I")
    n = r.get("I"); l20 = r.get("I")
    if n > 5000:
        raise BladFormatu("ulepszenia")
    for _ in range(n):
        r.get("I"); r.get("wstr"); r.get("raw:%d" % (4 * POZIOMY_ULEPSZEN)); r.get("I")
    return typ, n, l20


def _rts(r, wersja=250, czesciowo=False):
    r.get("B"); r.get("B"); r.get("I"); r.get("I")
    kolor = (r.get("f"), r.get("f"), r.get("f"))
    nazwa = r.get("wstr")
    if not nazwa.endswith(b"\0") or any(c < 32 for c in nazwa[:-1]):
        raise BladFormatu("nazwa gracza")
    r.get("I")
    jedn = []
    for _ in range(KUBELKI):
        k = r.get("I")
        if k > 100000:
            raise BladFormatu("kubełek")
        for _ in range(k):
            start = r.o
            try:
                jedn.append(czytaj_jednostke(r, wersja))
            except BladFormatu as e:
                if not czesciowo:
                    raise
                # rekord niemożliwy do odczytania (np. polimorficzna lista celów) – reszta jednostek gracza pominięta
                return kolor, nazwa[:-1].decode("cp1250"), jedn, {"blad": str(e), "offset": start}
    r.get("B")
    return kolor, nazwa[:-1].decode("cp1250"), jedn, None


def _gracz(d, o, wersja=250, czesciowo=False):
    r = _R(d, o)
    typ, n, l20 = _prefiks(r)
    kolor, nazwa, jedn, przerwa = _rts(r, wersja, czesciowo)
    g = {"typ": typ, "kolor": kolor, "nazwa": nazwa, "jednostki": jedn, "kotwica": (n, l20)}
    if przerwa:
        g["niepelny"] = przerwa
        return przerwa["offset"], g
    return r.o, g


def czytaj(dane, wersja=250):
    """Zwraca listę graczy: {typ, kolor (r,g,b), nazwa, jednostki: [...], [niepelny]}. Gracz 0 = World.
    wersja = wersja kawałka 5 (231 – EE, 250 – AoC). Gracz z nieczytelnym rekordem jednostki (polimorficzna lista
    celów) jest zwracany częściowo („niepelny”), a kolejny gracz wyszukiwany za miejscem przerwania."""
    n = struct.unpack_from("<I", dane, 0)[0]
    o = 12
    koniec, g = _gracz(dane, o, wersja, True)
    gracze = [g]
    for i in range(1, n):
        wzor = struct.pack("<II", *g["kotwica"])
        znal = None
        p = dane.find(wzor, koniec)
        while p >= 0 and znal is None:
            kand = p - 44
            if kand >= koniec:
                for czesciowo in (False, True):  # pierwszy kandydat wg położenia: pełny odczyt, a gdy się nie da – częściowy
                    try:
                        znal = _gracz(dane, kand, wersja, czesciowo)
                        break
                    except (BladFormatu, struct.error, UnicodeDecodeError):
                        pass
            p = dane.find(wzor, p + 1)
        if znal is None:
            raise BladFormatu(f"nie znaleziono gracza {i}")
        koniec, g = znal
        gracze.append(g)
    return gracze


def eksportuj_gramatyke(sciezka):
    json.dump({"zrodlo": "OpenEE – opis rekordu jednostki kawałka 5 (por. RAPORT_EEPPLAYER.md)",
               "kubelki": KUBELKI, "poziomy_ulepszen": POZIOMY_ULEPSZEN, "jednostka": GRAMATYKA_JEDNOSTKI},
              open(sciezka, "w"), ensure_ascii=False, indent=0)
