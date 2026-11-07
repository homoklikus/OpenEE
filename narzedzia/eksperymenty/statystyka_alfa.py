#!/usr/bin/env python3
"""Statystyka kanału alfa pod trójkątami materiałów (OpenEE 0.5.1, diagnostyka): dla każdej grafiki dbgraphics
z teksturą – udział trójkątów „player color” i zwykłych, których środek UV wypada na alfa = 0, oraz średni kolor
tekseli o alfa = 0 (co „przecieka” przy filtrowaniu/mipmapach). Tylko odczyt instalacji.
Użycie: statystyka_alfa.py <katalog_gry> [limit]"""
import sys, os, json, collections
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import cem, sst, db
from analiza_modelu import wczytaj, czesci

root = sys.argv[1]; limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9
tab = db.dekoduj(wczytaj(root, "db/dbgraphics.dat")[0], "dbgraphics")
wyn = {"grafiki": 0, "pc": collections.Counter(), "zwykle": collections.Counter(), "modele_pc_alfa0": [],
       "rgb_alfa0": collections.Counter()}
widziane = set()
for r in tab:
    mp = str(r.get("Model path", "")).replace("\\", "/").lower(); tp = str(r.get("Texture path", "")).replace("\\", "/").lower()
    if not mp or not tp or (mp, tp) in widziane: continue
    widziane.add((mp, tp))
    if len(widziane) > limit: break
    b, _ = wczytaj(root, mp + ".cem"); t, _ = wczytaj(root, tp)
    if not b or not t: continue
    try:
        M = cem.czytaj_cem(b); obr = sst.czytaj_sst(t)["obrazy"]
    except Exception:
        continue
    if M["wersja"] != (2, 0): continue
    wyn["grafiki"] += 1
    px_c = {}
    pc0 = 0; pcn = 0
    for s, m, G, M0 in czesci(M):
        v = m["klatki"][0]["wierzcholki"]
        for mt in m["materialy"]:
            nr = min(mt["tekstura_id"], len(obr) - 1)
            if nr not in px_c:
                im = obr[nr]
                px_c[nr] = (im["w"], im["h"], sst.rgba_z_tga(im))
            w, h, px = px_c[nr]
            ind = cem.indeksy_materialu(m, mt)
            pc = mt["nazwa"] == "player color"
            for k in range(0, len(ind), 3):
                u = sum(v[8 * i + 6] for i in ind[k:k + 3]) / 3; vv = sum(v[8 * i + 7] for i in ind[k:k + 3]) / 3
                x = min(w - 1, max(0, int((u % 1) * w))); y = min(h - 1, max(0, int((vv % 1) * h)))
                a = px[4 * (y * w + x) + 3]
                kl = "0" if a == 0 else ("255" if a == 255 else "1-254")
                (wyn["pc"] if pc else wyn["zwykle"])[kl] += 1
                if pc:
                    pcn += 1; pc0 += a == 0
    for nr, (w, h, px) in px_c.items():
        for i in range(0, len(px), 4 * 7):
            if px[i + 3] == 0:
                wyn["rgb_alfa0"][tuple(c // 64 * 64 for c in px[i:i + 3])] += 1
    if pc0:
        wyn["modele_pc_alfa0"].append([mp, pc0, pcn])
wyn["rgb_alfa0"] = [[list(k), n] for k, n in wyn["rgb_alfa0"].most_common(8)]
wyn["modele_pc_alfa0_liczba"] = len(wyn["modele_pc_alfa0"])
wyn["modele_pc_alfa0"] = sorted(wyn["modele_pc_alfa0"], key=lambda x: -x[1])[:25]
print(json.dumps(wyn, ensure_ascii=False, indent=1, default=dict))
