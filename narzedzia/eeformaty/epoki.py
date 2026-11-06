"""Epoki i warianty grafiki Empire Earth (etap 8) – dekodery OpenEE, tylko odczyt.

Łańcuch danych oryginału (RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md § 1–2):

  scenariusz (kawałek 5, blok EE gracza)  → technologia bieżącej epoki gracza (ID w dbtechtree)
  dbtechtree (rekord epoki)               → „Event ID” (indeks w dbevents), „Epoch number” (1–15)
  dbevents                                → lista ID efektów (dbeffects)
  dbeffects, „Effect code” = 6            → zmiana grafiki: „Object 1” (dbobjects) → „New graphic” (dbgraphics)
  dbobjects „Graphic ID”                  → grafika bazowa (przed jakąkolwiek epoką)

Grafika obiektu gracza w epoce E = grafika bazowa z nałożonymi kolejno (rosnąco wg numeru epoki) zmianami grafiki
ze zdarzeń wszystkich epok o numerze ≤ E [D + potwierdzenie: fort i obywatel w scenariuszu „Żołnierze dla Rzymu”].

Formaty (własna analiza plików, schemat pól: dane/schemat_db_eedbeditor, GPLv3):
* dbtechtree: brak globalnego licznika; 15 grup „i32 liczba_dzieci, rekord epoki, liczba_dzieci × rekord”.
  Rekord = 272 B (NAME 100 + 36 × i32 + 4 × u8 + 6 × i32) + 4 B × „Num of tech builders” (ostatnie pole).
* dbevents: bez licznika; rekord = NAME 100 B, i32 numer sekwencji, i32 n, n × i32 ID efektu.
* dbeffects: bez licznika; rekord = 22 pola po 4 B (88 B) w kolejności schematu.

Etap 11 (docs/FORMATY_DB_EE_VS_AOC.md): Empire Earth 1.0 – dbtechtree 268 B („Epoch number” +248, liczba budowniczych
+264), dbeffects 68 B (17 pól). Wariant rozpoznawany ze struktury; dane muszą pasować do dokładnie jednego wariantu.
"""
import struct

KOD_ZMIANY_GRAFIKI = 6
REKORD_TECH = 272          # AoC
REKORD_EFEKTU = 88         # AoC
TECH = {"aoc": {"rekord": 272, "epoka": 252, "budowniczowie": 268},
        "ee": {"rekord": 268, "epoka": 248, "budowniczowie": 264}}
EFEKT = {"aoc": 88, "ee": 68}


def _napis(b):
    if not b or b[0] in (0xCC, 0xFF):
        return ""
    return b.split(b"\0")[0].decode("cp1250", "replace")


def _struktura_techtree(d, f):
    o, liczba = 0, 0
    while o < len(d):
        if o + 4 > len(d):
            return f"ucięty licznik przy {o}"
        n = struct.unpack_from("<i", d, o)[0]
        o += 4
        if n < 0 or n > 100000:
            return f"licznik grupy {n} przy {o - 4}"
        for _ in range(n + 1):
            if o + f["rekord"] > len(d):
                return f"ucięty rekord przy {o}"
            nb = struct.unpack_from("<i", d, o + f["budowniczowie"])[0]
            if nb < 0 or nb > 1000 or o + f["rekord"] + 4 * nb > len(d):
                return f"budowniczowie {nb} przy {o}"
            o += f["rekord"] + 4 * nb
            liczba += 1
    return liczba


def wariant_techtree(d):
    """'aoc' | 'ee' – jedyny format rekordu, przy którym struktura grup zużywa plik co do bajta; inaczej ValueError."""
    wyn = {w: _struktura_techtree(d, f) for w, f in TECH.items()}
    pasuja = [w for w, x in wyn.items() if isinstance(x, int)]
    if len(pasuja) != 1:
        raise ValueError(f"dbtechtree: {'niejednoznaczny' if pasuja else 'nieobsługiwany'} wariant ({len(d)} B; {wyn})")
    return pasuja[0]


def techtree(d):
    """Lista rekordów dbtechtree: {nazwa, seq, id, start, koniec, event, obiekt, typ, epoka, budowniczowie, grupa}."""
    f = TECH[wariant_techtree(d)]
    o = 0
    wynik = []
    grupa = 0
    while o < len(d):
        n = struct.unpack_from("<i", d, o)[0]
        o += 4
        for i in range(n + 1):
            v = struct.unpack_from("<36i", d, o + 100)
            nb = struct.unpack_from("<i", d, o + f["budowniczowie"])[0]
            wynik.append({"nazwa": _napis(d[o:o + 100]), "seq": v[0], "id": v[1], "start": v[2], "koniec": v[3],
                          "event": v[4], "obiekt": v[18], "typ": v[22],
                          "epoka": struct.unpack_from("<i", d, o + f["epoka"])[0], "grupa": grupa,
                          "glowa_grupy": i == 0,
                          "budowniczowie": list(struct.unpack_from("<%di" % nb, d, o + f["rekord"]))})
            o += f["rekord"] + 4 * nb
        grupa += 1
    return wynik


