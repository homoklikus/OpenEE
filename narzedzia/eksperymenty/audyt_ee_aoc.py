#!/usr/bin/env python3
"""OpenEE – etap 11: audyt Empire Earth 1.0 kontra The Art of Conquest w JEDNEJ instalacji (WYŁĄCZNIE ODCZYT).

Instalacja (np. GOG „Empire Earth Gold”) zawiera dwa katalogi gier: „Empire Earth” i „Empire Earth - The Art of
Conquest”. Narzędzie porównuje je i zapisuje wynik (liczby, nazwy, skróty – bez treści zasobów) do pliku JSON:
  1. drzewa katalogów (pliki tylko w EE / tylko w AoC / wspólne identyczne / wspólne różne),
  2. archiwa Data/data.ssa (wpisy po kluczu: tylko EE / tylko AoC / identyczne / różne; grupy wg katalogu i rozszerzenia),
  3. tabele db/*.dat: rozmiar, wariant formatu, liczba rekordów; dbobjects ↔ dbgraphics (powiązania w obrębie
     tej samej gry), wspólne identyfikatory i zgodność nazw,
  4. archiwa kampanii: scenariusze i wersje formatu SCN,
  5. epoki i technologie (dbtechtree),
  6. Language.dll: identyfikatory napisów (tylko EE / tylko AoC / wspólne zgodne / różne),
  7. skrypty map .rmv,
  8. pliki PE (exe/dll): wersja, znacznik czasu, skrót, eksporty, importowane biblioteki.
Użycie: audyt_ee_aoc.py <katalog_instalacji> <wynik.json>
"""
import hashlib, json, os, struct, sys, collections

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # narzedzia/ – eeformaty
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # narzedzia/eksperymenty/
from eeformaty.ssa import ArchiwumSSA            # noqa: E402
from eeformaty import db, epoki, scn             # noqa: E402

EE, AOC = "Empire Earth", "Empire Earth - The Art of Conquest"


def sha(b):
    return hashlib.sha1(b).hexdigest()


def sha_pliku(p):
    h = hashlib.sha1()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def drzewo(kor):
    out = {}
    for d, _, pliki in os.walk(kor):
        for f in pliki:
            p = os.path.join(d, f)
            rel = os.path.relpath(p, kor).replace("\\", "/")
            out[rel.lower()] = {"rel": rel, "rozmiar": os.path.getsize(p), "sha1": sha_pliku(p)}
    return out


def porownaj_slowniki(a, b, rowne):
    ka, kb = set(a), set(b)
    wsp = ka & kb
    same = sorted(k for k in wsp if rowne(a[k], b[k]))
    return {"tylko_ee": sorted(ka - kb), "tylko_aoc": sorted(kb - ka), "identyczne": same,
            "rozne": sorted(wsp - set(same))}


def grupa(k):
    cz = k.split("/")
    return (cz[0] if len(cz) > 1 else "(korzeń)") + " *" + os.path.splitext(k)[1]


def zlicz_grupy(klucze):
    return dict(sorted(collections.Counter(grupa(k) for k in klucze).items()))


def pe_info(p):
    import pefile
    pe = pefile.PE(p, fast_load=False)
    w = {"rozmiar": os.path.getsize(p), "sha1": sha_pliku(p), "znacznik_czasu": pe.FILE_HEADER.TimeDateStamp,
         "maszyna": hex(pe.FILE_HEADER.Machine)}
    try:
        for fi in pe.FileInfo or []:
            for e in fi:
                for st in getattr(e, "StringTable", []):
                    for k, v in st.entries.items():
                        w.setdefault("wersja", {})[k.decode(errors="replace")] = v.decode(errors="replace")
    except Exception as ex:  # pragma: no cover
        w["wersja_blad"] = repr(ex)
    if hasattr(pe, "DIRECTORY_ENTRY_EXPORT"):
        w["eksporty"] = sorted((s.name or b"#%d" % s.ordinal).decode(errors="replace") for s in pe.DIRECTORY_ENTRY_EXPORT.symbols)
    if hasattr(pe, "DIRECTORY_ENTRY_IMPORT"):
        w["importy"] = sorted(i.dll.decode(errors="replace").lower() for i in pe.DIRECTORY_ENTRY_IMPORT)
    return w


