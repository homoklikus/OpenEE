#!/usr/bin/env python3
"""Porównanie dekompresji DCL: C (dcl_szybki.c) vs czysty Python, na próbce wpisów archiwum."""
import os, sys, time, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, dcl
A = ssa.ArchiwumSSA(sys.argv[1]); krok = int(sys.argv[2]) if len(sys.argv) > 2 else 25
assert dcl._lib() is not None, "brak biblioteki C"
n = zg = 0; tc = tp = 0.0
for i, k in enumerate(sorted(A.wpisy)):
    if i % krok: continue
    raw = A.czytaj_surowe(k)
    if not dcl.is_pk01(raw): continue
    size = int.from_bytes(raw[4:8], "little")
    t = time.time(); a = dcl.explode(raw, 12, size); tc += time.time() - t
    t = time.time(); b = dcl._explode_py(raw, 12, size); tp += time.time() - t
    n += 1; zg += a == b
print(f"wpisy {n}, zgodne {zg}, czas C {tc:.2f}s, Python {tp:.2f}s")
