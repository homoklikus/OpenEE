#!/usr/bin/env python3
"""OpenEE – wydzielenie warstwy localization/pl (teksty + głosy) z instalacji społecznościowej, z referencją GOG.

Nic nie jest kopiowane: manifest zawiera wyłącznie ODNIESIENIA (instalacja, archiwum, wpis, SHA-256) oraz
powiązania z identyfikatorami gry. Tylko odczyt obu instalacji.

Dowody powiązań (bez dopasowywania po podobieństwie nazw):
  * głosy jednostek/postaci: ten sam klucz wpisu w data.ssa w obu instalacjach + dbsounds (ścieżka → ID)
    + dbobjects (pola Creation/Action/Selection/Death sound → ID dźwięku),
  * narracja kampanii: ten sam klucz wpisu w archiwum kampanii,
  * scenariusze: pozycja na liście campaigns/*_scenariolist.txt obu wersji + porównanie terenu (kawałek 4),
  * cywilizacje: identyczna treść pliku poza polem nazwy,
  * teksty: identyfikatory tabel napisów (RT_STRING) w Language.dll.
Użycie: lokalizacja_pl.py <inst_GOG> <inst_społ> <porownanie.json> <katalog_wyjściowy>"""
import hashlib, json, os, struct, sys, collections, wave, io
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, db, scn, dcl

GRY = {"ee": "Empire Earth", "aoc": "Empire Earth - The Art of Conquest"}
POLA_DZWIEKU = ["Creation sound", "Action sound 1", "Action sound 2", "Selection sound 1", "Selection sound 2", "Death sound"]


def sha(b):
    return hashlib.sha256(b).hexdigest()


def info_wav(b):
    try:
        w = wave.open(io.BytesIO(b))
        return {"kanaly": w.getnchannels(), "bity": 8 * w.getsampwidth(), "hz": w.getframerate(),
                "sekundy": round(w.getnframes() / w.getframerate(), 3)}
    except Exception as e:
        return {"blad": str(e)[:60]}


def napisy_dll(path):
    import pefile
    pe = pefile.PE(path)
    out = {}
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != 6:   # RT_STRING
            continue
        for blk in t.directory.entries:
            for lang in blk.directory.entries:
                d = pe.get_data(lang.data.struct.OffsetToData, lang.data.struct.Size)
                p = 0
                for i in range(16):
                    n = struct.unpack_from("<H", d, p)[0]; p += 2
                    s = d[p:p + 2 * n].decode("utf-16-le", "replace"); p += 2 * n
                    if n:
                        out[(blk.id - 1) * 16 + i] = s
    return out


