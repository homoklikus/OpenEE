#!/usr/bin/env python3
"""OpenEE – eksport danych do pierwszego testu graficznego (tylko odczyt instalacji EE).

Tworzy w katalogu cache OpenEE:
    teren.json            fragment terenu z autentycznego scenariusza kampanii
    tekstury/<warstwa>/   PNG tekstur terenu użytych we fragmencie (warstwa 'archiwum' = data.ssa,
                          warstwa 'luzne' = pliki Data/Textures, jeśli istnieją – nakładka HD)
    model.json + PNG      jeden budynek CEM z teksturą
    eksport.json          metadane: źródła, SHA-256, kontrole

Użycie: eksport_testu_graficznego.py <instalacja> <katalog_wyjściowy>
"""
import hashlib, json, os, struct, sys, math, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, scn, sst, cem
from PIL import Image

KAMPANIA = "Empire Earth - The Art of Conquest/Data/Campaigns/AOCRoman.ssa"
SCENARIUSZ = "żołnierze dla rzymu"
ARCH_EE = "Empire Earth/Data/data.ssa"
ARCH_AOC = "Empire Earth - The Art of Conquest/Data/data.ssa"
LUZNE_EE = "Empire Earth/Data/Textures"
MODEL = "models/bld_barracks_05.cem"
OKNO = 64


def sha(b):
    return hashlib.sha256(b).hexdigest()


def tereny_db(A):
    """dbterrain.dat: rekordy {napis tekstury (u32 długość + znaki), nazwa char[100], u32, u32 id}."""
    b = A.czytaj("db/dbterrain.dat")
    out = {}
    for m in re.finditer(re.escape(b"textures\\"), b):
        s = m.start()
        n = struct.unpack_from("<I", b, s - 4)[0]
        tex = b[s:s + n].decode("latin-1")
        nazwa = b[s + n:s + n + 100].split(b"\0")[0].decode("latin-1")
        _, tid = struct.unpack_from("<II", b, s + n + 100)
        baza = tex.split("\\")[-1].lower()
        if baza.endswith(".sst"):          # AoC zapisuje nazwy z rozszerzeniem, EE bez
            baza = baza[:-4]
        out[tid] = {"tekstura": baza, "nazwa": nazwa}
    return out


def png_z_sst(buf, sciezka_bez_rozszerzenia):
    if buf[1] == 0:   # bajt 1: SST = 1, TGA = typ mapy kolorów 0 → czysty TGA (AoC: textures/*.tga)
        img = sst.czytaj_tga(buf)
        s = {"obrazy": [img], "naglowek": {"w": img["w"], "h": img["h"], "klatki": 1}}
    else:
        s = sst.czytaj_sst(buf)
    pliki = []
    for i, img in enumerate(s["obrazy"]):
        tryb = "BGRA" if img["bpp"] == 32 else "BGR"
        im = Image.frombytes("RGBA" if img["bpp"] == 32 else "RGB", (img["w"], img["h"]), img["px"], "raw", tryb)
        if not img["top"]:
            im = im.transpose(Image.FLIP_TOP_BOTTOM)
        p = f"{sciezka_bez_rozszerzenia}{'' if i == 0 else f'_obraz{i}'}.png"
        im.convert("RGBA").save(p)
        pliki.append(os.path.basename(p))
    return pliki, s["naglowek"]


