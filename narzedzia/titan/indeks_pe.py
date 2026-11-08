"""Indeks instrukcji binarki PE (x86-32) do pytań o dostęp do pól struktur Titan.

Narzędzie analityczne OpenEE (etap 30). Czyta EXE tylko do odczytu, wynik trzyma w lokalnej pamięci podręcznej
(~/.cache/openee_re/<sha256>.npz) – poza repozytorium. Nie zapisuje kodu ani bajtów binarki do repozytorium.

Metoda: liniowy przegląd sekcji kodu (capstone, tryb szczegółowy). Dla każdej instrukcji z operandem pamięci
[rejestr + przesunięcie] zapisuje: adres, przesunięcie, rejestr bazowy, rodzaj dostępu (O/Z/OZ), rozmiar operandu,
mnemonik. Początki funkcji = cele bezpośrednich `call rel32` oraz wskaźniki z obrazu (vtable) trafiające tuż za ret
lub wypełnienie (kandydaci, nie pewnik).

Ograniczenia [W]: przegląd liniowy może rozsynchronizować się na danych w sekcji kodu (tablice skoków);
dostęp przez wyliczony adres (lea + indeks) nie jest widoczny jako przesunięcie pola; to samo przesunięcie
występuje w wielu strukturach – wynik to KANDYDACI do weryfikacji, nie przypisania.
"""
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

import numpy as np

KATALOG = Path(os.environ.get("OPENEE_RE_CACHE", Path.home() / ".cache" / "openee_re"))
WERSJA_INDEKSU = 4
DOSTEP = {1: "O", 2: "Z", 3: "OZ"}
# Rodzaj dostępu wyznaczany regułą mnemonika (pole access capstone dla operandów pamięci x87 bywa błędne).
TYLKO_ZAPIS = {"mov", "fstp", "fst", "fistp", "fist", "fnstsw", "fnstcw", "movsd", "movss", "stosd", "stosb",
               "seta", "setae", "setb", "setbe", "sete", "setne", "setg", "setge", "setl", "setle", "sets", "setns",
               "setnp", "setp", "fbstp", "fisttp"}
ODCZYT_ZAPIS = {"add", "sub", "inc", "dec", "or", "and", "xor", "adc", "sbb", "neg", "not", "shl", "shr", "sar",
                "rol", "ror", "xchg", "cmpxchg", "xadd", "rcl", "rcr", "btr", "bts", "btc"}


