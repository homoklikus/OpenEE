"""RTTI MSVC w binarkach Titan: nazwa klasy dla vtable i vtable dla nazwy klasy (EE i AoC).

Narzędzie analityczne OpenEE (etap 30); binarka tylko do odczytu. Układ MSVC: vtable[-1] → Complete Object Locator
(+0x0C → TypeDescriptor, nazwa od +0x08, np. „.?AVEEUGAttackUnit@@”).

Użycie:
  python3 rtti_titan.py EXE nazwa 0x831968 [...]
  python3 rtti_titan.py EXE vtable EEUGAttackUnit [...]
  python3 rtti_titan.py EXE lista [WZORZEC]      – wszystkie klasy z vtable (filtr podciągu)
"""
from __future__ import annotations

import re
import sys

import pefile


class Rtti:
    def __init__(self, exe: str):
        pe = pefile.PE(exe, fast_load=True)
        self.base = pe.OPTIONAL_HEADER.ImageBase
        self.img = pe.get_memory_mapped_image()

    def u32(self, a: int) -> int:
        o = a - self.base
        return int.from_bytes(self.img[o:o + 4], "little") if 0 <= o < len(self.img) - 4 else 0

    def nazwa(self, vt: int) -> str | None:
        col = self.u32(vt - 4)
        td = self.u32(col + 12)
        o = td - self.base + 8
        if not (0 < o < len(self.img)):
            return None
        s = self.img[o:o + 120].split(b"\0")[0]
        if not s.startswith(b".?AV"):
            return None
        return s[4:].split(b"@@")[0].decode("latin1")

    def vtable(self, klasa: str) -> list[int]:
        out = []
        for m in re.finditer(re.escape(b".?AV" + klasa.encode() + b"@@\0"), self.img):
            td = self.base + m.start() - 8
            for c in re.finditer(re.escape(td.to_bytes(4, "little")), self.img):
                col = self.base + c.start() - 12
                if self.u32(col) != 0:          # signature 0 w COL; offset obiektu 0 → vtable główna
                    continue
                for v in re.finditer(re.escape(col.to_bytes(4, "little")), self.img):
                    vt = self.base + v.start() + 4
                    if self.u32(col + 4) == 0 and self.base + 0x1000 <= self.u32(vt) < self.base + 0x400000:
                        out.append(vt)          # pierwszy wpis musi wskazywać kod (odsiewa przypadkowe trafienia)
        return sorted(set(out))

    def lista(self, wzorzec: str = "") -> dict[str, list[int]]:
        out: dict[str, list[int]] = {}
        for m in re.finditer(rb"\.\?AV([A-Za-z0-9_]+)@@\0", self.img):
            k = m.group(1).decode()
            if wzorzec.lower() in k.lower():
                out[k] = self.vtable(k)
        return out


if __name__ == "__main__":
    r = Rtti(sys.argv[1])
    if sys.argv[2] == "nazwa":
        for v in sys.argv[3:]:
            print(v, r.nazwa(int(v, 16)))
    elif sys.argv[2] == "vtable":
        for k in sys.argv[3:]:
            print(k, [hex(v) for v in r.vtable(k)])
    else:
        for k, v in r.lista(sys.argv[3] if len(sys.argv) > 3 else "").items():
            print(k, [hex(x) for x in v])
