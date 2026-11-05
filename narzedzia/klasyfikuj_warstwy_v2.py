#!/usr/bin/env python3
"""OpenEE etap 2 – klasyfikacja warstw z użyciem instalacji REFERENCYJNEJ (GOG, zweryfikowanej hashdb).

Wejście: inwentarz referencyjny, weryfikacja hashdb, porównanie instalacji, manifest etapu 1 (dowody dla
plików istniejących tylko w instalacji społecznościowej). Wyjście: manifest_zasobow.json/.csv (v2) dla
instalacji społecznościowej oraz manifest_referencyjny.json.

Zasada: plik identyczny (SHA-256) z referencją → vanilla/aoc (pewność wysoka, dowód D-REF).
Plik zmieniony → warstwa tylko na podstawie dowodu w treści (sekcja .neoee, polskie teksty, wpisy archiwum).
Plik tylko w instalacji społecznościowej → dowody z etapu 1 (D-PE, D-STR, D-DIR, D-OVR …).
Użycie: klasyfikuj_warstwy_v2.py <katalog OpenEE/audyt>"""
import csv, json, os, sys, collections

EE, AOC = "empire earth/", "empire earth - the art of conquest/"


def gra(p):
    return "aoc" if p.lower().startswith(AOC) else "vanilla"


