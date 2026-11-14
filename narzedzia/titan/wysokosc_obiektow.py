#!/usr/bin/env python3
"""Wysokość obiektów scenariusza SCN względem terenu (etap 54) – diagnostyka „lewitujących” obiektów.

Rekord jednostki (kawałek 5) przechowuje pozycję jako translację macierzy 4×4 (elementy 3, 7, 11 = x, y, z) –
z jest BEZWZGLĘDNE (wysokość świata), nie względne do terenu [P: scenariusz kampanii, docs/titan/WYSOKOSC_OBIEKTOW_SCN.md].
Wysokość terenu w punkcie liczy ten sam wzór co GETerrainMesh::GetMeshZ (docs/titan/fizyka_terenu.md § 1).

Podpolecenia:
  scn PLIK.scn [--prog=0.05] [--typ=N ...] [--gracze]   różnica z obiektu − teren dla obiektów złożonych; kod wyjścia 1,
                                                         gdy któryś obiekt graczy (nie Świata) odstaje ponad próg
  statystyka PLIK.scn                                    rozkład różnicy według typu (do ustalenia przesunięć klas)
  nagranie NAGRANIE.json PLIK.scn                        odcinki stałej różnicy z − teren każdej jednostki nagrania
Narzędzie tylko czyta pliki; dane gry zostają lokalnie.
"""
from __future__ import annotations

import collections
import json
import math
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from eeformaty import gracze as G, scn as S  # noqa: E402
from eeformaty.dcl import maybe_unpack  # noqa: E402

PROG = 0.05   # próg ostrzeżenia: 1/4 kwantu wysokości terenu (0,204); przesunięcia klas w kampanii ≤ 0,01 [P]


def siatka(t: dict) -> dict:
    """Wysokości wierzchołków {(ix, iy): z} z kawałka 4 (kolejność rombu)."""
    h, i = {}, 0
    for y, (lo, hi) in enumerate(t["wiersze_punktow"]):
        for x in range(lo, hi + 1):
            h[(x, y)] = t["wysokosc"][i]
            i += 1
    return h


def wysokosc_terenu(h: dict, x: float, y: float):
    """GetMeshZ: dwa trójkąty z przekątną (ix, iy)–(ix+1, iy+1); None poza siatką."""
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    try:
        h00, h10, h01, h11 = h[(ix, iy)], h[(ix + 1, iy)], h[(ix, iy + 1)], h[(ix + 1, iy + 1)]
    except KeyError:
        return None
    if fy >= fx:
        return h00 + (h11 - h01) * fx + (h01 - h00) * fy
    return h00 + (h10 - h00) * fx + (h11 - h10) * fy


def wczytaj(sciezka):
    blob = Path(sciezka).read_bytes()
    ch = {c["tag"]: c for c in S.kawalki(blob)}
    h = siatka(S.teren(ch[4]["surowe"]))
    gr = G.czytaj(maybe_unpack(ch[5]["surowe"]), ch[5]["minor"])
    return h, gr


def obiekty(sciezka):
    """[{gracz, id, typ, x, y, z, teren, dz}] – obiekty złożone (z macierzą) scenariusza."""
    h, gr = wczytaj(sciezka)
    out = []
    for nr, g in enumerate(gr):
        for u in g.get("jednostki", []):
            if not u.get("complex"):
                continue
            m = struct.unpack("<16f", u["transform"])
            tz = wysokosc_terenu(h, m[3], m[7])
            out.append({"gracz": nr, "id": u["id"], "typ": u["type"], "x": m[3], "y": m[7], "z": m[11], "teren": tz,
                        "dz": None if tz is None else m[11] - tz})
    return out


def podejrzane(ob, prog=PROG, typy=None):
    """Obiekty graczy (gracz ≥ 1) z |z − teren| > prog; obiekty nad wodą (teren < 0, z ≥ 0 – okręty, mosty, doki)
    nie są zgłaszane."""
    zle = []
    for o in ob:
        if o["gracz"] == 0 or o["dz"] is None or (typy and o["typ"] not in typy):
            continue
        if o["teren"] < 0 and o["z"] >= 0 and o["z"] < prog:
            continue
        if abs(o["dz"]) > prog:
            zle.append(o)
    return zle


def odcinki_nagrania(nagr: dict, h: dict, eps=0.003):
    """{id: [(nr próbki, t, stan, x, y, z, teren, dz)]} – początek i każda zmiana różnicy o więcej niż eps."""
    wyn, ost = collections.defaultdict(list), {}
    for i, p in enumerate(nagr["probki"]):
        for k, u in p.items():
            if not k.startswith("0x") or not isinstance(u, dict) or "z" not in u:
                continue
            tz = wysokosc_terenu(h, u["x"], u["y"])
            if tz is None:
                continue
            dz = u["z"] - tz
            if k not in ost or abs(ost[k] - dz) > eps:
                wyn[k].append((i, p["t"], u.get("stan"), round(u["x"], 3), round(u["y"], 3), round(u["z"], 4),
                               round(tz, 4), round(dz, 4), u.get("typ")))
            ost[k] = dz
    return wyn


def main(argv=None) -> int:
    a = [x for x in (argv or sys.argv[1:]) if not x.startswith("--")]
    op = dict((x[2:].split("=", 1) + ["1"])[:2] for x in (argv or sys.argv[1:]) if x.startswith("--"))
    if not a:
        raise SystemExit(__doc__)
    if a[0] == "scn":
        ob = obiekty(a[1])
        typy = {int(op["typ"])} if "typ" in op else None
        zle = podejrzane(ob, float(op.get("prog", PROG)), typy)
        if "gracze" in op:
            for o in ob:
                if o["gracz"]:
                    print(o["gracz"], hex(o["id"]), o["typ"], round(o["x"], 3), round(o["y"], 3), round(o["z"], 4),
                          None if o["teren"] is None else round(o["teren"], 4))
        for o in zle:
            print(f"PODEJRZANE gracz {o['gracz']} {hex(o['id'])} typ {o['typ']} ({o['x']:.3f}; {o['y']:.3f}) "
                  f"z {o['z']:.4f} teren {o['teren']:.4f} różnica {o['dz']:+.4f}")
        print(json.dumps({"obiektow_graczy": sum(1 for o in ob if o["gracz"]), "podejrzanych": len(zle)}))
        return 1 if zle else 0
    if a[0] == "statystyka":
        st = collections.defaultdict(list)
        for o in obiekty(a[1]):
            if o["dz"] is not None:
                st[(o["gracz"] > 0, o["typ"])].append(o["dz"])
        for k in sorted(st):
            v = st[k]
            print("gracze" if k[0] else "świat", k[1], len(v), round(min(v), 4), round(max(v), 4))
        return 0
    if a[0] == "nagranie":
        h, _gr = wczytaj(a[2])
        nagr = json.loads(Path(a[1]).read_text())
        for k, v in odcinki_nagrania(nagr, h).items():
            print(k, "typ", v[0][8], "zmian", len(v))
            for w in v[:int(op.get("ile", 4))]:
                print("   próbka", w[0], "t", w[1], "stan", w[2], "xy", w[3], w[4], "z", w[5], "teren", w[6], "dz", w[7])
            if len(v) > int(op.get("ile", 4)):
                w = v[-1]
                print("   … ostatnia: próbka", w[0], "t", w[1], "stan", w[2], "z", w[5], "teren", w[6], "dz", w[7])
        return 0
    raise SystemExit(__doc__)


if __name__ == "__main__":
    sys.exit(main())
