"""Scenariusze SCN Empire Earth – lokalizacja kawałków FSChunk i odczyt terenu (kawałek 4).

Układ wg dokumentacji laboratorium (RAPORT_SCN.md, RAPORT_EEMAP.md), zweryfikowany ponownie
na plikach kampanii (patrz RAPORT_ETAP_1.md). Implementacja OpenEE – nie wymaga parsera całego
nagłówka: szuka listy identyfikatorów kawałków (i32 N, N × u32), pomija 7 napisów ANSI i u32,
a następnie sprawdza, że ramki kawałków układają się dokładnie do końca pliku.

Ramka kawałka: u32 major, u32 minor, i32 tag, u32 rozmiar, dane (często PK01).
Kawałek 4 (EEMap), po rozpakowaniu:
    i32 A, i32 B, u32 K(=17)
    T = 2AB + A + B rekordów pola: 4 B f10, ceil(K/2)*4 B blok, u32 n_obj (=0)
    i32 A, i32 B (powtórzone)
    T × (u8 teren, u8 flagi)
    V = 2AB + 3A + 3B + 1 punktów: (f32 wysokość, u8 klasa)
    u32, u32 teren_domyślny, u32, u32
Kolejność pól i punktów – wiersze rombu (patrz `wiersze_pol`, `wiersze_punktow`).
"""
import struct
from .dcl import maybe_unpack

WYMAGANE = {1, 2, 3, 4, 5, 6, 7, 10, 11}


def _proba_naglowka(d, p):
    n = struct.unpack_from("<i", d, p)[0]
    if not 9 <= n <= 16 or p + 4 + 4 * n > len(d):
        return None
    ids = list(struct.unpack_from(f"<{n}I", d, p + 4))
    if not WYMAGANE.issubset(ids) or any(i < 1 or i > 12 for i in ids) or ids.count(4) != 1:
        return None
    q = p + 4 + 4 * n
    for _ in range(7):                      # 7 × napis ANSI (u32 długość z NUL + bajty)
        if q + 4 > len(d):
            return None
        k = struct.unpack_from("<I", d, q)[0]
        if k > 1 << 20:
            return None
        q += 4 + k
    q += 4                                  # u32 f4ec
    chunks = []
    for cid in ids:
        if q + 16 > len(d):
            return None
        maj, mnr, tag, sz = struct.unpack_from("<IIiI", d, q)
        if tag != cid or q + 16 + sz > len(d):
            return None
        chunks.append({"tag": tag, "major": maj, "minor": mnr, "offset": q, "rozmiar": sz,
                       "surowe": d[q + 16:q + 16 + sz]})
        q += 16 + sz
    return chunks if q == len(d) else None


def kawalki(d):
    """Zwraca listę kawałków; ValueError, jeśli nie da się jednoznacznie ustalić ramek."""
    znal = []
    for p in range(4, min(len(d) - 8, 1 << 20)):
        if d[p + 4] in (1, 2, 3) and d[p] <= 16 and d[p + 1] == 0:   # szybki filtr
            r = _proba_naglowka(d, p)
            if r:
                znal.append((p, r))
    if len(znal) != 1:
        raise ValueError(f"SCN: znaleziono {len(znal)} kandydatów listy kawałków (oczekiwano 1)")
    return znal[0][1]


def _wiersze(n_wierszy, lo, hi, gorna, postoj):
    """Zakresy kolumn [lo,hi] kolejnych wierszy rombu: lo maleje do 0, hi rośnie do `gorna`;
    na krawędzi wartość zatrzymuje się na `postoj` wierszy, po czym zawraca."""
    out = []
    dl = dh = True
    sl = sh = 0
    for _ in range(n_wierszy):
        out.append((lo, hi))
        if dl:
            if lo == 0:
                sl += 1
                if sl == postoj:
                    dl = False
            else:
                lo -= 1
        else:
            lo += 1
        if dh:
            if hi == gorna:
                sh += 1
                if sh == postoj:
                    dh = False
            else:
                hi += 1
        else:
            hi -= 1
    return out


def wiersze_pol(A, B):
    """N = A+B wierszy pól; start [B-1, B]; zatrzymanie na krawędzi przez 1 krok."""
    N = A + B
    return _wiersze(N, B - 1, B, N - 1, 1)


def wiersze_punktow(A, B):
    """N+1 wierszy narożników; start [B-1, B+1]; zatrzymanie na krawędzi przez 2 kroki."""
    N = A + B
    return _wiersze(N + 1, B - 1, B + 1, N, 2)


def teren(raw4):
    d = maybe_unpack(raw4)
    A, B, K = struct.unpack_from("<iiI", d, 0)
    T = 2 * A * B + A + B
    V = 2 * A * B + 3 * A + 3 * B + 1
    blk = ((K + 1) // 2) * 4
    p = 12
    f10 = []
    for _ in range(T):
        f10.append(struct.unpack_from("<f", d, p)[0])
        p += 4 + blk
        nobj = struct.unpack_from("<I", d, p)[0]; p += 4
        if nobj:
            raise NotImplementedError("EEMap: obiekty przypięte do pól (n_obj>0) – format nieodtworzony")
    A2, B2 = struct.unpack_from("<ii", d, p); p += 8
    if (A2, B2) != (A, B):
        raise ValueError("EEMap: wymiary siatki ≠ nagłówek")
    tb = d[p:p + 2 * T]; p += 2 * T
    pola_teren, pola_flagi = tb[0::2], tb[1::2]
    wys, klasy = [], bytearray()
    for i in range(V):
        h, c = struct.unpack_from("<fB", d, p); p += 5
        wys.append(h); klasy.append(c)
    ogon = struct.unpack_from("<4I", d, p); p += 16
    if p != len(d):
        raise ValueError(f"EEMap: {len(d) - p} niewykorzystanych bajtów")
    rp = wiersze_pol(A, B)
    rv = wiersze_punktow(A, B)
    if sum(h - l + 1 for l, h in rp) != T or sum(h - l + 1 for l, h in rv) != V:
        raise ValueError("EEMap: niezgodna liczba pól/punktów z geometrią rombu")
    return {"A": A, "B": B, "K": K, "T": T, "V": V, "wiersze_pol": rp, "wiersze_punktow": rv,
            "teren": bytes(pola_teren), "flagi": bytes(pola_flagi), "f10": f10,
            "wysokosc": wys, "klasa": bytes(klasy), "ogon": ogon}
