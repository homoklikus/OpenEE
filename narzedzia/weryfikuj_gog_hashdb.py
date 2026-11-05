#!/usr/bin/env python3
"""Weryfikacja instalacji GOG względem dołączonej bazy sum `goggame-<id>.hashdb` (tylko odczyt).

Format (obserwacja): plik ZIP z jednym wpisem; wewnątrz: u32 12, u32 1, u32 N rekordów,
N × { char[1024] ścieżka względna (NUL), char[32] MD5 szesnastkowo }.
Użycie: weryfikuj_gog_hashdb.py <instalacja> <wynik.json>"""
import glob, hashlib, json, os, struct, sys, zipfile


def wczytaj_hashdb(p):
    z = zipfile.ZipFile(p)
    d = z.read(z.namelist()[0])
    a, b, n = struct.unpack_from("<III", d, 0)
    assert (a, b) == (12, 1) and 12 + n * 1056 == len(d), "nieoczekiwany format hashdb"
    out = {}
    for i in range(n):
        r = d[12 + i * 1056: 12 + (i + 1) * 1056]
        nazwa = r[:1024].split(b"\0")[0].decode("utf-8", "replace").replace("\\", "/")
        out[nazwa] = r[1024:1056].decode("ascii")
    return out


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def main():
    root, out = sys.argv[1], sys.argv[2]
    hp = glob.glob(os.path.join(root, "goggame-*.hashdb"))[0]
    ref = wczytaj_hashdb(hp)
    lok = {}
    for d, _, fn in os.walk(root):
        for n in fn:
            p = os.path.join(d, n)
            lok[os.path.relpath(p, root).replace(os.sep, "/")] = p
    lower = {k.lower(): k for k in lok}
    zgodne, rozne, brak = [], [], []
    for k, h in sorted(ref.items()):
        lk = lower.get(k.lower())
        if lk is None:
            brak.append(k)
        elif md5(lok[lk]) == h:
            zgodne.append(k)
        else:
            rozne.append(k)
    spoza = sorted(k for k in lok if k.lower() not in {x.lower() for x in ref})
    wyn = {"hashdb": os.path.basename(hp), "rekordy": len(ref), "zgodne_md5": len(zgodne),
           "rozne_md5": rozne, "brak_w_instalacji": brak, "pliki_spoza_hashdb": spoza}
    json.dump(wyn, open(out, "w"), ensure_ascii=False, indent=1)
    print(json.dumps({k: (v if not isinstance(v, list) else len(v)) for k, v in wyn.items()}, ensure_ascii=False))
    print("różne:", rozne[:20]); print("brak:", brak[:20]); print("spoza:", spoza[:40])


if __name__ == "__main__":
    main()
