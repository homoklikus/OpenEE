"""Modele CEM (sygnatura 'SSMF', wersja 2) Empire Earth – parser OpenEE.

Układ ustalony na danych EE, z pomocą publicznej dokumentacji projektu open-source
`cem` (docs.rs/cem, coderbot16) – kod napisany od nowa.

    'SSMF' u16 wersja główna (=2), u16 podwersja (=0); w EE występuje też 1.3 (11 modeli) – nieobsługiwana
    7 × u32: trójkąty, wierzchołki, punkty_tag, materiały, klatki, modele_potomne, poziomy_LOD
    napis nazwa węzła  (napis = u32 długość z NUL + bajty)
    3 × f32 środek
    LOD × { u32 liczba_trójkątów, liczba × 3 × u32 indeksy }
    materiały × { napis nazwa, u32 tekstura, LOD × (u32 offset, u32 długość) trójkątów,
                  u32 offset_wierzchołków, u32 liczba_wierzchołków, napis nazwa_tekstury }
    punkty_tag × napis
    klatki × { f32 promień, wierzchołki × (3 f32 poz, 3 f32 normalna, 2 f32 uv),
               punkty_tag × 3 f32, macierz 4×4 f32, AABB 6 f32 }
    modele_potomne × (kolejny model SSMF – weryfikowane przez `czytaj_cem`)
"""
import struct


class _R:
    def __init__(self, b, p=0):
        self.b, self.p = b, p

    def u32(self):
        v = struct.unpack_from("<I", self.b, self.p)[0]; self.p += 4; return v

    def f32(self, n=1):
        v = struct.unpack_from(f"<{n}f", self.b, self.p); self.p += 4 * n
        return v if n > 1 else v[0]

    def napis(self):
        n = self.u32()
        if n > 4096:
            raise ValueError(f"CEM: podejrzana długość napisu {n} @ {self.p - 4}")
        s = self.b[self.p:self.p + n].split(b"\0", 1)[0].decode("latin-1"); self.p += n
        return s


def _model(r):
    if r.b[r.p:r.p + 4] != b"SSMF":
        raise ValueError(f"CEM: brak 'SSMF' @ {r.p}")
    r.p += 4
    major, minor = struct.unpack_from("<HH", r.b, r.p); r.p += 4
    wersja = (major, minor)
    if wersja == (1, 3):
        return _model_v13(r)
    if wersja != (2, 0):
        raise NotImplementedError(f"CEM: wersja {major}.{minor} nieobsługiwana (obsługiwane 2.0 i 1.3)")
    n_tri, n_v, n_tag, n_mat, n_fr, n_child, n_lod = (r.u32() for _ in range(7))
    m = {"wersja": wersja, "nazwa": r.napis(), "srodek": r.f32(3), "liczby": {
        "trojkaty": n_tri, "wierzcholki": n_v, "tagi": n_tag, "materialy": n_mat,
        "klatki": n_fr, "potomne": n_child, "lod": n_lod}}
    lods = []
    for _ in range(n_lod):
        k = r.u32()
        idx = struct.unpack_from(f"<{3 * k}I", r.b, r.p); r.p += 12 * k
        lods.append(idx)
    m["lod"] = lods
    mats = []
    for _ in range(n_mat):
        mt = {"nazwa": r.napis(), "tekstura_id": r.u32()}
        mt["zakresy_lod"] = [(r.u32(), r.u32()) for _ in range(n_lod)]
        mt["v_offset"], mt["v_liczba"] = r.u32(), r.u32()
        mt["tekstura"] = r.napis()
        mats.append(mt)
    m["materialy"] = mats
    m["tagi"] = [r.napis() for _ in range(n_tag)]
    klatki = []
    for _ in range(n_fr):
        fr = {"promien": r.f32()}
        v = struct.unpack_from(f"<{8 * n_v}f", r.b, r.p); r.p += 32 * n_v
        fr["wierzcholki"] = v
        fr["tagi"] = [r.f32(3) for _ in range(n_tag)]
        fr["macierz"] = r.f32(16)
        fr["aabb"] = r.f32(6)
        klatki.append(fr)
    m["klatki"] = klatki
    m["potomne"] = [_model(r) for _ in range(n_child)]
    return m