def main():
    au = sys.argv[1]
    ref = json.load(open(os.path.join(au, "referencja_gog/inwentarz_referencyjny.json")))["pliki"]
    hdb = json.load(open(os.path.join(au, "referencja_gog/weryfikacja_hashdb.json")))
    por = json.load(open(os.path.join(au, "porownanie/porownanie_instalacji.json")))
    v1 = {e["sciezka"]: e for e in json.load(open(os.path.join(au, "manifest_zasobow_etap1.json")))["pliki"]}
    zm = {x["sciezka"]: x for x in por["pliki"]["zmienione"]}
    ident = set(por["pliki"]["identyczne"])
    arch = por["archiwa"]
    platforma_gog = set(hdb["pliki_spoza_hashdb"])

    # --- manifest referencyjny ---
    mref = []
    for p in ref:
        s = p["sciezka"]
        if s in platforma_gog or s.lower().startswith(("goggame", "gog.ico", "support.ico", "unins000", "launch empire")):
            w, d = "platforma_gog", "plik instalatora/klienta GOG (spoza hashdb lub metadane GOG)"
        elif s.lower().endswith(("ddraw.dll", "dxcfg.exe", "dxcfg.ini")):
            w, d = "platforma_gog", "D-REF: wrapper DirectDraw dołączony przez GOG (dxcfg z 2023 r.) – nie część gry z 2001/2002"
        else:
            w, d = gra(s), "D-HASHDB: MD5 zgodne z goggame-1207658777.hashdb (build 58180155540805121)"
        mref.append({"sciezka": s, "rozmiar": p["rozmiar"], "sha256": p["sha256"], "warstwa": w,
                     "pewnosc": "wysoka", "dowody": [d]})
    json.dump({"opis": "Manifest instalacji referencyjnej GOG", "liczba_plikow": len(mref), "pliki": mref},
              open(os.path.join(au, "manifest_referencyjny.json"), "w"), ensure_ascii=False, indent=1)

    # --- manifest społeczności ---
    wyn = []
    for s, e1 in v1.items():
        e = {"sciezka": s, "rozmiar": e1["rozmiar"], "sha256": e1["sha256"], "warstwa": None, "pewnosc": None,
             "dowody": [], "uwagi": "", "warstwa_etap1": e1["warstwa"]}
        sl = s.lower()

        def ust(w, pew, *d, uw=""):
            e["warstwa"], e["pewnosc"] = w, pew
            e["dowody"] += list(d)
            e["uwagi"] = uw
        if s in ident:
            ust(gra(s), "wysoka", "D-REF: SHA-256 identyczne z instalacją referencyjną GOG")
        elif s in zm:
            a = arch.get(s)
            if e1["warstwa"] == "neoee" and any("D-PE" in x for x in e1["dowody"]):
                ust("neoee", "wysoka", "D-REF: zmieniony względem GOG", *e1["dowody"])
            elif sl.endswith("language.dll"):
                ust("localization", "wysoka", "D-REF: zmieniony względem GOG", *e1["dowody"])
            elif a is not None:
                typy = collections.Counter(x["wpis"].rsplit(".", 1)[-1] for x in a["zmienione"])
                opis = (f"D-SSA-REF: {a['identyczne_surowe'] + a['identyczne_tresc']} wpisów identycznych z GOG (treść), "
                        f"{len(a['zmienione'])} zmienionych {dict(typy)}, {len(a['tylko_ref'])} tylko w GOG, {len(a['tylko_spol'])} tylko tutaj")
                if sl.endswith("data/data.ssa") and sl.startswith(EE):
                    ust("mieszane:vanilla+localization", "wysoka", opis,
                        uw="jedyne zmiany: 462 nagrania głosowe sounds/*.wav (polski dubbing); 3277 pozostałych wpisów = GOG")
                elif sl.endswith("data/data.ssa"):
                    ust("mieszane:aoc+localization", "wysoka", opis,
                        uw="zmiany: 80 nagrań głosowych, 6 ekranów tytułowych TGA, 21 plików cywilizacji o polskich nazwach")
                else:
                    ust("localization", "wysoka", opis, uw="kampania: polskie scenariusze, narracja MP3, obrazy, lista scenariuszy")
            elif "/wonlobby resources/" in sl or sl.endswith("wonlobby.cfg"):
                ust("neoee", "srednia", "D-REF: zmieniony względem GOG",
                    "D-STR: pliki lobby WON – NeoEE zastępuje lobby (komponent LobbyExtension w NeoEE.cfg)",
                    uw="możliwy udział dreXmoda (motywy lobby) – nie rozdzielono")
            elif sl.endswith("zzwonversion.cfg"):
                ust("neoee", "srednia", "D-REF: 'Version: 2.0.0.0' → '2.0.0.5' (wersja NeoEE z rejestru)")
            elif sl.endswith(("dx7hrdisplay.dll", "dx7hrtnldisplay.dll", "low-level engine.dll")):
                ust("nieustalone", "wysoka", f"D-REF: łatka binarna – ten sam rozmiar, różnice w kilku bajtach (zob. raport porównania)",
                    uw="autor łatki nieustalony (NeoEE? instalator społeczności?) – brak sygnatury w pliku")
            elif sl.endswith(".bik"):
                ust("nieustalone", "wysoka", "D-REF: zmieniony film (24,2 MB vs 13,8 MB)",
                    uw="hipotezy: wersja HD (additional\\movies) lub polska ścieżka dźwiękowa – ścieżki audio BIK nie analizowano")
            elif sl.startswith("unins000"):
                ust("neoee", "wysoka", "D-REG: deinstalator instalatora NeoEE (inna treść niż deinstalator GOG)")
            elif sl.endswith("eula.txt"):
                ust("nieustalone", "srednia", "D-REF: drobna zmiana tekstu licencji (31 B)")
            else:
                ust("nieustalone", "srednia", "D-REF: zmieniony względem GOG, brak dowodu autorstwa")
        else:
            # tylko w instalacji społecznościowej – dowody etapu 1
            if e1["warstwa"] == "nieustalone" and any("D-OVR" in x for x in e1["dowody"]):
                ust("hd_nieustalone", "srednia", *e1["dowody"],
                    "D-REF: odpowiadający wpis archiwum GOG ma inną treść (0/252 identycznych) – luźny plik zastępuje oryginał",
                    uw="pakiety HD instalatora (hipoteza) – NIE są częścią NeoEE/dreXmoda wg dostępnych dowodów")
            elif e1["warstwa"] in ("vanilla", "aoc"):
                kopia = [x["ref"] for x in por["pliki"]["tylko_spol_ale_tresc_w_ref"] if x["spol"] == s]
                if kopia:
                    ust(e1["warstwa"], "srednia", f"D-REF: treść identyczna z plikiem GOG {kopia[0][0]} (inna ścieżka)",
                        uw="kopia pliku oryginalnego dodana przez instalator społeczności pod nową ścieżką")
                elif "/random map scripts/" in sl:
                    ust("nieustalone", "wysoka", "D-REF: brak w instalacji GOG – dodatkowa mapa losowa",
                        uw="mapy społeczności (Neo*, Perfect Islands, Tunisia Oasis …) – autor/komponent nieustalony; w etapie 1 błędnie 'vanilla/aoc (niska)'")
                else:
                    ust("nieustalone", "srednia", "D-REF: brak w instalacji GOG", uw="w etapie 1 'vanilla/aoc (niska)'")
            else:
                ust(e1["warstwa"], e1["pewnosc"], *e1["dowody"], uw=e1.get("uwagi", ""))
        wyn.append(e)
    pods = collections.Counter((e["warstwa"], e["pewnosc"]) for e in wyn)
    bajty = collections.Counter()
    for e in wyn:
        bajty[e["warstwa"]] += e["rozmiar"]
    json.dump({"opis": "Manifest zasobów instalacji społecznościowej – etap 2 (z referencją GOG)",
               "liczba_plikow": len(wyn), "podsumowanie": {f"{k[0]}|{k[1]}": v for k, v in sorted(pods.items())},
               "bajty_na_warstwe": dict(bajty), "pliki": wyn},
              open(os.path.join(au, "manifest_zasobow.json"), "w"), ensure_ascii=False, indent=1)
    with open(os.path.join(au, "manifest_zasobow.csv"), "w", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(["sciezka", "warstwa", "pewnosc", "warstwa_etap1", "rozmiar", "sha256", "dowody", "uwagi"])
        for e in wyn:
            w.writerow([e["sciezka"], e["warstwa"], e["pewnosc"], e["warstwa_etap1"], e["rozmiar"], e["sha256"],
                        " | ".join(e["dowody"]), e["uwagi"]])
    for k, v in sorted(pods.items(), key=lambda x: str(x)):
        print(f"{k[0]:32s} {k[1]:8s} {v:5d}  {bajty[k[0]] / 1e6:8.1f} MB (warstwa)")
    zmiana = collections.Counter((e["warstwa_etap1"], e["warstwa"]) for e in wyn if e["warstwa_etap1"] != e["warstwa"])
    print("zmiany klasyfikacji względem etapu 1:", dict(zmiana))


if __name__ == "__main__":
    main()
