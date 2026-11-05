#!/usr/bin/env python3
"""Porównanie instalacji referencyjnej (GOG) ze społecznościową (NeoEE/dreXmod/PL/HD). Tylko odczyt.

Użycie: porownaj_instalacje.py <inst_ref> <inw_ref.json> <inst_spol> <inw_spol.json> <wyjście.json>
Wynik:
  pliki: identyczne / zmienione / tylko_ref / tylko_spol (ścieżki bez rozróżniania wielkości liter)
  archiwa: dla każdego *.ssa obecnego w obu – wpisy identyczne (surowe lub po rozpakowaniu), zmienione,
           tylko_ref, tylko_spol (dopasowanie po nazwie, a dla zmienionych nazw – po SHA-256 treści)
  nadpisania: luźne pliki w Data/ instalacji społecznościowej, które odpowiadają wpisom data.ssa
              – porównane z wpisem REFERENCYJNYM (czy luźny plik = oryginał, zmiana, czy nowy zasób)
"""
import hashlib, json, os, sys, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eeformaty import ssa, dcl


def sha(b):
    return hashlib.sha256(b).hexdigest()


def indeks(inw):
    return {p["sciezka"].lower(): p for p in json.load(open(inw))["pliki"]}


class _Arch:
    """Indeks archiwum z leniwym rozpakowywaniem (rozpakowujemy tylko wpisy, których surowe bajty się różnią)."""
    def __init__(self, path):
        self.A = ssa.ArchiwumSSA(path)
        self.surowe = {k: sha(self.A.czytaj_surowe(k)) for k in self.A.wpisy}
        self._tresc = {}

    def tresc(self, k):
        if k not in self._tresc:
            raw = self.A.czytaj_surowe(k)
            try:
                roz = dcl.maybe_unpack(raw)
            except Exception:
                roz = raw
            self._tresc[k] = (sha(roz), len(roz))
        return self._tresc[k]


def porownaj_archiwa(pr, ps):
    R, S = _Arch(pr), _Arch(ps)
    wyn = {"wpisy_ref": len(R.surowe), "wpisy_spol": len(S.surowe), "identyczne_surowe": 0, "identyczne_tresc": 0,
           "zmienione": [], "tylko_ref": [], "tylko_spol": [], "przemianowane": []}
    for k in R.surowe:
        if k in S.surowe:
            if R.surowe[k] == S.surowe[k]:
                wyn["identyczne_surowe"] += 1
            elif R.tresc(k)[0] == S.tresc(k)[0]:
                wyn["identyczne_tresc"] += 1
            else:
                wyn["zmienione"].append({"wpis": k, "rozmiar_ref": R.tresc(k)[1], "rozmiar_spol": S.tresc(k)[1]})
        else:
            wyn["tylko_ref"].append(k)
    sam_ref = [k for k in R.surowe if k not in S.surowe]
    tresc_ref = {R.tresc(k)[0]: k for k in sam_ref}
    for k in S.surowe:
        if k not in R.surowe:
            if S.tresc(k)[0] in tresc_ref:
                wyn["przemianowane"].append({"ref": tresc_ref[S.tresc(k)[0]], "spol": k})
            else:
                wyn["tylko_spol"].append(k)
    return wyn, R


def main():
    ir, inwr, isp, inws, out = sys.argv[1:6]
    R, S = indeks(inwr), indeks(inws)
    pl = {"identyczne": [], "zmienione": [], "tylko_ref": [], "tylko_spol": []}
    for k, p in R.items():
        if k in S:
            (pl["identyczne"] if p["sha256"] == S[k]["sha256"] else pl["zmienione"]).append(
                p["sciezka"] if p["sha256"] == S[k]["sha256"] else
                {"sciezka": p["sciezka"], "rozmiar_ref": p["rozmiar"], "rozmiar_spol": S[k]["rozmiar"]})
        else:
            pl["tylko_ref"].append(p["sciezka"])
    pl["tylko_spol"] = [S[k]["sciezka"] for k in S if k not in R]
    # ten sam plik pod inną ścieżką (po SHA)
    sha_ref = collections.defaultdict(list)
    for p in R.values():
        sha_ref[p["sha256"]].append(p["sciezka"])
    pl["tylko_spol_ale_tresc_w_ref"] = [{"spol": s, "ref": sha_ref[S[s.lower()]["sha256"]]}
                                        for s in pl["tylko_spol"] if S[s.lower()]["sha256"] in sha_ref]
    archiwa = {}
    ref_wpisy = {}
    for k, p in R.items():
        if k.endswith(".ssa") and k in S:
            print("archiwum", p["sciezka"], flush=True)
            w, rw = porownaj_archiwa(os.path.join(ir, p["sciezka"]), os.path.join(isp, S[k]["sciezka"]))
            archiwa[p["sciezka"]] = w
            ref_wpisy[p["sciezka"]] = rw
    # nadpisania luźne w instalacji społecznościowej względem archiwów referencyjnych
    nadp = []
    for gra in ("Empire Earth", "Empire Earth - The Art of Conquest"):
        arch = f"{gra}/Data/data.ssa"
        rw = ref_wpisy.get(arch)
        pref = f"{gra}/Data/".lower()
        for k, p in S.items():
            if not k.startswith(pref) or k.endswith(".ssa"):
                continue
            rel = k[len(pref):]
            if rw and rel in rw.surowe:
                tresc = open(os.path.join(isp, p["sciezka"]), "rb").read()
                try:
                    tresc = dcl.maybe_unpack(tresc)
                except Exception:
                    pass
                nadp.append({"luzny": p["sciezka"], "wpis_ref": f"{arch}:{rel}",
                             "rowny_oryginalowi": sha(tresc) == rw.tresc(rel)[0],
                             "rozmiar_luzny": len(tresc), "rozmiar_oryginalu": rw.tresc(rel)[1]})
    wyn = {"pliki": {k: (v if k != "identyczne" else sorted(v)) for k, v in pl.items()},
           "liczby": {k: len(v) for k, v in pl.items()}, "archiwa": archiwa, "nadpisania_luzne": nadp}
    json.dump(wyn, open(out, "w"), ensure_ascii=False, indent=1)
    print(json.dumps(wyn["liczby"]))
    for a, w in archiwa.items():
        print(a, {k: (len(v) if isinstance(v, list) else v) for k, v in w.items()})
    print("nadpisania:", len(nadp), "równe oryginałowi:", sum(x["rowny_oryginalowi"] for x in nadp))


if __name__ == "__main__":
    main()