def _model_v13(r):
    """SSMF 1.3 (11 modeli EE). Układ ustalony na danych (fx_debrisflat: plik zużyty co do bajta), nazwy struktur
    zgodne z publiczną dokumentacją crate `cem` (moduł v1): Quantities, Vertex, Material, Frame."""
    q = dict(zip(("klatki", "materialy", "punkty", "trojkaty", "grupy", "wierzcholki", "tagi", "potomne"),
                 (r.u32() for _ in range(8))))
    m = {"wersja": (1, 3), "nazwa": r.napis(), "srodek": r.f32(3), "liczby": q}
    m["u8"] = r.b[r.p]; r.p += 1
    m["punkty_u32"] = list(struct.unpack_from(f"<{q['punkty']}I", r.b, r.p)); r.p += 4 * q["punkty"]
    tr = []
    for _ in range(q["trojkaty"] * 3):
        idx = r.u32(); uv = r.f32(2); rgb = r.f32(3); x4 = r.f32(4)
        tr.append({"w": idx, "uv": uv, "rgb": rgb, "x4": x4})
    m["rogi"] = tr
    grupy = []
    for _ in range(q["grupy"]):          # nazwana grupa trójkątów, np. "player color"
        nazwa = r.napis(); n = r.u32()
        grupy.append({"nazwa": nazwa, "trojkaty": list(struct.unpack_from(f"<{n}I", r.b, r.p))}); r.p += 4 * n
    m["grupy"] = grupy
    mats = []
    for _ in range(q["materialy"]):
        n = r.u32()
        ind = list(struct.unpack_from(f"<{n}I", r.b, r.p)); r.p += 4 * n
        flag = r.b[r.p]; r.p += 1
        tex = None
        if flag:
            tex = (r.napis(), r.u32())
        mats.append({"trojkaty": ind, "tekstura": tex[0] if tex else "", "tekstura_u32": tex[1] if tex else None})
    m["materialy"] = mats
    m["wierzch_punkt"] = [(r.u32(), r.f32()) for _ in range(q["wierzcholki"])]
    m["tagi"] = [r.napis() for _ in range(q["tagi"])]
    kl = []
    for _ in range(q["klatki"]):
        fr = {"promien": r.f32()}
        fr["punkty"] = [r.f32(3) for _ in range(q["punkty"])]
        fr["normalne_q"] = list(struct.unpack_from(f"<{q['wierzcholki']}H", r.b, r.p)); r.p += 2 * q["wierzcholki"]
        fr["tagi"] = [r.f32(3) for _ in range(q["tagi"])]
        fr["macierz"] = r.f32(16)
        fr["aabb"] = r.f32(6)
        kl.append(fr)
    m["klatki"] = kl
    m["potomne"] = [_model(r) for _ in range(q["potomne"])]
    return m


def indeksy_materialu(m, mt, lod=0):
    """Bezwzględne indeksy wierzchołków trójkątów materiału (CEM 2.0). Indeksy w LOD są WZGLĘDNE wobec v_offset
    materiału [D: 544/544 materiałów z v_offset > 0] – naprawa grafiki OpenEE."""
    o, n = mt["zakresy_lod"][lod]
    vo = mt["v_offset"]
    return [vo + i for i in m["lod"][lod][3 * o:3 * (o + n)]]


def czytaj_cem(buf):
    r = _R(buf)
    m = _model(r)
    m["reszta_bajtow"] = len(buf) - r.p
    return m


def kontrola(m):
    """Sprawdzenia spójności – zwraca listę problemów (pusta = OK)."""
    bl = []
    if m["wersja"] == (1, 3):
        q = m["liczby"]
        if any(c["w"] >= q["wierzcholki"] for c in m["rogi"]):
            bl.append("1.3: indeks wierzchołka poza zakresem")
        if any(p >= q["punkty"] for p, _ in m["wierzch_punkt"]):
            bl.append("1.3: indeks punktu poza zakresem")
        for mt in m["materialy"]:
            if any(t >= q["trojkaty"] for t in mt["trojkaty"]):
                bl.append("1.3: indeks trójkąta materiału poza zakresem")
        return bl
    nv = m["liczby"]["wierzcholki"]
    for i, l in enumerate(m["lod"]):
        if l and max(l) >= nv:
            bl.append(f"LOD{i}: indeks {max(l)} ≥ {nv}")
    if m["lod"] and len(m["lod"][0]) // 3 != m["liczby"]["trojkaty"]:
        bl.append(f"LOD0 ma {len(m['lod'][0]) // 3} trójkątów, nagłówek {m['liczby']['trojkaty']}")
    for mt in m["materialy"]:
        if mt["v_offset"] + mt["v_liczba"] > nv:
            bl.append(f"materiał {mt['nazwa']}: zakres wierzchołków poza modelem")
        if m["lod"]:
            ind = indeksy_materialu(m, mt)
            if ind and (min(ind) < mt["v_offset"] or max(ind) >= mt["v_offset"] + mt["v_liczba"]):
                bl.append(f"materiał {mt['nazwa']}: indeksy poza zakresem wierzchołków materiału")
        for (o, n), l in zip(mt["zakresy_lod"], m["lod"]):
            if o + n > len(l) // 3:
                bl.append(f"materiał {mt['nazwa']}: zakres trójkątów poza LOD")
    for c in m["potomne"]:
        bl += kontrola(c)
    return bl
