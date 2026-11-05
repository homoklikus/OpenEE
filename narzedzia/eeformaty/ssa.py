"""Archiwum SSA Empire Earth (sygnatura 'rass') – odczyt wyłącznie w trybie 'rb'.

Układ (zweryfikowany na data.ssa EE i AoC oraz archiwach kampanii):
    0x00 char[4] 'rass'
    0x04 u32     wersja (=1)
    0x08 u32     0
    0x0C u32     granica tablicy wpisów (ostatni wpis zaczyna się przed tą wartością)
    0x10 ...     wpisy, dopóki pozycja wpisu < granicy:
                 u32 długość nazwy (z bajtem NUL), nazwa (ANSI – cp1250 w polskich archiwach, separator '\\'),
                 u32 początek, u32 koniec (włącznie), u32 rozmiar (= koniec − początek + 1)
Dane wpisu mogą być kontenerem PK01 (DCL) albo surowym plikiem.
"""
import struct
from dataclasses import dataclass


@dataclass(frozen=True)
class Wpis:
    nazwa: str        # oryginalna nazwa z archiwum
    klucz: str        # znormalizowana: małe litery, '/' jako separator
    poczatek: int
    rozmiar: int


class ArchiwumSSA:
    def __init__(self, sciezka):
        self.sciezka = str(sciezka)
        self._f = open(self.sciezka, "rb")
        hdr = self._f.read(16)
        if hdr[:4] != b"rass":
            raise ValueError(f"{sciezka}: brak sygnatury 'rass'")
        self.wersja, self._zero, self.offset_danych = struct.unpack("<III", hdr[4:16])
        # Uwaga: pole 0x0C wskazuje miejsce, przed którym ZACZYNA się ostatni wpis tablicy
        # (wpis może wystawać poza tę wartość) – czytamy z zapasem.
        tab = self._f.read(self.offset_danych - 16 + 65536)
        self.wpisy = {}
        pos = 0
        while pos + 16 < self.offset_danych:
            (n,) = struct.unpack_from("<I", tab, pos)
            nazwa = tab[pos + 4:pos + 4 + n].rstrip(b"\0").decode("cp1250", "replace")
            pocz, kon, rozm = struct.unpack_from("<III", tab, pos + 4 + n)
            if kon - pocz + 1 != rozm:
                raise ValueError(f"{sciezka}: niespójny wpis {nazwa}")
            k = nazwa.replace("\\", "/").lower()
            self.wpisy[k] = Wpis(nazwa, k, pocz, rozm)
            pos += 4 + n + 12

    def czytaj_surowe(self, klucz):
        w = self.wpisy[klucz.replace("\\", "/").lower()]
        self._f.seek(w.poczatek)
        return self._f.read(w.rozmiar)

    def czytaj(self, klucz):
        from .dcl import maybe_unpack
        return maybe_unpack(self.czytaj_surowe(klucz))

    def zamknij(self):
        self._f.close()

    def __contains__(self, klucz):
        return klucz.replace("\\", "/").lower() in self.wpisy

    def __enter__(self):
        return self

    def __exit__(self, *a):
        self.zamknij()
