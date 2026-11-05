#!/usr/bin/env python3
"""Diagnostyka UV (OpenEE 0.5.1): obraz SST materiału z naniesionymi trójkątami UV (kolor = materiał), szachownica
pod przezroczystością, osobno kanał alfa. Wynik lokalny (zawiera grafikę gry – nie publikować).
Użycie: uv_modelu.py <katalog_gry> models/x textures/xT.sst wyjscie.png [część]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import cem, sst
from analiza_modelu import wczytaj, czesci
from PIL import Image, ImageDraw

root, model, tex, out = sys.argv[1:5]
M = cem.czytaj_cem(wczytaj(root, model.lower() + ".cem")[0])
obrazy = sst.czytaj_sst(wczytaj(root, tex.lower())[0])["obrazy"]
KOL = [(255, 0, 0), (0, 160, 255), (0, 255, 0), (255, 0, 255), (255, 255, 0)]
S = 3
for nr, im in enumerate(obrazy):
    w, h = im["w"], im["h"]
    rgba = Image.frombytes("RGBA", (w, h), sst.rgba_z_tga(im)).resize((w * S, h * S), Image.NEAREST)
    szach = Image.new("RGBA", rgba.size, (90, 90, 90, 255)); d0 = ImageDraw.Draw(szach)
    for y in range(0, rgba.size[1], 12):
        for x in range(0, rgba.size[0], 12):
            if (x // 12 + y // 12) % 2: d0.rectangle([x, y, x + 11, y + 11], fill=(160, 160, 160, 255))
    kol = Image.alpha_composite(szach, rgba)
    alfa = rgba.getchannel("A").convert("RGBA")
    for panel in (kol, alfa):
        d = ImageDraw.Draw(panel)
        for s, m, G, M0 in czesci(M):
            v = m["klatki"][0]["wierzcholki"]
            for k, mt in enumerate(m["materialy"]):
                if min(mt["tekstura_id"], len(obrazy) - 1) != nr: continue
                ind = cem.indeksy_materialu(m, mt)
                for t in range(0, len(ind), 3):
                    p = [(v[8 * i + 6] * w * S, v[8 * i + 7] * h * S) for i in ind[t:t + 3]]
                    d.polygon(p, outline=KOL[k % len(KOL)])
    o = Image.new("RGB", (w * S * 2 + 10, h * S), (0, 0, 0)); o.paste(kol, (0, 0)); o.paste(alfa, (w * S + 10, 0))
    o.save(out.replace(".png", f"_{nr}.png"))
print("ok")