def main():
    root, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    meta = {"zrodla": {}, "kontrole": {}}

    # --- teren ---
    K = ssa.ArchiwumSSA(os.path.join(root, KAMPANIA))
    klucz = [k for k in K.wpisy if k.endswith(".scn") and SCENARIUSZ in k][0]
    d = K.czytaj(klucz)
    meta["zrodla"]["scenariusz"] = {"archiwum": KAMPANIA, "wpis": K.wpisy[klucz].nazwa, "sha256": sha(d)}
    ch = scn.kawalki(d)
    t = scn.teren([c for c in ch if c["tag"] == 4][0]["surowe"])
    A_, B_ = t["A"], t["B"]
    rp, rv = t["wiersze_pol"], t["wiersze_punktow"]
    # indeksy liniowe
    base_t, base_v = [], []
    acc = 0
    for lo, hi in rp:
        base_t.append(acc); acc += hi - lo + 1
    acc = 0
    for lo, hi in rv:
        base_v.append(acc); acc += hi - lo + 1

    def ti(r, c):
        lo, hi = rp[r]
        return base_t[r] + (c - lo) if lo <= c <= hi else None

    def vi(r, c):
        lo, hi = rv[r]
        return base_v[r] + (c - lo) if lo <= c <= hi else None

    # kontrola: f10 pola = min wysokości narożników (r,c),(r,c+1),(r+1,c),(r+1,c+1)
    zgodne = niezgodne = 0
    for r in range(len(rp)):
        lo, hi = rp[r]
        for c in range(lo, hi + 1):
            hs = [t["wysokosc"][vi(rr, cc)] for rr, cc in ((r, c), (r, c + 1), (r + 1, c), (r + 1, c + 1))]
            if abs(min(hs) - t["f10"][ti(r, c)]) < 1e-5:
                zgodne += 1
            else:
                niezgodne += 1
    meta["kontrole"]["f10_rowne_min_naroznikow"] = {"zgodne": zgodne, "niezgodne": niezgodne}

    # wybór okna OKNO×OKNO o największej zmienności wysokości (całe wewnątrz rombu)
    N = A_ + B_
    best = None
    for r0 in range(0, N - OKNO, 4):
        for c0 in range(0, N - OKNO, 4):
            if any(ti(r, c) is None for r in (r0, r0 + OKNO - 1) for c in (c0, c0 + OKNO - 1)):
                continue
            ok = all(rp[r][0] <= c0 and rp[r][1] >= c0 + OKNO - 1 for r in range(r0, r0 + OKNO))
            if not ok:
                continue
            hs = [t["wysokosc"][vi(r, c)] for r in range(r0, r0 + OKNO + 1, 4) for c in range(c0, c0 + OKNO + 1, 4)]
            m = sum(hs) / len(hs)
            var = sum((h - m) ** 2 for h in hs) / len(hs)
            woda = sum(1 for h in hs if h < 0) / len(hs)
            score = var * (1.0 if 0.05 < woda < 0.5 else 0.3)
            if best is None or score > best[0]:
                best = (score, r0, c0)
    _, r0, c0 = best
    wys = [[t["wysokosc"][vi(r, c)] for c in range(c0, c0 + OKNO + 1)] for r in range(r0, r0 + OKNO + 1)]
    kl = [[t["klasa"][vi(r, c)] for c in range(c0, c0 + OKNO + 1)] for r in range(r0, r0 + OKNO + 1)]
    ter = [[t["teren"][ti(r, c)] for c in range(c0, c0 + OKNO)] for r in range(r0, r0 + OKNO)]
    fl = [[t["flagi"][ti(r, c)] for c in range(c0, c0 + OKNO)] for r in range(r0, r0 + OKNO)]
    uzyte = sorted({x for row in ter for x in row})

    # --- tekstury terenu ---
    E = ssa.ArchiwumSSA(os.path.join(root, ARCH_EE))
    AO = ssa.ArchiwumSSA(os.path.join(root, ARCH_AOC))
    db = tereny_db(AO)               # scenariusz kampanii AoC → tabela terenów AoC
    db_ee = tereny_db(E)
    meta["kontrole"]["dbterrain_aoc_vs_ee"] = {
        "tylko_aoc": sorted(set(db) - set(db_ee)),
        "rozne_tekstury": sorted(k for k in set(db) & set(db_ee) if db[k]["tekstura"] != db_ee[k]["tekstura"])}

    def znajdz(k):
        """Kolejność wyszukiwania AoC: archiwum AoC, potem archiwum EE (AoC korzysta z danych EE);
        dla tekstur najpierw .sst, potem .tga (AoC przechowuje część tekstur jako TGA)."""
        warianty = [k]
        if k.endswith(".sst"):
            warianty.append(k[:-4] + ".tga")
        for kk in warianty:
            for nazwa_arch, arch in (("aoc", AO), ("ee", E)):
                if kk in arch:
                    return f"{nazwa_arch}:{kk}", arch.czytaj(kk)
        return None, None
    tex_out = {}
    for warstwa in ("archiwum", "luzne"):
        os.makedirs(os.path.join(out, "tekstury", warstwa), exist_ok=True)
    # płaszczyzna wody: pierwsza klatka animacji textures/water_ocean_1.sst (EE); AoC 'water_oceanb' nie występuje w archiwach
    skad, b = znajdz("textures/water_ocean_1.sst")
    if b is not None:
        os.makedirs(os.path.join(out, "tekstury", "archiwum"), exist_ok=True)
        png_z_sst(b, os.path.join(out, "tekstury", "archiwum", "water_ocean_1"))
        meta["zrodla"]["woda"] = {"wpis": skad, "sha256_rozpakowane": sha(b)}
    for tid in uzyte:
        info = db.get(tid)
        if not info:
            tex_out[str(tid)] = {"blad": "brak w dbterrain"}
            continue
        wpis = {"nazwa": info["nazwa"], "baza": info["tekstura"], "warianty": {}}
        for v in (1, 2, 3, 4):
            nazwa = f"{info['tekstura']}_{v}"
            k = f"textures/{nazwa}.sst"
            skad, b = znajdz(k)
            if b is not None:
                pl, hdr = png_z_sst(b, os.path.join(out, "tekstury", "archiwum", nazwa))
                wpis["warianty"].setdefault("archiwum", []).append(pl[0])
                meta["zrodla"].setdefault("tekstury", {})[k] = {"archiwum": skad, "sha256_rozpakowane": sha(b), "w": hdr["w"], "h": hdr["h"]}
            lp = os.path.join(root, LUZNE_EE, f"{nazwa}.sst")
            if os.path.exists(lp):
                b = open(lp, "rb").read()
                pl, hdr = png_z_sst(b, os.path.join(out, "tekstury", "luzne", nazwa))
                wpis["warianty"].setdefault("luzne", []).append(pl[0])
                meta["zrodla"].setdefault("tekstury_luzne", {})[f"{LUZNE_EE}/{nazwa}.sst"] = {"sha256": sha(b), "w": hdr["w"], "h": hdr["h"]}
        tex_out[str(tid)] = wpis

    json.dump({"A": A_, "B": B_, "okno": {"r0": r0, "c0": c0, "n": OKNO}, "wysokosc": wys, "klasa": kl,
               "teren": ter, "flagi": fl, "tekstury": tex_out,
               "uwagi": ["Narożniki pola (r,c): punkty (r,c),(r,c+1),(r+1,c),(r+1,c+1) – potwierdzone kontrolą f10.",
                         "Wybór wariantu tekstury _1.._4 oraz UV 0..1 na pole – HIPOTEZA OpenEE (nieustalone w EE).",
                         "Skala pionowa względem boku pola – nieustalona; Godot stosuje współczynnik z konfiguracji."]},
              open(os.path.join(out, "teren.json"), "w"), ensure_ascii=False)

    # --- model ---
    _, b = znajdz(MODEL)
    m = cem.czytaj_cem(b)
    meta["zrodla"]["model"] = {"wpis": MODEL, "sha256_rozpakowane": sha(b), "kontrola": cem.kontrola(m)}
    fr = m["klatki"][0]
    v = fr["wierzcholki"]
    lod0 = m["lod"][0]
    mats = []
    for mt in m["materialy"]:
        o, n = mt["zakresy_lod"][0]
        tex = mt["tekstura"].lower()
        k = f"textures/{tex}.sst"
        pngs = []
        skad, tb = znajdz(k)
        if tb is not None:
            pngs, hdr = png_z_sst(tb, os.path.join(out, f"model_{tex}"))
            meta["zrodla"].setdefault("tekstury_modelu", {})[k] = {"sha256_rozpakowane": sha(tb), "obrazy": len(pngs)}
        mats.append({"nazwa": mt["nazwa"], "tekstura": tex, "png": pngs,
                     "indeksy": list(lod0[3 * o:3 * (o + n)])})
    json.dump({"zrodlo": MODEL, "nazwa": m["nazwa"], "uklad": "Z w górę (CEM) – Godot: (x, z, -y)",
               "pozycje": [v[i:i + 3] for i in range(0, len(v), 8)],
               "normalne": [v[i + 3:i + 6] for i in range(0, len(v), 8)],
               "uv": [v[i + 6:i + 8] for i in range(0, len(v), 8)],
               "materialy": mats}, open(os.path.join(out, "model.json"), "w"))
    meta["teren"] = {"A": A_, "B": B_, "okno": [r0, c0, OKNO], "uzyte_tereny": {str(x): db.get(x, {}).get("nazwa") for x in uzyte},
                     "wys_min": min(min(r) for r in wys), "wys_max": max(max(r) for r in wys)}
    json.dump(meta, open(os.path.join(out, "eksport.json"), "w"), ensure_ascii=False, indent=1)
    print(json.dumps(meta["kontrole"], ensure_ascii=False), meta["teren"])


if __name__ == "__main__":
    main()
