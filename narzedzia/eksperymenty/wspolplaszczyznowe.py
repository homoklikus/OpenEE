#!/usr/bin/env python3
"""Wykrywanie trójkątów współpłaszczyznowych nakładających się (ryzyko z-fightingu) i zduplikowanych w modelu CEM
(OpenEE 0.5.1, diagnostyka). Dla każdej pary: materiały, indeksy, wierzchołki (układ modelu, Z w górę), UV, alfa
tekstury w środku UV. Tylko odczyt instalacji.
Użycie: wspolplaszczyznowe.py <katalog_gry> models/x textures/xT.sst [tol_odl=0.002] [tol_kat_stopnie=1]"""
import sys, os, json, math, collections
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import cem, sst
from analiza_modelu import wczytaj, czesci, przeksztalc


def sub(a, b): return (a[0]-b[0], a[1]-b[1], a[2]-b[2])
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def dot(a, b): return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]


def nakladaja_2d(A, B, eps=1e-6):
    """SAT dla trójkątów 2D – True gdy wnętrza się przecinają (dotyk krawędzią nie liczy się)."""
    for T in (A, B):
        for i in range(3):
            p, q = T[i], T[(i + 1) % 3]
            n = (q[1] - p[1], p[0] - q[0])
            pa = [n[0]*x[0] + n[1]*x[1] for x in A]; pb = [n[0]*x[0] + n[1]*x[1] for x in B]
            if max(pa) <= min(pb) + eps or max(pb) <= min(pa) + eps:
                return False
    return True


def analiza(root, model, tex, tol_d=0.002, tol_kat=1.0):
    M = cem.czytaj_cem(wczytaj(root, model.lower() + ".cem")[0])
    obr = sst.czytaj_sst(wczytaj(root, tex.lower())[0])["obrazy"] if tex else []
    pix = {}
    tri = []
    for s, m, G, M0 in czesci(M):
        v = m["klatki"][0]["wierzcholki"]; nv = len(v) // 8
        pos = [przeksztalc(G, v[8*i:8*i+3]) for i in range(nv)]
        for k, mt in enumerate(m["materialy"]):
            ind = cem.indeksy_materialu(m, mt)
            nr = min(mt["tekstura_id"], len(obr) - 1) if obr else -1
            for t in range(0, len(ind), 3):
                ii = ind[t:t+3]; P = [pos[i] for i in ii]
                n = cross(sub(P[1], P[0]), sub(P[2], P[0])); ln = math.sqrt(dot(n, n))
                if ln < 1e-12: continue
                n = (n[0]/ln, n[1]/ln, n[2]/ln)
                uv = [tuple(round(x, 4) for x in v[8*i+6:8*i+8]) for i in ii]
                a = None
                if nr >= 0:
                    if nr not in pix: pix[nr] = (obr[nr]["w"], obr[nr]["h"], sst.rgba_z_tga(obr[nr]))
                    w, h, px = pix[nr]; u = sum(x[0] for x in uv)/3; vv = sum(x[1] for x in uv)/3
                    a = px[4*(min(h-1, max(0, int((vv % 1)*h)))*w + min(w-1, max(0, int((u % 1)*w)))) + 3]
                tri.append({"czesc": s, "material": k, "nazwa_mat": mt["nazwa"], "nr": t // 3, "ind": ii, "P": P, "n": n,
                            "d": dot(n, P[0]), "uv": uv, "alfa_srodek": a, "tekstura_id": mt["tekstura_id"], "obraz": nr})
    cos_t = math.cos(math.radians(tol_kat))
    pary = []; dupl = []
    for i in range(len(tri)):
        A = tri[i]
        for j in range(i + 1, len(tri)):
            B = tri[j]
            c = dot(A["n"], B["n"])
            if abs(c) < cos_t: continue
            if any(abs(dot(A["n"], p) - A["d"]) > tol_d for p in B["P"]): continue
            ka = sorted(tuple(round(x, 4) for x in p) for p in A["P"]); kb = sorted(tuple(round(x, 4) for x in p) for p in B["P"])
            # rzut na płaszczyznę A
            n = A["n"]; ax = (1, 0, 0) if abs(n[0]) < 0.9 else (0, 1, 0)
            e1 = cross(n, ax); l = math.sqrt(dot(e1, e1)); e1 = (e1[0]/l, e1[1]/l, e1[2]/l); e2 = cross(n, e1)
            pa = [(dot(p, e1), dot(p, e2)) for p in A["P"]]; pb = [(dot(p, e1), dot(p, e2)) for p in B["P"]]
            if ka == kb:
                dupl.append((i, j))
            elif nakladaja_2d(pa, pb):
                pary.append((i, j, "zgodne" if c > 0 else "przeciwne"))
    def opis(t):
        return {k: (t[k] if k != "P" else [[round(x, 4) for x in p] for p in t[k]]) for k in
                ("czesc", "material", "nazwa_mat", "nr", "ind", "P", "uv", "alfa_srodek", "tekstura_id", "obraz")}
    licz = collections.Counter((tri[i]["material"], tri[j]["material"], o) for i, j, o in pary)
    return {"model": model, "trojkaty": len(tri), "pary_wspolplaszczyznowe": len(pary), "duplikaty": len(dupl),
            "pary_wg_materialow": {f"{a}-{b} {o}": n for (a, b, o), n in licz.items()},
            "przyklady": [[opis(tri[i]), opis(tri[j]), o] for i, j, o in pary[:6]],
            "duplikaty_przyklady": [[opis(tri[i]), opis(tri[j])] for i, j in dupl[:4]]}


if __name__ == "__main__":
    a = sys.argv[1:]
    print(json.dumps(analiza(a[0], a[1], a[2] if len(a) > 2 else "", *(float(x) for x in a[3:5])), ensure_ascii=False, indent=1))