def sha256(p: str | Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def _buduj(exe: Path) -> dict[str, np.ndarray]:
    import capstone
    import pefile
    from capstone import x86
    pe = pefile.PE(str(exe), fast_load=True)
    base = pe.OPTIONAL_HEADER.ImageBase
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    md.skipdata = True
    adr, disp, reg, acc, size, mnem = [], [], [], [], [], []
    calls = set()
    kod_zakresy = []
    mnem_id: dict[str, int] = {}
    reg_id: dict[str, int] = {}
    for s in pe.sections:
        # Binarki GOG/NeoEE mają przestawione flagi sekcji: kod Titan leży w pierwszej sekcji (VA 0x1000) nazwanej
        # „.data”/„.rdata”. Bierzemy sekcje wykonywalne, sekcje z flagą kodu i pierwszą sekcję obrazu.
        if not (s.Characteristics & 0x20000000 or s.Characteristics & 0x20 or s.VirtualAddress == 0x1000):
            continue
        if s.SizeOfRawData == 0:
            continue
        kod = s.get_data()
        va = base + s.VirtualAddress
        kod_zakresy.append((va, kod))
        for ins in md.disasm(kod, va):
            if ins.id == 0:
                continue
            if ins.mnemonic == "call" and ins.operands and ins.operands[0].type == x86.X86_OP_IMM:
                calls.add(ins.operands[0].imm & 0xFFFFFFFF)
            for k, op in enumerate(ins.operands):
                if op.type != x86.X86_OP_MEM or op.mem.base == 0:
                    continue
                d = op.mem.disp & 0xFFFFFFFF
                if d == 0 or d > 0x400000:                  # tylko przesunięcia pól (nie adresy globalne)
                    continue
                if op.mem.base in (x86.X86_REG_ESP, x86.X86_REG_EBP):
                    continue                                 # zmienne lokalne i argumenty
                mn = ins.mnemonic
                if mn == "lea":
                    a = 0
                elif k == 0 and mn in TYLKO_ZAPIS:
                    a = 2
                elif k == 0 and mn in ODCZYT_ZAPIS:
                    a = 3
                else:
                    a = 1
                rn = ins.reg_name(op.mem.base)
                adr.append(ins.address); disp.append(d)
                reg.append(reg_id.setdefault(rn, len(reg_id))); acc.append(a); size.append(op.size)
                mnem.append(mnem_id.setdefault(ins.mnemonic, len(mnem_id)))
    # Funkcje wołane tylko pośrednio (vtable): wskaźniki w obrazie trafiające w kod tuż za ret/ret n/wypełnieniem.
    img = pe.get_memory_mapped_image()
    w = np.frombuffer(img[: len(img) // 4 * 4], dtype="<u4")
    for va, kod in kod_zakresy:
        m = (w > va) & (w < va + len(kod))
        for t in np.unique(w[m]):
            o = int(t) - va
            pb = kod[o - 1]
            if pb in (0xC3, 0xCC, 0x90) or (o >= 3 and kod[o - 3] == 0xC2):
                calls.add(int(t))
    return {"adr": np.array(adr, np.uint32), "disp": np.array(disp, np.uint32), "reg": np.array(reg, np.uint8),
            "acc": np.array(acc, np.uint8), "size": np.array(size, np.uint8), "mnem": np.array(mnem, np.uint16),
            "funkcje": np.array(sorted(calls), np.uint32),
            "mnem_nazwy": np.array(sorted(mnem_id, key=mnem_id.get)), "reg_nazwy": np.array(sorted(reg_id, key=reg_id.get)),
            "wersja": np.array([WERSJA_INDEKSU])}


class Indeks:
    def __init__(self, exe: str | Path):
        self.exe = Path(exe)
        self.sha = sha256(self.exe)
        KATALOG.mkdir(parents=True, exist_ok=True)
        p = KATALOG / f"{self.sha[:32]}.npz"
        d = None
        if p.exists():
            d = dict(np.load(p))
            if int(d.get("wersja", [0])[0]) != WERSJA_INDEKSU:
                d = None
        if d is None:
            d = _buduj(self.exe)
            np.savez_compressed(p, **d)
        self.d = d
        self.f = d["funkcje"]

    def funkcja(self, a: int) -> int | None:
        i = int(np.searchsorted(self.f, a, side="right")) - 1
        return int(self.f[i]) if i >= 0 else None

    def dostepy(self, przesuniecie: int, rozmiar: int | None = None) -> list[dict]:
        d = self.d
        m = d["disp"] == przesuniecie
        if rozmiar:
            m &= d["size"] == rozmiar
        out = []
        for i in np.nonzero(m)[0]:
            a = int(d["adr"][i])
            out.append({"adres": a, "funkcja": self.funkcja(a), "dostep": DOSTEP.get(int(d["acc"][i]), "adres"),
                        "rozmiar": int(d["size"][i]), "rejestr": str(d["reg_nazwy"][d["reg"][i]]),
                        "mnemonik": str(d["mnem_nazwy"][d["mnem"][i]])})
        return out


if __name__ == "__main__":
    ix = Indeks(sys.argv[1])
    for x in ix.dostepy(int(sys.argv[2], 16), int(sys.argv[3]) if len(sys.argv) > 3 else None)[:200]:
        print(f"{x['adres']:08X} f={x['funkcja'] or 0:08X} {x['dostep']:3} {x['rozmiar']} {x['mnemonik']} [{x['rejestr']}]")
