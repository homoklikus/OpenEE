"""Wspólny opis struktur Titan (dane/titan/struktury_titan.json): walidacja, mapa dostępu do pól, kontrola EE↔AoC.

Narzędzie OpenEE (etap 30). Odpowiada na pytania typu „które funkcje zapisują pole X”, „czym różnią się odwołania
do +0x248 w EE i AoC”, „czy przesunięcie AoC jest spójne z funkcją-parą EE”. Wyniki dotyczące binarek są
KANDYDATAMI (przegląd liniowy, przesunięcie wspólne dla wielu struktur) – do ręcznej weryfikacji, nie przypisania.

Polecenia:
  waliduj [--exe-ee P --exe-aoc P]   poprawność schematu; z binarkami: czy funkcje z 'odczyt'/'zapis' zawierają dostęp
  dostep STRUKTURA POLE [--exe-ee P --exe-aoc P] [--zapis]   kandydaci funkcji odczytu/zapisu w EE i AoC
  przesuniecie 0x248 [--rozmiar 4] --exe-ee P [--exe-aoc P]  surowe zapytanie o przesunięcie
  porownaj --exe-ee P --exe-aoc P    spójność przesunięć EE/AoC w parach funkcji (pary_funkcji)
  markdown [WYJSCIE]                 tabela pól do atlasu (docs/titan/struktury_titan.md)
Ścieżki binarek: argumenty albo zmienne OPENEE_EXE_EE / OPENEE_EXE_AOC. Binarki tylko do odczytu.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

KORZEN = Path(__file__).resolve().parents[2]
SCHEMAT = KORZEN / "dane" / "titan" / "struktury_titan.json"
TYPY = {"u8": 1, "i8": 1, "u16": 2, "i16": 2, "u32": 4, "i32": 4, "f32": 4, "ptr": 4, "obj": 4}


def wczytaj(p: Path = SCHEMAT) -> dict:
    return json.loads(Path(p).read_text(encoding="utf-8"))


def hx(s: str | None) -> int | None:
    return int(s, 16) if s else None


def rozmiar_typu(t: str) -> int | None:
    if t.endswith("[]"):
        return None
    if "[" in t:
        b, n = t[:-1].split("[")
        return TYPY[b] * int(n) if b in TYPY else None
    return TYPY.get(t)


def waliduj_schemat(s: dict) -> list[str]:
    bl = []
    for k in ("wersja", "struktury", "binarki", "pary_funkcji"):
        if k not in s:
            bl.append(f"brak klucza {k}")
    for sn, st in s.get("struktury", {}).items():
        nazwy = set()
        for p in st.get("pola", []):
            w = f"{sn}.{p.get('nazwa')}"
            for k in ("nazwa", "typ", "ee", "aoc", "rozmiar", "pewnosc", "zrodlo", "odczyt", "zapis"):
                if k not in p:
                    bl.append(f"{w}: brak '{k}'")
            if p.get("nazwa") in nazwy:
                bl.append(f"{w}: powtórzona nazwa")
            nazwy.add(p.get("nazwa"))
            if p.get("pewnosc") not in s.get("pewnosc", {}):
                bl.append(f"{w}: pewność {p.get('pewnosc')} spoza P/W/H/N")
            for war in ("ee", "aoc"):
                v = p.get(war)
                if v is not None and not (isinstance(v, str) and v.startswith("0x")):
                    bl.append(f"{w}: przesunięcie {war} nie jest napisem 0x…")
            if p.get("ee") is None and p.get("aoc") is None:
                bl.append(f"{w}: brak przesunięcia w obu wariantach")
            r = rozmiar_typu(p.get("typ", ""))
            if r is not None and r != p.get("rozmiar"):
                bl.append(f"{w}: rozmiar {p.get('rozmiar')} ≠ typ {p.get('typ')} ({r})")
            for f in p.get("odczyt", []) + p.get("zapis", []):
                if not (isinstance(f, str) and f.startswith("0x")):
                    bl.append(f"{w}: adres funkcji {f!r} nie jest napisem 0x…")
        # nakładanie się pól w obrębie wariantu
        for war in ("ee", "aoc"):
            zak = sorted((hx(p[war]), hx(p[war]) + p["rozmiar"], p["nazwa"]) for p in st.get("pola", []) if p.get(war)
                         and p.get("rozmiar"))
            for a, b in zip(zak, zak[1:]):
                if b[0] < a[1]:
                    bl.append(f"{sn}: pola {a[2]} i {b[2]} nakładają się w {war}")
    return bl


def pole(s: dict, struktura: str, nazwa: str) -> dict:
    for p in s["struktury"][struktura]["pola"]:
        if p["nazwa"] == nazwa:
            return p
    raise KeyError(f"{struktura}.{nazwa}")


def _indeks(sciezka: str | None):
    if not sciezka:
        return None
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from indeks_pe import Indeks
    return Indeks(sciezka)


def _w_funkcji(ix, f: int, przes: int, zapis: bool | None = None) -> list[dict]:
    i = int(__import__("numpy").searchsorted(ix.f, f, side="right"))
    kon = int(ix.f[i]) if i < len(ix.f) else f + 0x4000
    out = [x for x in ix.dostepy(przes) if f <= x["adres"] < kon]
    if zapis is not None:
        out = [x for x in out if ("Z" in x["dostep"]) == zapis]
    return out


def mapa_dostepu(ix, przes: int, rozmiar: int | None = None) -> dict:
    fun: dict[int, dict] = {}
    for x in ix.dostepy(przes, rozmiar):
        f = x["funkcja"] or 0
        e = fun.setdefault(f, {"funkcja": hex(f), "odczyt": 0, "zapis": 0, "adres": 0, "instrukcje": []})
        if x["dostep"] == "adres":
            e["adres"] += 1
        else:
            e["odczyt"] += "O" in x["dostep"]
            e["zapis"] += "Z" in x["dostep"]
        e["instrukcje"].append(f"{x['adres']:#x} {x['mnemonik']} {x['dostep']}")
    return {"przesuniecie": hex(przes), "funkcje": sorted(fun.values(), key=lambda e: e["funkcja"]),
            "funkcje_zapisujace": [e["funkcja"] for e in fun.values() if e["zapis"]],
            "funkcje_czytajace": [e["funkcja"] for e in fun.values() if e["odczyt"]]}


def porownaj(s: dict, ix_ee, ix_aoc) -> list[dict]:
    out = []
    for sn, st in s["struktury"].items():
        for p in st["pola"]:
            if not p.get("ee") or not p.get("aoc") or hx(p["ee"]) < 0x40:
                continue                    # małe przesunięcia (nagłówki obiektów) występują w każdej strukturze
            for para in s["pary_funkcji"]:
                fe, fa = hx(para["ee"]), hx(para["aoc"])
                de = _w_funkcji(ix_ee, fe, hx(p["ee"]))
                da = _w_funkcji(ix_aoc, fa, hx(p["aoc"]))
                if bool(de) != bool(da):
                    # przesunięcie AoC mogło się zmienić: szukamy w funkcji AoC tej samej liczby dostępów pod innym przes.
                    out.append({"pole": f"{sn}.{p['nazwa']}", "para": para["opis"], "ee": len(de), "aoc": len(da),
                                "uwaga": "dostęp tylko w jednej grze – sprawdź przesunięcie albo przynależność pola"})
    return out


def markdown(s: dict) -> str:
    w = ["# Struktury Titan – tabela generowana", "",
         "Plik generowany przez `narzedzia/titan/struktury.py markdown` z `dane/titan/struktury_titan.json` "
         "(jedno źródło prawdy). Nie edytuj ręcznie – zmieniaj schemat.", ""]
    for sn, st in s["struktury"].items():
        w += [f"## {sn}", "", st.get("opis", ""), "", "| Pole | Typ | EE | AoC | Pewność | Zapis | Źródło / opis |",
              "|---|---|---|---|---|---|---|"]
        for p in st["pola"]:
            w.append(f"| {p['nazwa']} | {p['typ']} | {p['ee'] or '–'} | {p['aoc'] or '–'} | [{p['pewnosc']}] | "
                     f"{', '.join(p['zapis']) or '–'} | {p['zrodlo']}; {p.get('opis', '')} |")
        w.append("")
    return "\n".join(w).rstrip("\n")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("polecenie")
    ap.add_argument("arg", nargs="*")
    ap.add_argument("--exe-ee", default=os.environ.get("OPENEE_EXE_EE"))
    ap.add_argument("--exe-aoc", default=os.environ.get("OPENEE_EXE_AOC"))
    ap.add_argument("--rozmiar", type=int)
    ap.add_argument("--schemat", default=str(SCHEMAT))
    a = ap.parse_args(argv)
    s = wczytaj(Path(a.schemat))
    if a.polecenie == "waliduj":
        bl = waliduj_schemat(s)
        for war, ex in (("ee", a.exe_ee), ("aoc", a.exe_aoc)):
            ix = _indeks(ex)
            if not ix:
                continue
            if ix.sha != s["binarki"][war]["sha256"]:
                bl.append(f"{war}: sha256 binarki {ix.sha[:16]} ≠ schemat")
            for sn, st in s["struktury"].items():
                for p in st["pola"]:
                    if not p.get(war):
                        continue
                    for rodz, zap in (("odczyt", False), ("zapis", True)):
                        for f in p[rodz]:
                            if war == "ee" and not _w_funkcji(ix, hx(f), hx(p[war]), zap if zap else None):
                                bl.append(f"{sn}.{p['nazwa']}: funkcja {f} ({rodz}) bez dostępu do {p[war]} w EE")
        print(json.dumps({"bledy": bl, "pol": sum(len(v["pola"]) for v in s["struktury"].values())}, ensure_ascii=False,
                         indent=1))
        return 1 if bl else 0
    if a.polecenie == "dostep":
        p = pole(s, a.arg[0], a.arg[1])
        out = {"pole": f"{a.arg[0]}.{a.arg[1]}", "pewnosc": p["pewnosc"]}
        for war, ex in (("ee", a.exe_ee), ("aoc", a.exe_aoc)):
            ix = _indeks(ex)
            if ix and p.get(war):
                out[war] = mapa_dostepu(ix, hx(p[war]), p["rozmiar"] if p["rozmiar"] in (1, 2, 4) else None)
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0
    if a.polecenie == "przesuniecie":
        out = {}
        for war, ex in (("ee", a.exe_ee), ("aoc", a.exe_aoc)):
            ix = _indeks(ex)
            if ix:
                out[war] = mapa_dostepu(ix, int(a.arg[0], 16), a.rozmiar)
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return 0
    if a.polecenie == "porownaj":
        r = porownaj(s, _indeks(a.exe_ee), _indeks(a.exe_aoc))
        print(json.dumps({"niespojnosci": r, "liczba": len(r)}, ensure_ascii=False, indent=1))
        return 0
    if a.polecenie == "markdown":
        t = markdown(s)
        if a.arg:
            Path(a.arg[0]).write_text(t + "\n", encoding="utf-8")
        else:
            print(t)
        return 0
    ap.error("nieznane polecenie")
    return 2


if __name__ == "__main__":
    sys.exit(main())
