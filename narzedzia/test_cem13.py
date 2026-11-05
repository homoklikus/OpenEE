#!/usr/bin/env python3
import os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, cem
A = ssa.ArchiwumSSA(sys.argv[1]); wyn = {}
for k in sorted(A.wpisy):
    if not k.endswith(".cem"): continue
    b = A.czytaj(k)
    if b[4:8] == b"\x02\x00\x00\x00": continue
    try:
        m = cem.czytaj_cem(b)
        wyn[k] = {"ok": m["reszta_bajtow"] == 0, "reszta": m["reszta_bajtow"], "liczby": m["liczby"],
                  "problemy": cem.kontrola(m), "tekstury": [x["tekstura"] for x in m["materialy"]]}
    except Exception as e:
        wyn[k] = {"ok": False, "blad": repr(e)[:160]}
    print(k, json.dumps(wyn[k], ensure_ascii=False)[:300])
if len(sys.argv) > 2: json.dump(wyn, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