def main():
    R, S, porp, out = sys.argv[1:5]
    por = json.load(open(porp))
    os.makedirs(out, exist_ok=True)
    man = {"jezyk": "pl", "opis": "Warstwa localization/pl – odniesienia do zasobów z instalacji społecznościowej",
           "zrodla": {"pl": "instalacja społecznościowa (NeoEE Setup 1.7.2, komponent language\\pl)",
                      "en": "instalacja referencyjna GOG 2.0.0.2974 v3 (zweryfikowana hashdb)"},
           "prawa": "Nagrania i teksty są własnością ich właścicieli; manifest nie zawiera danych – OpenEE odczytuje je "
                    "z instalacji użytkownika. Nie dołączać do publicznych pakietów.",
           "glosy": [], "glosy_bez_wersji_pl": [], "narracja_kampanii": [], "narracja_brak_pl": [],
           "scenariusze": [], "cywilizacje": [], "grafika_z_tekstem": [], "teksty": {}}
    # --- tabele (AoC – używane przez profil AoC; EE korzysta z tych samych ścieżek dźwięków) ---
    AR = ssa.ArchiwumSSA(os.path.join(R, GRY["aoc"], "Data", "data.ssa"))
    snd = db.dekoduj(AR.czytaj("db/dbsounds.dat"), "dbsounds")
    obj = db.dekoduj(AR.czytaj("db/dbobjects.dat"), "dbobjects")
    sciezka_id = {}
    for r in snd:
        if r["Pathname"]:
            sciezka_id.setdefault(r["Pathname"].replace("\\", "/").lower(), []).append((r["ID"], r["Name"], r["Unknown"], r["Unknown#2"]))
    uzycia = collections.defaultdict(list)
    for o in obj:
        for f in POLA_DZWIEKU:
            if o.get(f, -1) >= 0:
                uzycia[o[f]].append({"obiekt_id": o["ID"], "obiekt": o["Name"], "pole": f})
    # --- głosy z data.ssa ---
    for g in ("ee", "aoc"):
        rel = f"{GRY[g]}/Data/data.ssa"
        a = por["archiwa"][rel]
        Ar = ssa.ArchiwumSSA(os.path.join(R, rel)); As = ssa.ArchiwumSSA(os.path.join(S, rel))
        zmienione = {x["wpis"] for x in a["zmienione"]}
        for k in sorted(zmienione):
            if not k.startswith("sounds/"):
                continue
            en, pl = Ar.czytaj(k), As.czytaj(k)
            ids = sciezka_id.get(k, [])
            wpis = {"klucz": k, "archiwum": rel, "gra": g, "sha256_pl": sha(pl), "sha256_en": sha(en),
                    "pl": info_wav(pl), "en": info_wav(en),
                    "dzwieki_db": [{"id": i, "nazwa": n, "kat": [u1, u2]} for i, n, u1, u2 in ids],
                    "uzycie": [u for i, *_ in ids for u in uzycia.get(i, [])]}
            wpis["rodzaj"] = "glos" if ids and all(u1 == 2 and u2 == 3 for _, _, u1, u2 in ids) else "dzwiek_zmieniony_nieglosowy?"
            man["glosy"].append(wpis)
        # wpisy dźwiękowe z kategorii (2,3) z opisem rozpoczynającym się od 'D' (konwencja dbsounds dla dialogów), bez zmian
        for k in sorted(Ar.wpisy):
            if k.startswith("sounds/") and k.endswith(".wav") and k not in zmienione:
                ids = sciezka_id.get(k, [])
                if ids and any(u1 == 2 and u2 == 3 and n[:1] in ("D", "d") for _, n, u1, u2 in ids):
                    man["glosy_bez_wersji_pl"].append({"klucz": k, "archiwum": rel, "dzwieki_db": [{"id": i, "nazwa": n} for i, n, *_ in ids],
                                                       "uwaga": "brak zmiany w wersji PL – nagranie EN/obce/okrzyk; odtwarzane z wersji oryginalnej"})
    # --- kampanie ---
    for rel, a in por["archiwa"].items():
        if "/Campaigns/" not in rel or not a["zmienione"] and not a["tylko_spol"]:
            continue
        Ar = ssa.ArchiwumSSA(os.path.join(R, rel)); As = ssa.ArchiwumSSA(os.path.join(S, rel))
        kamp = os.path.basename(rel)
        for x in a["zmienione"]:
            k = x["wpis"]
            if k.endswith(".mp3"):
                man["narracja_kampanii"].append({"kampania": kamp, "klucz": k, "archiwum": rel,
                                                 "sha256_pl": sha(As.czytaj(k)), "sha256_en": sha(Ar.czytaj(k))})
            elif k.endswith(".jpg"):
                man["grafika_z_tekstem"].append({"archiwum": rel, "klucz": k, "uwaga": "obraz kampanii różny w PL (prawdopodobnie tekst)"})
        for k in a["tylko_ref"]:
            if k.endswith(".mp3"):
                man["narracja_brak_pl"].append({"kampania": kamp, "klucz": k, "archiwum": rel, "zastepstwo": "en"})
        # scenariusze wg listy kampanii
        def lista(A):
            kk = [k for k in A.wpisy if k.startswith("campaigns/") and k.endswith(".txt")][0]
            t = A.czytaj(kk)
            import re as _re
            # lista: nazwy plików *.scn w kolejności kampanii (między nimi pola długości)
            nazwy = [m.decode("cp1250").strip().lower() for m in _re.findall(rb"[\x20-\xff]+?\.scn", t, _re.I)]
            return nazwy
        try:
            le, lp = lista(Ar), lista(As)
        except Exception as e:
            le, lp = [], []
        for i, (ne, np_) in enumerate(zip(le, lp)):
            ke, kp = f"scenarios/een1ve1s_{ne}", f"scenarios/een1ve1s_{np_}"
            r = {"kampania": kamp, "pozycja": i + 1, "en": ke, "pl": kp}
            if ke in Ar.wpisy and kp in As.wpisy:
                try:
                    te = [c for c in scn.kawalki(Ar.czytaj(ke)) if c["tag"] == 4][0]["surowe"]
                    tp = [c for c in scn.kawalki(As.czytaj(kp)) if c["tag"] == 4][0]["surowe"]
                    r["teren_identyczny"] = sha(dcl.maybe_unpack(te)) == sha(dcl.maybe_unpack(tp))
                except Exception as e:
                    r["teren_identyczny"] = None; r["uwaga"] = repr(e)[:80]
            else:
                r["blad"] = "brak wpisu"
            man["scenariusze"].append(r)
    # --- cywilizacje i grafika AoC ---
    rel = f"{GRY['aoc']}/Data/data.ssa"
    a = por["archiwa"][rel]
    Ar = ssa.ArchiwumSSA(os.path.join(R, rel)); As = ssa.ArchiwumSSA(os.path.join(S, rel))
    def reszta(b):
        n = struct.unpack_from("<I", b, 0)[0]; return b[4 + n:]
    en_civ = {sha(reszta(Ar.czytaj(k))): k for k in a["tylko_ref"] if k.startswith("civilizations/")}
    for k in a["tylko_spol"]:
        if k.startswith("civilizations/"):
            b = As.czytaj(k); n = struct.unpack_from("<I", b, 0)[0]
            man["cywilizacje"].append({"pl": k, "nazwa_pl": b[4:4 + n].decode("cp1250"), "en": en_civ.get(sha(reszta(b))),
                                       "dowod": "identyczna treść poza nazwą" if sha(reszta(b)) in en_civ else "BRAK odpowiednika"})
    for x in a["zmienione"]:
        if x["wpis"].startswith("textures/"):
            man["grafika_z_tekstem"].append({"archiwum": rel, "klucz": x["wpis"], "uwaga": "ekran tytułowy/powitalny – inny rozmiar (256×256×4 vs 256×256×3)"})
    # --- teksty Language.dll ---
    for g in ("ee", "aoc"):
        e = napisy_dll(os.path.join(R, GRY[g], "Language.dll")); p = napisy_dll(os.path.join(S, GRY[g], "Language.dll"))
        wsp = set(e) & set(p)
        man["teksty"][g] = {"plik": f"{GRY[g]}/Language.dll", "napisy_en": len(e), "napisy_pl": len(p),
                           "wspolne_id": len(wsp), "rozne_tresci": sum(1 for i in wsp if e[i] != p[i]),
                           "tylko_en": sorted(set(e) - set(p))[:200], "tylko_pl": sorted(set(p) - set(e))[:200],
                           "przyklady": {str(i): [e[i], p[i]] for i in sorted(i for i in wsp if e[i] != p[i])[200:212]}}
    json.dump(man, open(os.path.join(out, "manifest.json"), "w"), ensure_ascii=False, indent=1)
    gl = man["glosy"]
    print("głosy PL:", len(gl), collections.Counter(g["rodzaj"] for g in gl), "z użyciem w dbobjects:", sum(1 for g in gl if g["uzycie"]))
    print("głosy bez PL (kat. dialog):", len(man["glosy_bez_wersji_pl"]))
    print("narracja PL:", len(man["narracja_kampanii"]), "brak PL:", len(man["narracja_brak_pl"]))
    print("scenariusze:", len(man["scenariusze"]), "teren identyczny:", sum(1 for s in man["scenariusze"] if s.get("teren_identyczny")))
    print("cywilizacje:", len(man["cywilizacje"]), "dopasowane:", sum(1 for c in man["cywilizacje"] if c["en"]))
    for g, t in man["teksty"].items():
        print("teksty", g, {k: (v if not isinstance(v, (list, dict)) else len(v)) for k, v in t.items()})


if __name__ == "__main__":
    main()
