#!/usr/bin/env python3
"""Kierunek „projektowy” modeli z flagą dbobjects „Always face camera” (OpenEE 0.5.1, diagnostyka): średnia
ważona polem normalna trójkątów (układ CEM, Z w górę), rzut poziomy i kąt nachylenia. Jeśli wszystkie impostory
patrzą w ten sam kierunek, jest to kierunek stałej kamery EE, do którego obraca je billboard.
Użycie: kierunek_billboardow.py <katalog_gry>"""
import sys, os, json, math, collections
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import cem, db
from analiza_modelu import wczytaj, czesci, przeksztalc

root = sys.argv[1]
g = {r["ID"]: r for r in db.dekoduj(wczytaj(root, "db/dbgraphics.dat")[0], "dbgraphics")}
ob = db.dekoduj(wczytaj(root, "db/dbobjects.dat")[0], "dbobjects")
modele = collections.Counter()
for r in ob:
    if r.get("Always face camera") and r.get("Graphic ID") in g:
        mp = str(g[r["Graphic ID"]].get("Model path", "")).replace("\\", "/").lower()
        if mp: modele[mp] += 1
wyn = []
for mp in sorted(modele):
    b, _ = wczytaj(root, mp + ".cem")
    if not b: continue
    try: M = cem.czytaj_cem(b)
    except Exception: continue
    if M["wersja"] != (2, 0): continue
    S = [0.0, 0.0, 0.0]; A = 0.0
    for s, m, G, M0 in czesci(M):
        v = m["klatki"][0]["wierzcholki"]; nv = len(v) // 8
        P = [przeksztalc(G, v[8*i:8*i+3]) for i in range(nv)]
        N = [v[8*i+3:8*i+6] for i in range(nv)]
        for mt in m["materialy"]:
            ind = cem.indeksy_materialu(m, mt)
            for t in range(0, len(ind), 3):
                a, b2, c = (P[i] for i in ind[t:t+3])
                u = (b2[0]-a[0], b2[1]-a[1], b2[2]-a[2]); w = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
                n = (u[1]*w[2]-u[2]*w[1], u[2]*w[0]-u[0]*w[2], u[0]*w[1]-u[1]*w[0])
                ar = math.sqrt(sum(x*x for x in n)) / 2
                if ar <= 0: continue
                vn = [sum(N[i][k] for i in ind[t:t+3]) for k in range(3)]   # strona wg normalnych wierzchołków
                sg = 1 if sum(n[k]*vn[k] for k in range(3)) >= 0 else -1
                for k in range(3): S[k] += sg * n[k] / 2
                A += ar
    h = math.hypot(S[0], S[1])
    wyn.append({"model": mp, "obiekty": modele[mp], "azymut_st": round(math.degrees(math.atan2(S[1], S[0])), 1),
                "nachylenie_st": round(math.degrees(math.atan2(S[2], h)), 1), "spojnosc": round(math.sqrt(sum(x*x for x in S)) / A, 3) if A else 0})
az = [w["azymut_st"] for w in wyn if w["spojnosc"] > 0.3]
print(json.dumps({"modele": len(wyn), "azymuty_spojnych": collections.Counter(int(round(a / 15)) * 15 for a in az).most_common(),
                  "lista": wyn}, ensure_ascii=False, indent=0)[:6000])