def zdarzenia(d):
    """Lista dbevents (indeks = Event ID): {nazwa, seq, efekty: [ID dbeffects]}."""
    o, wynik = 0, []
    while o + 108 <= len(d):
        seq, n = struct.unpack_from("<2i", d, o + 100)
        if n < 0 or o + 108 + 4 * n > len(d):
            raise ValueError(f"dbevents: rekord {len(wynik)}")
        wynik.append({"nazwa": _napis(d[o:o + 100]), "seq": seq,
                      "efekty": list(struct.unpack_from("<%di" % n, d, o + 108))})
        o += 108 + 4 * n
    if o != len(d):
        raise ValueError("dbevents: nadmiarowe bajty")
    return wynik


POLA_EFEKTU = ["Sequence number", "ID", "Set base attribute", "Alter base attribute", "Alter attribute multiplier",
               "Object 1", "Object 2", "Unit set ID", "Effect code", "New graphic", "Tech ID", "Attribute",
               "New sound", "New button", "New area effect", "Terrain family", "Never used", "Unknown",
               "Never used#2", "Never used#3", "Never used#4", "Never used#5"]
POLA_FLOAT = {"Set base attribute", "Alter base attribute", "Alter attribute multiplier"}


def wariant_efektow(d):
    pasuja = [w for w, r in EFEKT.items() if len(d) and len(d) % r == 0]
    if len(pasuja) != 1:
        raise ValueError(f"dbeffects: {'niejednoznaczny' if pasuja else 'nieobsługiwany'} wariant – {len(d)} B "
                         "(rekord AoC 88 B, EE 68 B)")
    return pasuja[0]


def efekty(d):
    R = EFEKT[wariant_efektow(d)]
    pola = POLA_EFEKTU[:R // 4]          # EE: pola 0–16 (bez pięciu końcowych pól AoC)
    wynik = []
    for o in range(0, len(d), R):
        r = {}
        for i, p in enumerate(pola):
            r[p] = struct.unpack_from("<f" if p in POLA_FLOAT else "<i", d, o + 4 * i)[0]
        wynik.append(r)
    return wynik


class Warianty:
    """Wybór grafiki obiektu wg epoki (i zbadanych technologii) z danych gry."""

    def __init__(self, tech, zdarz, efek, obiekty):
        self.efekty = {e["ID"]: e for e in efek}
        self.zdarzenia = zdarz
        self.obiekty = obiekty            # ID → rekord dbobjects
        self.tech = {t["id"]: t for t in tech if t["seq"] >= 0}
        # technologie epok: głowy grup dbtechtree (typ technologii 2, numer epoki > 0)
        self.epoki = sorted((t for t in tech if t["glowa_grupy"] and t["epoka"] > 0), key=lambda t: t["epoka"])

    def zmiany_zdarzenia(self, event):
        if event is None or event < 0 or event >= len(self.zdarzenia):
            return []
        out = []
        for i in self.zdarzenia[event]["efekty"]:
            e = self.efekty.get(i)
            if e and e["Effect code"] == KOD_ZMIANY_GRAFIKI and e["Object 1"] >= 0 and e["New graphic"] >= 0:
                out.append((e["Object 1"], e["New graphic"], i))
        return out

    def numer_epoki(self, tech_id):
        t = self.tech.get(tech_id)
        return t["epoka"] if t and t["glowa_grupy"] else 0

    def mapa_grafik(self, tech_epoki, zbadane=()):
        """Słownik obiekt → grafika (tylko obiekty zmienione) dla gracza w epoce `tech_epoki` (ID technologii)."""
        nr = self.numer_epoki(tech_epoki)
        m = {}
        for ep in self.epoki:
            if ep["epoka"] > nr:
                break
            for ob, gr, _ in self.zmiany_zdarzenia(ep["event"]):
                m[ob] = gr
        for tid in zbadane:
            t = self.tech.get(tid)
            if t and not t["glowa_grupy"]:
                for ob, gr, _ in self.zmiany_zdarzenia(t["event"]):
                    m[ob] = gr
        return m

    def grafika(self, obiekt, tech_epoki, zbadane=()):
        m = self.mapa_grafik(tech_epoki, zbadane)
        if obiekt in m:
            return m[obiekt]
        return int(self.obiekty.get(obiekt, {}).get("Graphic ID", -1))
