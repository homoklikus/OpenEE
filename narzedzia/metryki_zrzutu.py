#!/usr/bin/env python3
"""Metryki kadru zrzutu (OpenEE 0.5.1): udział prawie czarnych pikseli i stosunek energii gradientu pionowego do
poziomego (poziome pasy z-fightingu podnoszą go wyraźnie powyżej ~1). Użycie: metryki_zrzutu.py <wyj> x0 y0 x1 y1 pliki…"""
import sys, json, os
from PIL import Image
out, x0, y0, x1, y1 = sys.argv[1], *map(int, sys.argv[2:6])
wyn = {}
for p in sys.argv[6:]:
    try: im = Image.open(p).convert("L").crop((x0, y0, x1, y1))
    except Exception: continue
    w, h = im.size; px = im.load()
    czarne = sum(1 for y in range(h) for x in range(w) if px[x, y] < 22) / (w * h)
    gv = sum(abs(px[x, y + 1] - px[x, y]) for y in range(h - 1) for x in range(w)) / ((h - 1) * w)
    gh = sum(abs(px[x + 1, y] - px[x, y]) for y in range(h) for x in range(w - 1)) / (h * (w - 1))
    wyn[os.path.basename(p)] = {"czarne": round(czarne, 4), "grad_pion/poziom": round(gv / gh, 3) if gh else None}
json.dump(wyn, open(os.path.join(out, "metryki.json"), "w"), indent=1)
print(json.dumps(wyn, indent=1))
