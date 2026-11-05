"""Dekompresja PKWARE DCL „implode” oraz kontener PK01 używany przez Empire Earth.

Implementacja własna OpenEE, oparta na publicznym opisie formatu DCL (algorytm „blast”,
zlib/contrib/blast, Mark Adler – opis tablic kodów i bitowego układu strumienia).
Nie zawiera kodu pochodzącego z plików Empire Earth.

Kontener PK01 (obserwacja na danych EE):
    0x00  char[4]  'PK01'
    0x04  u32      rozmiar po dekompresji
    0x08  u32      0 (zawsze zero w obserwowanych plikach)
    0x0C  ...      strumień DCL (bajt 0: typ literałów 0/1, bajt 1: log2(słownik) − 6)
"""
import struct

_MAXBITS = 13

# Skompresowane opisy długości kodów Huffmana (format „blast”: (powtórzenia-1)<<4 | długość).
_LIT_REP = bytes([
    11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8, 9, 7, 6, 7, 8, 7, 6,
    55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5, 7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9,
    8, 25, 11, 8, 11, 9, 12, 8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
    44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45, 44, 173])
_LEN_REP = bytes([2, 35, 36, 53, 38, 23])
_DIST_REP = bytes([2, 20, 53, 230, 247, 151, 248])
_LEN_BASE = (3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264)
_LEN_EXTRA = (0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8)


def _invert_table(rep, nsym):
    # W DCL kody są zapisane jako bitowa negacja kanonicznych kodów Huffmana.
    lengths = []
    for b in rep:
        lengths += [b & 15] * ((b >> 4) + 1)
    count = [0] * (_MAXBITS + 1)
    for ln in lengths:
        count[ln] += 1
    offs = [0] * (_MAXBITS + 2)
    for i in range(1, _MAXBITS + 1):
        offs[i + 1] = offs[i] + count[i]
    symbols = [0] * nsym
    for s, ln in enumerate(lengths):
        if ln:
            symbols[offs[ln]] = s
            offs[ln] += 1
    return count, symbols


_LIT = _invert_table(_LIT_REP, 256)
_LEN = _invert_table(_LEN_REP, 16)
_DIST = _invert_table(_DIST_REP, 64)


class _Bits:
    __slots__ = ("data", "pos", "buf", "cnt")

    def __init__(self, data, pos):
        self.data, self.pos, self.buf, self.cnt = data, pos, 0, 0

    def bits(self, need):
        buf, cnt = self.buf, self.cnt
        while cnt < need:
            if self.pos >= len(self.data):
                raise ValueError("DCL: koniec danych wejściowych")
            buf |= self.data[self.pos] << cnt
            self.pos += 1
            cnt += 8
        self.buf, self.cnt = buf >> need, cnt - need
        return buf & ((1 << need) - 1)

    def decode(self, h):
        count, symbols = h
        code = first = index = 0
        for ln in range(1, _MAXBITS + 1):
            code |= self.bits(1) ^ 1          # bity kodu są zanegowane
            c = count[ln]
            if code < first + c:
                return symbols[index + (code - first)]
            index += c
            first = (first + c) << 1
            code <<= 1
        raise ValueError("DCL: niepoprawny kod")


def explode(data, pos=0, expected=None):
    """Dekompresuje strumień DCL od pozycji `pos`. Zwraca bytes."""
    s = _Bits(data, pos)
    lit = s.bits(8)
    if lit > 1:
        raise ValueError("DCL: niepoprawny nagłówek literałów")
    dictbits = s.bits(8)
    if not 4 <= dictbits <= 6:
        raise ValueError("DCL: niepoprawny rozmiar słownika")
    out = bytearray()
    while True:
        if s.bits(1):
            sym = s.decode(_LEN)
            ln = _LEN_BASE[sym] + s.bits(_LEN_EXTRA[sym])
            if ln == 519:
                break
            sym = 2 if ln == 2 else dictbits
            dist = (s.decode(_DIST) << sym) + s.bits(sym) + 1
            if dist > len(out):
                raise ValueError("DCL: odległość poza buforem")
            start = len(out) - dist
            if dist >= ln:
                out += out[start:start + ln]
            else:
                for i in range(ln):
                    out.append(out[start + i])
        else:
            out.append(s.decode(_LIT) if lit else s.bits(8))
        if expected is not None and len(out) > expected:
            raise ValueError("DCL: dane dłuższe niż deklarowane")
    return bytes(out)


def is_pk01(buf):
    return buf[:4] == b"PK01"


def unpack_pk01(buf):
    if not is_pk01(buf):
        raise ValueError("To nie jest kontener PK01")
    size, zero = struct.unpack_from("<II", buf, 4)
    out = explode(buf, 12, size)
    if len(out) != size:
        raise ValueError(f"PK01: rozmiar {len(out)} ≠ deklarowany {size}")
    return out


def maybe_unpack(buf):
    """Zwraca dane rozpakowane, jeżeli to PK01; w przeciwnym razie bez zmian."""
    return unpack_pk01(buf) if is_pk01(buf) else buf


# --- przyspieszenie: biblioteka C (dcl_szybki.c) kompilowana lokalnie do OpenEE/cache/bin ---
import ctypes as _ct, os as _os, subprocess as _sp

_LIB = None
_LIB_PROBA = False


def _lib():
    global _LIB, _LIB_PROBA
    if _LIB_PROBA:
        return _LIB
    _LIB_PROBA = True
    if _os.environ.get("OPENEE_BEZ_C"):
        return None
    tu = _os.path.dirname(_os.path.abspath(__file__))
    src = _os.path.join(tu, "dcl_szybki.c")
    bdir = _os.path.normpath(_os.path.join(tu, "..", "..", "cache", "bin"))
    so = _os.path.join(bdir, "libdcl.so")
    try:
        if not _os.path.exists(so) or _os.path.getmtime(so) < _os.path.getmtime(src):
            _os.makedirs(bdir, exist_ok=True)
            _sp.run(["gcc", "-O2", "-shared", "-fPIC", "-o", so, src], check=True, capture_output=True)
        L = _ct.CDLL(so)
        L.dcl_rozpakuj.restype = _ct.c_long
        L.dcl_rozpakuj.argtypes = [_ct.c_char_p, _ct.c_long, _ct.c_char_p, _ct.c_long]
        _LIB = L
    except Exception:
        _LIB = None
    return _LIB


_explode_py = explode


def explode(data, pos=0, expected=None):  # noqa: F811 – wersja z przyspieszeniem C
    L = _lib()
    if L is None or expected is None:
        return _explode_py(data, pos, expected)
    we = bytes(data[pos:])
    wy = _ct.create_string_buffer(expected + 16)
    n = L.dcl_rozpakuj(we, len(we), wy, expected + 16)
    if n < 0:
        raise ValueError(f"DCL (C): błąd {n}")
    return wy.raw[:n]
