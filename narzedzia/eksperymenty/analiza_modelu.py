#!/usr/bin/env python3
"""Diagnostyka pojedynczego modelu CEM (OpenEE 0.5.1): części, materiały, obrazy SST, alfa, transformacje,
trójkąty współpłaszczyznowe i zduplikowane. Czyta wyłącznie z instalacji (tylko odczyt), wypisuje statystyki.
Użycie: analiza_modelu.py <katalog_gry_bazowej> models/bld_stable_03 [textures/bld_stable_03T.sst] [--json plik]"""
import sys, os, json, math, collections, struct
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import ssa, cem, sst

ARCH = ["Empire Earth - The Art of Conquest/Data/data.ssa", "Empire Earth/Data/data.ssa"]


def wczytaj(root, klucz):
    for a in ARCH:                       # warstwa AoC ma pierwszeństwo nad vanilla (jak w OpenEE)
        p = os.path.join(root, a)
        if os.path.exists(p):
            A = ssa.ArchiwumSSA(p)
            if klucz in A.wpisy:
                return A.czytaj(klucz), a
    return None, None


def mnoz(a, b):  # macierze 4×4 wierszami
    return [sum(a[4 * i + k] * b[4 * k + j] for k in range(4)) for i in range(4) for j in range(4)]


def przeksztalc(M, p):
    return tuple(M[4 * i] * p[0] + M[4 * i + 1] * p[1] + M[4 * i + 2] * p[2] + M[4 * i + 3] for i in range(3))


def czesci(m, M=None, sciezka=""):
    M0 = list(m["klatki"][0]["macierz"]) if m.get("klatki") else [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    G = M0 if M is None else mnoz(M, M0)
    s = (sciezka + "/" if sciezka else "") + m["nazwa"]
    yield s, m, G, M0
    for c in m["potomne"]:
        yield from czesci(c, G, s)


def analiza(root, model, tex):
    buf, zr = wczytaj(root, model.lower() + ".cem")
    if buf is None:
        return {"blad": "brak modelu"}
    M = cem.czytaj_cem(buf)
    obrazy = []
    if tex:
        tb, _ = wczytaj(root, tex.lower())
        if tb:
            obrazy = sst.czytaj_sst(tb)["obrazy"]
    wyn = {"model": model, "archiwum": zr, "tekstura": tex, "obrazy_sst": [], "czesci": []}
    for im in obrazy:
        w, h, px = im["w"], im["h"], sst.rgba_z_tga(im)
        a = px[3::4]
        wyn["obrazy_sst"].append({"w": w, "h": h, "bpp": im["bpp"], "rle": None, "alfa_min": min(a), "alfa_0_udzial": round(a.count(0) / len(a), 3)})
    wszystkie = []
    for s, m, G, M0 in czesci(M):
        v = m["klatki"][0]["wierzcholki"] if m.get("klatki") else []
        nv = len(v) // 8
        cz = {"czesc": s, "wierzcholki": nv, "klatki": len(m.get("klatki", [])), "macierz_lokalna": [round(x, 3) for x in M0],
              "materialy": []}
        for mt in m["materialy"]:
            ind = cem.indeksy_materialu(m, mt)
            pos = [przeksztalc(G, v[8 * i:8 * i + 3]) for i in range(nv)]
            uv = [v[8 * i + 6:8 * i + 8] for i in range(nv)]
            tri = [tuple(ind[k:k + 3]) for k in range(0, len(ind), 3)]
            us = [uv[i][0] for t in tri for i in t]; vs = [uv[i][1] for t in tri for i in t]
            zdegen = 0; dup = 0; klucze = collections.Counter()
            for t in tri:
                a, b, c = (pos[i] for i in t)
                n = ((b[1]-a[1])*(c[2]-a[2])-(b[2]-a[2])*(c[1]-a[1]), (b[2]-a[2])*(c[0]-a[0])-(b[0]-a[0])*(c[2]-a[2]),
                     (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))
                if math.sqrt(sum(x * x for x in n)) < 1e-9: zdegen += 1
                k = tuple(sorted(tuple(round(x, 3) for x in pos[i]) for i in t))
                klucze[k] += 1
                wszystkie.append((k, s, mt["nazwa"]))
            dup = sum(c - 1 for c in klucze.values() if c > 1)
            img = obrazy[min(mt["tekstura_id"], len(obrazy) - 1)] if obrazy else None
            e = {"nazwa": mt["nazwa"], "tekstura_id": mt["tekstura_id"], "tekstura": mt["tekstura"], "v_offset": mt["v_offset"],
                 "v_liczba": mt["v_liczba"], "trojkaty": len(tri), "zdegenerowane": zdegen, "duplikaty_w_materiale": dup,
                 "uv_zakres": [round(min(us), 3), round(max(us), 3), round(min(vs), 3), round(max(vs), 3)] if us else None}
            if img:
                w, h, px = img["w"], img["h"], sst.rgba_z_tga(img)
                al = []
                for t in tri:
                    u = sum(uv[i][0] for i in t) / 3; vv = sum(uv[i][1] for i in t) / 3
                    x = min(w - 1, max(0, int((u % 1.0) * w))); y = min(h - 1, max(0, int((vv % 1.0) * h)))
                    al.append(px[4 * (y * w + x) + 3])
                e["alfa_w_srodkach"] = {"0": al.count(0), "1-254": sum(1 for x in al if 0 < x < 255), "255": al.count(255)}
            cz["materialy"].append(e)
        bb = [przeksztalc(G, v[8 * i:8 * i + 3]) for i in range(nv)]
        if bb:
            cz["aabb_model"] = [round(min(p[k] for p in bb), 3) for k in range(3)] + [round(max(p[k] for p in bb), 3) for k in range(3)]
        wyn["czesci"].append(cz)
    # duplikaty między częściami/materiałami (te same 3 wierzchołki)
    licz = collections.defaultdict(list)
    for k, s, n in wszystkie: licz[k].append((s, n))
    wyn["duplikaty_globalne"] = sum(len(x) - 1 for x in licz.values() if len(x) > 1)
    wyn["duplikaty_przyklady"] = [x for x in licz.values() if len(x) > 1][:5]
    return wyn


if __name__ == "__main__":
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    w = analiza(a[0], a[1], a[2] if len(a) > 2 else "")
    print(json.dumps(w, ensure_ascii=False, indent=1))
