"""Tabele db/*.dat Empire Earth – dekoder OpenEE sterowany schematem (dane/schemat_db_eedbeditor, GPLv3).

Obsługiwane: tabele „u32 N + N rekordów” (dbobjects, dbgraphics, dbsounds, dbcolortable, dbterrain, …).
Typy pól: STRING (stała długość), DYNAMIC_STRING (długość z wcześniejszego pola), FLOAT, liczby 1/4 B (ze znakiem).
Każde dekodowanie jest kontrolowane: liczba zużytych bajtów musi równać się długości tabeli.
Ten sam schemat eksportuje `eksportuj_uklad()` → JSON dla dekodera GDScript (baza_db.gd).

Etap 11 (docs/FORMATY_DB_EE_VS_AOC.md): warianty "aoc" (schemat bazowy) i "ee" (Empire Earth 1.0, bez pól z
dane/uklad_db_warianty.json – dbobjects, dbcivilization). Wariant rozpoznawany z rozmiaru: 4 + N × rekord(wariant),
dokładnie jeden pasujący; tabele bez opisu wariantów – układ wspólny."""
import json, os, struct

SCHEMAT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "dane",
                                        "schemat_db_eedbeditor", "AOC"))
OBSLUGIWANE = ("dbobjects", "dbgraphics", "dbsounds", "dbcolortable", "dbterrain", "dbterraintype",
               "dbcliffterrain", "dbfamily", "dbunitset", "dbmusic", "dbbuttons", "dbcivilization")


def _common():
    c = {}
    for line in open(os.path.join(SCHEMAT, "common.dats"), encoding="latin-1"):
        if line.startswith("#") or "\t" not in line:
            continue
        p = line.rstrip("\n").split("\t")
        c[p[0]] = p[1:]
    return c


def schemat(tabela):
    com = _common()
    pola = []
    for line in open(os.path.join(SCHEMAT, tabela + ".dats"), encoding="latin-1"):
        if line.startswith("#") or "\t" not in line:
            continue
        p = line.rstrip("\n").split("\t")
        if p[1].startswith("@"):
            p = [p[0]] + com[p[1][1:]]
        size, typ = int(p[1]), p[2]
        if typ in ("LINK", "ENUM", "RANGE", "DYNAMIC_STRING"):
            extra, nazwa = p[3], p[4]
        else:
            extra, nazwa = None, p[3]
        pola.append([nazwa, size, typ, int(extra) if typ == "DYNAMIC_STRING" else None])
    # unikalne nazwy pól
    widz = {}
    for f in pola:
        n = f[0]
        widz[n] = widz.get(n, 0) + 1
        if widz[n] > 1:
            f[0] = f"{n}#{widz[n]}"
    return pola


WARIANTY_PLIK = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "dane",
                                              "uklad_db_warianty.json"))


def _warianty():
    return json.load(open(WARIANTY_PLIK, encoding="utf-8"))


def uklad(tabela, wariant="aoc"):
    pola = schemat(tabela)
    pomin = set(_warianty().get(wariant, {}).get(tabela, {}).get("pomin", []))
    return [f for f in pola if f[0] not in pomin]


def rozpoznaj(dane, tabela):
    """'aoc' | 'ee' | 'wspolny'; ValueError, gdy dane nie pasują do dokładnie jednego wariantu."""
    w = _warianty()
    if not any(tabela in w.get(x, {}) for x in ("aoc", "ee")):
        return "wspolny"
    n = struct.unpack_from("<I", dane, 0)[0]
    roz = {x: sum(f[1] for f in uklad(tabela, x)) for x in ("aoc", "ee")}
    pasuja = [x for x, r in roz.items() if n > 0 and 4 + n * r == len(dane)]
    if len(pasuja) != 1:
        raise ValueError(f"{tabela}: nieobsługiwany wariant – {len(dane)} B, N = {n}, oczekiwany rekord {roz}")
    return pasuja[0]


def dekoduj(dane, tabela, wariant=None):
    w = wariant or rozpoznaj(dane, tabela)
    pola = uklad(tabela, "aoc" if w == "wspolny" else w)
    n = struct.unpack_from("<I", dane, 0)[0]
    p = 4
    rek = []
    for _ in range(n):
        vals = []
        r = {}
        for nazwa, size, typ, extra in pola:
            if typ in ("STRING", "DYNAMIC_STRING"):
                sz = vals[extra] if typ == "DYNAMIC_STRING" else size
                if sz < 0 or p + sz > len(dane):
                    raise ValueError(f"{tabela} ({w}): łańcuch {sz} B od {p} poza danymi ({len(dane)} B)")
                s = dane[p:p + sz]; p += sz
                v = s.split(b"\0")[0].decode("latin-1") if s[:1] not in (b"\xcc", b"\xff") else ""
            elif typ == "FLOAT":
                v = struct.unpack_from("<f", dane, p)[0]; p += 4
            elif size == 1:
                v = dane[p]; p += 1
            else:
                v = struct.unpack_from("<i", dane, p)[0]; p += 4
            vals.append(v)
            r[nazwa] = v
        rek.append(r)
    if p != len(dane):
        raise ValueError(f"{tabela}: zużyto {p} z {len(dane)} bajtów – schemat niezgodny")
    return rek


def eksportuj_uklad(sciezka):
    json.dump({"zrodlo": "EE DB Editor (Forlini91), GPLv3 – patrz dane/schemat_db_eedbeditor/ZRODLO.md",
               "tabele": {t: schemat(t) for t in OBSLUGIWANE}}, open(sciezka, "w"), ensure_ascii=False, indent=0)
