"""Rozwiązywanie instrukcji switch MSVC (drzewo porównań + tablice skoków bajtowe) dla konkretnych wartości.

Narzędzie analityczne OpenEE (etap 30). Emuluje wyłącznie instrukcje sterujące wyborem przypadku dla JEDNEJ
konkretnej wartości zmiennej przełącznika: mov rej, imm; cmp; test; add/sub/dec/inc; movzx z tablicy bajtów;
jmp [rej*4 + tablica]; skoki warunkowe i bezwarunkowe. Pierwsza instrukcja spoza tego zbioru = początek kodu
przypadku. Wynik to adres, nie kod – binarka czytana tylko do odczytu.

Użycie: python3 switch_titan.py EXE ADRES_STARTU REJESTR WARTOSC [WARTOSC ...]
  np. dispatcher wejścia w stan EE: 0x61AD69 eax 2001 2012 2021
"""
from __future__ import annotations

import sys

import capstone
import pefile
from capstone import x86

MASKA = 0xFFFFFFFF


class Emulator:
    def __init__(self, exe: str, ciagly: bool = True):
        self.ciagly = ciagly   # True: wynik = początek bloku przypadku (po ostatnim skoku), nie pierwsza „obca” instrukcja
        self.pe = pefile.PE(exe, fast_load=True)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.img = self.pe.get_memory_mapped_image()
        self.md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        self.md.detail = True

    def u8(self, a: int) -> int:
        return self.img[a - self.base]

    def u32(self, a: int) -> int:
        o = a - self.base
        return int.from_bytes(self.img[o:o + 4], "little")

    def ins(self, a: int):
        return next(self.md.disasm(self.img[a - self.base:a - self.base + 16], a))

    def przypadek(self, start: int, rej: str, wartosc: int, maks: int = 200) -> tuple[int, list[int]]:
        r = {rej: wartosc & MASKA}
        flagi = None           # (a, b) z ostatniego cmp/test-różnicy
        a = start
        sciezka = []
        cel_skoku = start      # początek bloku, do którego prowadził ostatni rozstrzygnięty skok
        for _ in range(maks):
            i = self.ins(a)
            sciezka.append(a)
            m, ops = i.mnemonic, i.operands
            nast = a + i.size
            def val(op):
                if op.type == x86.X86_OP_IMM:
                    return op.imm & MASKA
                if op.type == x86.X86_OP_REG:
                    n = i.reg_name(op.reg)
                    if n in r:
                        return r[n]
                return None
            if m == "mov" and ops[0].type == x86.X86_OP_REG and val(ops[1]) is not None:
                r[i.reg_name(ops[0].reg)] = val(ops[1]); a = nast; continue
            if m == "cmp" and ops[0].type == x86.X86_OP_REG and val(ops[0]) is not None and val(ops[1]) is not None:
                flagi = (val(ops[0]), val(ops[1])); a = nast; continue
            if m == "lea" and ops[1].type == x86.X86_OP_MEM and ops[1].mem.base and not ops[1].mem.index:
                b = i.reg_name(ops[1].mem.base)
                if b in r:
                    r[i.reg_name(ops[0].reg)] = (r[b] + ops[1].mem.disp) & MASKA; a = nast; continue
            if m in ("add", "sub") and ops[0].type == x86.X86_OP_REG and i.reg_name(ops[0].reg) in r and val(ops[1]) is not None:
                n = i.reg_name(ops[0].reg)
                r[n] = (r[n] + val(ops[1]) if m == "add" else r[n] - val(ops[1])) & MASKA
                flagi = (r[n], 0); a = nast; continue
            if m in ("dec", "inc") and ops[0].type == x86.X86_OP_REG and i.reg_name(ops[0].reg) in r:
                n = i.reg_name(ops[0].reg)
                r[n] = (r[n] + (1 if m == "inc" else -1)) & MASKA
                flagi = (r[n], 0); a = nast; continue
            if m == "movzx" and ops[1].type == x86.X86_OP_MEM and ops[1].size == 1:
                b = i.reg_name(ops[1].mem.base) if ops[1].mem.base else None
                if b in r:
                    r[i.reg_name(ops[0].reg)] = self.u8((r[b] + ops[1].mem.disp) & MASKA); a = nast; continue
            if m == "jmp" and ops[0].type == x86.X86_OP_MEM and ops[0].mem.index and ops[0].mem.scale == 4:
                ix = i.reg_name(ops[0].mem.index)
                if ix in r:
                    a = cel_skoku = self.u32((r[ix] * 4 + ops[0].mem.disp) & MASKA); continue
            if m == "jmp" and ops[0].type == x86.X86_OP_IMM:
                a = cel_skoku = ops[0].imm; continue
            if m.startswith("j") and flagi is not None and ops[0].type == x86.X86_OP_IMM:
                x, y = flagi
                sx = x - (1 << 32) if x & 0x80000000 else x
                sy = y - (1 << 32) if y & 0x80000000 else y
                war = {"ja": x > y, "jae": x >= y, "jb": x < y, "jbe": x <= y, "je": x == y, "jne": x != y,
                       "jg": sx > sy, "jge": sx >= sy, "jl": sx < sy, "jle": sx <= sy}.get(m)
                if war is not None:
                    a = cel_skoku = (ops[0].imm if war else nast); continue
            # instrukcja spoza zbioru: jeśli nie steruje przepływem i nie zmienia śledzonych rejestrów – pomijamy
            # (np. xor al, al; push; zapis do pamięci); flagi traktujemy wtedy jako nieznane
            if not (m.startswith("j") or m.startswith("call") or m.startswith("ret")):
                _, zap = i.regs_access()
                zap = {i.reg_name(x) for x in zap}
                if not (zap & set(r)) and m not in ("cmp", "test"):
                    try:
                        zmienia_flagi = bool(i.eflags)    # capstone: maska flag modyfikowanych przez instrukcję
                    except Exception:  # noqa: BLE001
                        zmienia_flagi = True
                    if zmienia_flagi or m.startswith("f") or m == "sahf":
                        flagi = None       # pominięta instrukcja zmieniła flagi – dalsze skoki nierozstrzygalne
                    a = nast; continue
            return (cel_skoku if self.ciagly else a), sciezka
        raise RuntimeError("przekroczono limit instrukcji")


if __name__ == "__main__":
    e = Emulator(sys.argv[1])
    st = int(sys.argv[2], 16)
    for v in sys.argv[4:]:
        adr, _ = e.przypadek(st, sys.argv[3], int(v, 0))
        print(f"{v}: {adr:#x}")
