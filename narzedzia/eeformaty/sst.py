"""Tekstury SST Empire Earth.

Układ (obserwacja, potwierdzona na teksturach terenu, przycisków i efektów):
    0x00 u8   0
    0x01 u8   ?  (=1 w obserwowanych plikach)
    0x02 u32  liczba klatek/obrazów (N)
    0x06 u32  szerokość
    0x0A u32  wysokość
    0x0E      N × { u8 znacznik (=0 w obserwowanych plikach), obraz TGA (nagłówek 18 B + piksele) }
Pliki z N=2 (np. tekstury z przyrostkiem 't' w AoC) zawierają drugi obraz tego samego rozmiaru
(znaczenie drugiego obrazu – NIEUSTALONE; hipoteza: maska koloru gracza).
TGA: 24 bpp (BGR) lub 32 bpp (BGRA); bit 5 deskryptora = początek u góry.
"""
import struct


def _tga(buf, pos):
    idlen, cmtype, typ = buf[pos], buf[pos + 1], buf[pos + 2]
    w, h = struct.unpack_from("<HH", buf, pos + 12)
    bpp, desc = buf[pos + 16], buf[pos + 17]
    if cmtype != 0 or typ not in (2, 10):
        raise ValueError(f"TGA: nieobsługiwany typ {typ}/{cmtype}")
    p = pos + 18 + idlen
    bp = bpp // 8
    if typ == 2:
        n = w * h * bp
        px = buf[p:p + n]
        p += n
    else:  # RLE
        out = bytearray()
        while len(out) < w * h * bp:
            c = buf[p]; p += 1
            if c & 0x80:
                out += buf[p:p + bp] * ((c & 0x7F) + 1); p += bp
            else:
                k = (c + 1) * bp; out += buf[p:p + k]; p += k
        px = bytes(out)
    return {"w": w, "h": h, "bpp": bpp, "top": bool(desc & 0x20), "alpha_bits": desc & 0x0F, "px": px}, p


def rgba_z_tga(img):
    """Zwraca bajty RGBA wiersz po wierszu od góry."""
    w, h, bp = img["w"], img["h"], img["bpp"] // 8
    px = img["px"]
    out = bytearray(w * h * 4)
    for y in range(h):
        sy = y if img["top"] else h - 1 - y
        row = px[sy * w * bp:(sy + 1) * w * bp]
        o = y * w * 4
        for x in range(w):
            b, g, r = row[x * bp], row[x * bp + 1], row[x * bp + 2]
            a = row[x * bp + 3] if bp == 4 else 255
            out[o:o + 4] = bytes((r, g, b, a)); o += 4
    return bytes(out)


def czytaj_sst(buf):
    if len(buf) < 15:
        raise ValueError("SST: za krótki plik")
    z0, z1, n, w, h = struct.unpack_from("<BBIII", buf, 0)
    if z0 != 0 or n < 1 or n > 4096:
        raise ValueError(f"SST: nieoczekiwany nagłówek {buf[:14].hex()}")
    pos = 14
    obrazy, znaczniki = [], []
    for _ in range(n):
        znaczniki.append(buf[pos]); pos += 1
        img, pos = _tga(buf, pos)
        obrazy.append(img)
    return {"naglowek": {"b1": z1, "klatki": n, "w": w, "h": h, "znaczniki": znaczniki}, "obrazy": obrazy,
            "reszta": len(buf) - pos}


def czytaj_tga(buf):
    img, pos = _tga(buf, 0)
    return img
