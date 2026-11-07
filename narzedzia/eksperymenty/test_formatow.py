#!/usr/bin/env python3
"""Test czytników formatów na prawdziwych archiwach (tylko odczyt).
Użycie: test_formatow.py <katalog_instalacji> <wynik.json> [limit_na_typ]"""
import json, os, sys, time, traceback, collections
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty import ssa, dcl, sst, cem

ARCH = ["Empire Earth/Data/data.ssa", "Empire Earth - The Art of Conquest/Data/data.ssa"]


def main():
    root, out = sys.argv[1], sys.argv[2]
    limit = int(sys.argv[3]) if len(sys.argv) > 3 else 10 ** 9
    wybrane = [ARCH[int(sys.argv[4])]] if len(sys.argv) > 4 else ARCH
    wyn = {}
    for a in wybrane:
        A = ssa.ArchiwumSSA(os.path.join(root, a))
        st = collections.defaultdict(lambda: collections.Counter())
        bledy = []
        dodatki = collections.Counter()
        cnt = collections.Counter()
        t0 = time.time()
        for k, w in A.wpisy.items():
            ext = k.rsplit(".", 1)[-1]
            if ext not in ("sst", "cem", "tga", "dat"):
                continue
            if cnt[ext] >= limit:
                continue
            cnt[ext] += 1
            try:
                raw = A.czytaj_surowe(k)
                pk = dcl.is_pk01(raw)
                b = dcl.maybe_unpack(raw)
                st[ext]["pk01" if pk else "surowe"] += 1
                if ext == "sst":
                    s = sst.czytaj_sst(b)
                    i0 = s["obrazy"][0]
                    st[ext][f"klatki={s['naglowek']['klatki']}"] += 1
                    st[ext][f"bpp={i0['bpp']}"] += 1
                    st[ext][f"b1={s['naglowek']['b1']}"] += 1
                    if s["reszta"]:
                        st[ext]["reszta>0"] += 1
                    if (i0["w"], i0["h"]) != (s["naglowek"]["w"], s["naglowek"]["h"]):
                        st[ext]["wymiar_naglowka≠TGA"] += 1
                elif ext == "tga":
                    i = sst.czytaj_tga(b)
                    st[ext][f"bpp={i['bpp']}"] += 1
                elif ext == "cem":
                    m = cem.czytaj_cem(b)
                    pr = cem.kontrola(m)
                    st[ext][f"lod={m['liczby']['lod']}"] += 1
                    st[ext][f"klatki>1" if m['liczby']['klatki'] > 1 else "klatki=1"] += 1
                    st[ext][f"potomne={m['liczby']['potomne']}"] += 1
                    if m["reszta_bajtow"]:
                        st[ext]["reszta>0"] += 1
                        dodatki[k] = m["reszta_bajtow"]
                    if pr:
                        st[ext]["problemy"] += 1
                        bledy.append((k, pr[:3]))
                    for mt in m["materialy"]:
                        dodatki["mat:" + mt["nazwa"][:20]] += 0
                elif ext == "dat":
                    st[ext]["ok"] += 1
            except NotImplementedError as ex:
                st[ext]["nieobslugiwane"] += 1
                bledy.append((k, "NIEOBSŁUGIWANE: " + str(ex)[:150]))
            except Exception as ex:
                st[ext]["BLAD"] += 1
                bledy.append((k, repr(ex)[:200]))
        wyn[a] = {"czas_s": round(time.time() - t0, 1), "statystyki": {k: dict(v) for k, v in st.items()},
                  "bledy": bledy[:50], "liczba_bledow": len(bledy),
                  "cem_z_reszta": dict(list(((k, v) for k, v in dodatki.items() if not k.startswith("mat:")))[:30])}
        A.zamknij()
        print(a, json.dumps(wyn[a]["statystyki"], ensure_ascii=False), "błędy:", len(bledy), wyn[a]["czas_s"], "s")
    json.dump(wyn, open(out, "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