def napisy_dll(p):
    import pefile
    pe = pefile.PE(p)
    wyn = {}
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != 6:          # RT_STRING
            continue
        for blok in t.directory.entries:
            for jez in blok.directory.entries:
                d = pe.get_data(jez.data.struct.OffsetToData, jez.data.struct.Size)
                q = 0
                for i in range(16):
                    if q + 2 > len(d):
                        break
                    n = struct.unpack_from("<H", d, q)[0]; q += 2
                    s = d[q:q + 2 * n].decode("utf-16-le", "replace"); q += 2 * n
                    if n:
                        wyn[(blok.id - 1) * 16 + i] = s
    return wyn


def main():
    inst, wyj = sys.argv[1], sys.argv[2]
    R = {"instalacja": inst}
    kat = {g: os.path.join(inst, g) for g in (EE, AOC)}

    # 1. drzewa katalogów
    dr = {g: drzewo(kat[g]) for g in kat}
    c = porownaj_slowniki(dr[EE], dr[AOC], lambda x, y: x["sha1"] == y["sha1"])
    R["drzewa"] = {"pliki": {g: len(dr[g]) for g in dr},
                   "tylko_ee": [dr[EE][k]["rel"] for k in c["tylko_ee"]],
                   "tylko_aoc": [dr[AOC][k]["rel"] for k in c["tylko_aoc"]],
                   "wspolne_identyczne": [dr[EE][k]["rel"] for k in c["identyczne"]],
                   "wspolne_rozne": [{"rel": dr[EE][k]["rel"], "ee": dr[EE][k]["rozmiar"], "aoc": dr[AOC][k]["rozmiar"]}
                                     for k in c["rozne"]]}

    # 2. data.ssa
    ar = {g: ArchiwumSSA(os.path.join(kat[g], "Data", "data.ssa")) for g in kat}
    sk = {g: {k: (w.rozmiar, sha(ar[g].czytaj_surowe(k))) for k, w in ar[g].wpisy.items()} for g in ar}
    c = porownaj_slowniki(sk[EE], sk[AOC], lambda x, y: x == y)
    R["data_ssa"] = {"wpisy": {g: len(sk[g]) for g in sk}, "naglowek": {g: [ar[g].wersja] for g in ar},
                     "liczby": {k: len(v) for k, v in c.items()},
                     "grupy": {k: zlicz_grupy(v) for k, v in c.items()},
                     "tylko_ee": c["tylko_ee"], "tylko_aoc_przyklady": c["tylko_aoc"][:200], "rozne": c["rozne"]}
    R["data_ssa"]["aoc_zawiera_wszystkie_klucze_ee"] = not c["tylko_ee"]

    # 3. tabele db
    tab = {}
    for g in ar:
        for k in ar[g].wpisy:
            if k.startswith("db/") and k.endswith(".dat"):
                tab.setdefault(k[3:-4], {})[g] = ar[g].czytaj(k)
    R["db"] = {}
    dek = {}
    for t, d in sorted(tab.items()):
        r = {}
        for g, b in d.items():
            e = {"rozmiar": len(b), "N": struct.unpack_from("<I", b, 0)[0] if len(b) >= 4 else None}
            if t in db.OBSLUGIWANE:
                try:
                    e["wariant"] = db.rozpoznaj(b, t)
                    dek[(t, g)] = db.dekoduj(b, t)
                except Exception as ex:
                    e["blad"] = str(ex)[:200]
            elif t == "dbtechtree":
                e["wariant"] = epoki.wariant_techtree(b)
            elif t == "dbeffects":
                e["wariant"] = epoki.wariant_efektow(b)
            r["ee" if g == EE else "aoc"] = e
        r["identyczne_bajty"] = len(d) == 2 and d[EE] == d[AOC]
        R["db"][t] = r
    # dbobjects ↔ dbgraphics w obrębie gry
    pow_ = {}
    for g in (EE, AOC):
        ob = dek.get(("dbobjects", g), []); gr = dek.get(("dbgraphics", g), [])
        idg = {int(x["ID"]) for x in gr}
        braki = sorted({int(o["Graphic ID"]) for o in ob if int(o["Graphic ID"]) >= 0 and int(o["Graphic ID"]) not in idg})
        typy = collections.Counter(int(o["Object type"]) for o in ob)
        pow_["ee" if g == EE else "aoc"] = {
            "obiekty": len(ob), "grafiki": len(gr), "id_obiektow": [min(int(o["ID"]) for o in ob), max(int(o["ID"]) for o in ob)] if ob else [],
            "graphic_id_bez_rekordu": braki, "budynki": sum(1 for o in ob if int(o["Is building?"])),
            "typy_obiektow": dict(sorted(typy.items()))}
    obe = {g: {int(o["ID"]): o for o in dek.get(("dbobjects", g), [])} for g in (EE, AOC)}
    wsp = sorted(set(obe[EE]) & set(obe[AOC]))
    pow_["wspolne_id"] = len(wsp)
    pow_["tylko_ee_id"] = sorted(set(obe[EE]) - set(obe[AOC]))
    pow_["tylko_aoc_id"] = len(set(obe[AOC]) - set(obe[EE]))
    pow_["wspolne_id_inna_nazwa"] = [i for i in wsp if obe[EE][i]["Name"] != obe[AOC][i]["Name"]]
    pow_["wspolne_id_inna_grafika"] = [i for i in wsp if obe[EE][i]["Graphic ID"] != obe[AOC][i]["Graphic ID"]]
    pola = [f[0] for f in db.uklad("dbobjects", "ee")]
    rozne_pola = collections.Counter()
    for i in wsp:
        for f in pola:
            if obe[EE][i][f] != obe[AOC][i][f]:
                rozne_pola[f] += 1
    pow_["wspolne_id_pola_rozne"] = dict(rozne_pola.most_common(40))
    pow_["wspolne_id_z_roznymi_statystykami"] = sum(1 for i in wsp if any(obe[EE][i][f] != obe[AOC][i][f] for f in
                                                   ("Health", "Attack", "Speed", "Max range", "Line of sight")))
    gre = {g: {int(x["ID"]): x for x in dek.get(("dbgraphics", g), [])} for g in (EE, AOC)}
    wg = set(gre[EE]) & set(gre[AOC])
    pow_["dbgraphics_wspolne_id"] = len(wg)
    pow_["dbgraphics_wspolne_inny_model"] = sorted(i for i in wg if gre[EE][i].get("Model path") != gre[AOC][i].get("Model path"))
    R["obiekty_grafiki"] = pow_

    # 5. epoki i technologie
    ep = {}
    for g in (EE, AOC):
        b = tab.get("dbtechtree", {}).get(g)
        if b is None:
            continue
        t = epoki.techtree(b)
        ep["ee" if g == EE else "aoc"] = {"technologie": len(t), "epoki": sorted({x["epoka"] for x in t if "epoka" in x})}
    R["epoki"] = ep

    # 4. kampanie i scenariusze
    kamp = {}
    for g in (EE, AOC):
        kc = os.path.join(kat[g], "Data", "Campaigns")
        for f in sorted(os.listdir(kc)) if os.path.isdir(kc) else []:
            if not f.lower().endswith(".ssa"):
                continue
            a = ArchiwumSSA(os.path.join(kc, f))
            wersje = collections.Counter()
            for k in a.wpisy:
                if k.endswith(".scn"):
                    try:
                        kw = scn.kawalki(a.czytaj(k))
                        wersje[str([x["minor"] for x in kw if x["tag"] == 5][0])] += 1
                    except Exception:
                        wersje["blad"] += 1
            kamp.setdefault("ee" if g == EE else "aoc", {})[f] = {
                "wpisy": len(a.wpisy), "scenariusze": sum(wersje.values()), "wersje_scn": dict(wersje),
                "sha1": sha_pliku(os.path.join(kc, f))}
    R["kampanie"] = kamp
    # luźne scenariusze w Data/Scenarios
    for g in (EE, AOC):
        ks = os.path.join(kat[g], "Data", "Scenarios")
        if os.path.isdir(ks):
            wersje = collections.Counter()
            for f in os.listdir(ks):
                if f.lower().endswith(".scn"):
                    try:
                        kw = scn.kawalki(scn.maybe_unpack(open(os.path.join(ks, f), "rb").read()))
                        wersje[str([x["minor"] for x in kw if x["tag"] == 5][0])] += 1
                    except Exception:
                        wersje["blad"] += 1
            R.setdefault("scenariusze_luzne", {})["ee" if g == EE else "aoc"] = dict(wersje)

    # 6. Language.dll
    ld = {g: napisy_dll(os.path.join(kat[g], "Language.dll")) for g in kat}
    c = porownaj_slowniki(ld[EE], ld[AOC], lambda x, y: x == y)
    R["language_dll"] = {"napisy": {g: len(ld[g]) for g in ld}, "liczby": {k: len(v) for k, v in c.items()},
                         "zakres_id": {g: [min(ld[g]), max(ld[g])] for g in ld if ld[g]},
                         "tylko_ee_id": c["tylko_ee"][:300], "rozne_id": c["rozne"][:300]}

    # 7. skrypty .rmv (luźne w drzewie)
    rmv = {g: {k: v for k, v in dr[g].items() if k.endswith(".rmv")} for g in dr}
    c = porownaj_slowniki(rmv[EE], rmv[AOC], lambda x, y: x["sha1"] == y["sha1"])
    R["rmv"] = {"pliki": {g: len(rmv[g]) for g in rmv}, "tylko_ee": [rmv[EE][k]["rel"] for k in c["tylko_ee"]],
                "tylko_aoc": [rmv[AOC][k]["rel"] for k in c["tylko_aoc"]],
                "identyczne": len(c["identyczne"]), "rozne": [rmv[EE][k]["rel"] for k in c["rozne"]]}
    rmv_ssa = {g: sorted(k for k in ar[g].wpisy if k.endswith(".rmv")) for g in ar}
    R["rmv"]["w_data_ssa"] = {g: len(v) for g, v in rmv_ssa.items()}

    # 8. PE
    pe = {}
    for g in kat:
        for f in sorted(os.listdir(kat[g])):
            if f.lower().endswith((".exe", ".dll")):
                try:
                    pe.setdefault(f.lower(), {})["ee" if g == EE else "aoc"] = pe_info(os.path.join(kat[g], f))
                except Exception as ex:
                    pe.setdefault(f.lower(), {})["ee" if g == EE else "aoc"] = {"blad": repr(ex)[:200]}
    for f, d in pe.items():
        if "ee" in d and "aoc" in d and "eksporty" in d["ee"] and "eksporty" in d["aoc"]:
            d["eksporty_tylko_ee"] = sorted(set(d["ee"]["eksporty"]) - set(d["aoc"]["eksporty"]))
            d["eksporty_tylko_aoc"] = sorted(set(d["aoc"]["eksporty"]) - set(d["ee"]["eksporty"]))
            d["identyczne"] = d["ee"]["sha1"] == d["aoc"]["sha1"]
            for g in ("ee", "aoc"):
                d[g]["eksporty_liczba"] = len(d[g].pop("eksporty"))
    R["pe"] = pe

    os.makedirs(os.path.dirname(os.path.abspath(wyj)), exist_ok=True)
    json.dump(R, open(wyj, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print(json.dumps({"drzewa": R["drzewa"]["pliki"], "data_ssa": R["data_ssa"]["liczby"],
                      "aoc_ma_wszystko_z_ee": R["data_ssa"]["aoc_zawiera_wszystkie_klucze_ee"],
                      "language": R["language_dll"]["liczby"], "rmv": R["rmv"]["pliki"], "epoki": R["epoki"]},
                     ensure_ascii=False))


if __name__ == "__main__":
    main()
