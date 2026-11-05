#!/usr/bin/env python3
"""OpenEE – audyt instalacji Empire Earth (WYŁĄCZNIE ODCZYT).

Tworzy inwentarz wszystkich plików: ścieżka względna, rozmiar, mtime, SHA-256, sygnatura (magic),
informacje o wersji PE (dla .exe/.dll) oraz informację, czy plik figuruje w dzienniku deinstalacji
instalatora Inno Setup (unins000.dat).  Nie otwiera żadnego pliku do zapisu w katalogu gry.

Użycie: python3 audyt_instalacji.py <katalog_instalacji> <plik_wyjściowy.json> [<sciezki_unins.txt>]
"""
import hashlib, json, os, sys, time

try:
    import pefile  # opcjonalne
except Exception:  # pragma: no cover
    pefile = None


def sha256(p, buf=1 << 20):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while True:
            b = f.read(buf)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def magic(p):
    with open(p, "rb") as f:
        b = f.read(16)
    return b.hex()


def pe_info(p):
    if pefile is None:
        return None
    try:
        pe = pefile.PE(p, fast_load=True)
        pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
        out = {"timestamp": pe.FILE_HEADER.TimeDateStamp,
               "timestamp_utc": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(pe.FILE_HEADER.TimeDateStamp)),
               "sekcje": [s.Name.rstrip(b"\0").decode("latin-1") for s in pe.sections]}
        for fi in getattr(pe, "FileInfo", []) or []:
            for e in fi:
                for st in getattr(e, "StringTable", []) or []:
                    for k, v in st.entries.items():
                        out.setdefault("wersja", {})[k.decode("latin-1")] = v.decode("latin-1", "replace")
        pe.close()
        return out
    except Exception as ex:
        return {"blad": str(ex)}


def main():
    root, out = sys.argv[1], sys.argv[2]
    unins = set()
    if len(sys.argv) > 3:
        pref = "C:\\GOG Games\\Empire Earth Gold Edition\\"
        for line in open(sys.argv[3], encoding="utf-8", errors="replace"):
            line = line.strip()
            if line.startswith(pref):
                unins.add(line[len(pref):].replace("\\", "/").lower())
    pliki = []
    for d, dn, fn in os.walk(root):
        dn.sort()
        for n in sorted(fn):
            p = os.path.join(d, n)
            rel = os.path.relpath(p, root).replace(os.sep, "/")
            st = os.stat(p)
            r = {"sciezka": rel, "rozmiar": st.st_size,
                 "mtime": time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(st.st_mtime)),
                 "sha256": sha256(p), "magic": magic(p),
                 "w_dzienniku_instalatora": rel.lower() in unins}
            if n.lower().endswith((".exe", ".dll")):
                r["pe"] = pe_info(p)
            pliki.append(r)
    json.dump({"katalog": root, "utworzono": time.strftime("%Y-%m-%d %H:%M:%S"),
               "liczba_plikow": len(pliki), "pliki": pliki}, open(out, "w"), ensure_ascii=False, indent=1)
    print("pliki:", len(pliki), "w dzienniku instalatora:", sum(p["w_dzienniku_instalatora"] for p in pliki))


if __name__ == "__main__":
    main()
