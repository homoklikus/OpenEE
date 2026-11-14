#!/usr/bin/env python3
"""Testy narzędzi etapów 30–34 bez danych gry: pomiar_core (walidacja, konwersja ruchu i walki), struktury (schemat), switch_titan,
efekty_obszaru (zestawy jednostek, etap 34).
Uruchomienie: python3 narzedzia/titan/test_titan_narzedzia.py"""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pomiar_core as P  # noqa: E402
import struktury as S  # noqa: E402
import efekty_obszaru as EF  # noqa: E402


def jedn(x, stan=5000, typ=422, **kw):
    d = {"x": x, "y": 10.5, "v": 0.0, "stan": stan, "kontakty": 0, "k248": 0.0, "m01": 0.0, "m11": 1.0, "typ": typ,
         "trasa_n": 0, "punkt_ost": None}
    d.update(kw)
    return d


def pomiar(n=5):
    pr = []
    for k in range(n):
        pr.append({"t": 1000 + round(k * P.TAKT_MS), "rng": 12345 + k, "0x1000001": jedn(10.5 + 0.01 * k)})
    return {"wariant": "ee", "jednostki": ["0x1000001"], "probki": pr, "pominiete_niespojne": 0}


class TestPomiarCore(unittest.TestCase):
    def test_poprawny(self):
        self.assertTrue(P.waliduj(pomiar())["ok"])

    def test_brak_probki(self):
        d = pomiar(); del d["probki"][2]
        w = P.waliduj(d)
        self.assertFalse(w["ok"]); self.assertIn("brakujące próbki", " ".join(w["bledy"]))
        self.assertTrue(P.waliduj(d, dopusc_luki=True)["ok"])

    def test_duplikat_taktu(self):
        d = pomiar(); d["probki"][3]["t"] = d["probki"][2]["t"]
        self.assertIn("duplikat taktu", " ".join(P.waliduj(d)["bledy"]))

    def test_bledny_id(self):
        d = pomiar(); d["jednostki"] = ["123"]
        self.assertIn("błędny identyfikator", " ".join(P.waliduj(d)["bledy"]))

    def test_brak_jednostki_w_probce(self):
        d = pomiar(); del d["probki"][1]["0x1000001"]
        self.assertIn("brak jednostki", " ".join(P.waliduj(d)["bledy"]))

    def test_niespojny_odczyt_ostrzezenie(self):
        d = pomiar(); d["pominiete_niespojne"] = 3
        w = P.waliduj(d)
        self.assertTrue(w["ok"]); self.assertTrue(w["ostrzezenia"])

    def test_zmiana_wariantu(self):
        self.assertIn("zmiana wariantu", " ".join(P.waliduj(pomiar(), "aoc")["bledy"]))

    def test_brak_pola(self):
        d = pomiar(); del d["probki"][0]["0x1000001"]["k248"]
        self.assertIn("brak pól", " ".join(P.waliduj(d)["bledy"]))

    def test_nieznany_parametr(self):
        with self.assertRaises(P.BladPomiaru):
            P.konwertuj(pomiar(), "t", {"422": {"vmaks": 1.0}})

    def test_nieznany_typ(self):
        d = pomiar()
        for p in d["probki"]:
            p["0x1000001"]["typ"] = 999
        with self.assertRaises(P.BladPomiaru):
            P.konwertuj(d, "t")

    def test_konwersja_astar(self):
        d = pomiar(6)
        for p in d["probki"][3:]:
            p["0x1000001"].update(trasa_n=3, punkt_ost=[20.5, 10.5, 0.0, 10.0])
        s = P.konwertuj(d, "t")
        self.assertEqual(s["tryb_rozkazow"], "astar")
        self.assertEqual(s["jednostki"][0]["rozkazy"], [{"takt": 3, "tryb": "rozkaz", "x": 20.5, "y": 10.5,
                         "zrodlo": "cel = ostatni punkt trasy z pamięci; trasa z A* w Core"}])
        self.assertEqual([p["takt"] for p in s["jednostki"][0]["probki"]], list(range(6)))


class TestStruktury(unittest.TestCase):
    def test_schemat_repozytorium(self):
        s = S.wczytaj()
        self.assertEqual(S.waliduj_schemat(s), [])

    def test_wykrywa_nakladanie_i_pewnosc(self):
        s = copy.deepcopy(S.wczytaj())
        pola = s["struktury"]["EEUnit"]["pola"]
        pola.append(dict(pola[0], nazwa="zly", ee="0x0C", pewnosc="X"))
        bl = " ".join(S.waliduj_schemat(s))
        self.assertIn("nakładają się", bl); self.assertIn("pewność X", bl)

    def test_markdown(self):
        self.assertIn("| v | f32 | 0x238 | 0x238 | [P]", S.markdown(S.wczytaj()))


class TestWalka(unittest.TestCase):
    """Konwersja okna walki (etap 31): błędne dane muszą dawać czytelny BladPomiaru, nie cichą serię."""

    def test_zakres_poza_pomiarem(self):
        with self.assertRaises(P.BladPomiaru) as k:
            P.walka(pomiar(), 3, 99, ["0x1000001"], {}, "x")
        self.assertIn("poza pomiarem", str(k.exception))

    def test_brak_surowych_pol_walki(self):
        with self.assertRaises(P.BladPomiaru) as k:
            P.walka(pomiar(), 0, 5, ["0x1000001"], {}, "x")
        self.assertIn("surowych bajtów", str(k.exception))

    def test_nieznany_cel(self):
        d = pomiar()
        d["probki"][0]["0x1000001"]["kolejka"] = {"poziomy": [{"cele": [{"klasa": "EEUGGather"}]}]}
        with self.assertRaises(P.BladPomiaru) as k:
            P.walka(d, 0, 5, ["0x1000001"], {}, "x")
        self.assertIn("nieobsługiwany", str(k.exception))


class TZestawyJednostek(unittest.TestCase):
    """Etap 34: zestaw jednostek dbunitset jak EE 0x52BFA4 (rodziny z wyjątkami-obiektami, obiekty, włącz/wyłącz)."""
    def setUp(self):
        def zest(i, rodz=(), obj=(), inc=0, exc=0):
            d = {"ID": i, "Include unit set...": inc, "Exclude unit set": exc}
            for k in range(8):
                d["Family ID" + ("" if k == 0 else f"#{k + 1}")] = rodz[k] if k < len(rodz) else 0
                d["Object ID" + ("" if k == 0 else f"#{k + 1}")] = obj[k] if k < len(obj) else -1
            return d
        self.ob = {1: {"Family ID": 4}, 2: {"Family ID": 4}, 3: {"Family ID": 7}, 4: {"Family ID": 9}}
        self.us = [zest(1, rodz=(4,), obj=(2,)), zest(2, obj=(3,)), zest(3, rodz=(4,), inc=2, exc=4), zest(4, obj=(1,))]
        self.n = EF.zestawy(self.us, self.ob)

    def test_rodziny_z_wyjatkiem(self):
        self.assertEqual([t for t in self.ob if self.n(1, t)], [1])        # rodzina 4 bez obiektu 2

    def test_tylko_obiekty(self):
        self.assertEqual([t for t in self.ob if self.n(2, t)], [3])

    def test_wlacz_wylacz(self):
        self.assertEqual([t for t in self.ob if self.n(3, t)], [2, 3])     # 1 wyłączony zestawem 4, 3 z zestawu 2


class WysokoscObiektow(unittest.TestCase):
    """Etap 54: wysokość obiektów SCN względem terenu (wysokosc_obiektow.py) i wysokość kopii wzoru w generatorze
    scenariuszy testowych (scenariusz_testowy_kolizji.wysokosc_kopii) – siatki syntetyczne, bez danych gry."""

    def setUp(self):
        import importlib
        import wysokosc_obiektow as W
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "eksperymenty"))
        self.W = W
        self.G = importlib.import_module("scenariusz_testowy_kolizji")
        # teren: płaskowyż 1,0 dla x < 4, stok do 0 między x = 4 i 5, dalej 0; pas wody (−0,5) dla y ≥ 8
        self.h = {(x, y): (-0.5 if y >= 8 else (1.0 if x <= 4 else 0.0)) for x in range(0, 11) for y in range(0, 11)}

    def test_interpolacja_trojkatow(self):
        h = {(0, 0): 0.0, (1, 0): 1.0, (0, 1): 2.0, (1, 1): 4.0}
        self.assertAlmostEqual(self.W.wysokosc_terenu(h, 0.5, 0.5), 2.0)       # przekątna (0,0)–(1,1)
        self.assertAlmostEqual(self.W.wysokosc_terenu(h, 0.75, 0.25), 1.5)     # trójkąt h00, h10, h11
        self.assertAlmostEqual(self.W.wysokosc_terenu(h, 0.25, 0.75), 2.0)     # trójkąt h00, h01, h11
        self.assertIsNone(self.W.wysokosc_terenu(h, 5.0, 5.0))

    def test_podejrzane(self):
        ob = [{"gracz": 1, "id": 1, "typ": 32, "x": 6.5, "y": 2.5, "z": 1.02, "teren": 0.0, "dz": 1.02},     # lewituje
              {"gracz": 1, "id": 2, "typ": 34, "x": 2.0, "y": 2.0, "z": 1.01, "teren": 1.0, "dz": 0.01},     # budynek +0,01
              {"gracz": 1, "id": 3, "typ": 110, "x": 5.5, "y": 9.5, "z": 0.0, "teren": -0.5, "dz": 0.5},     # okręt na wodzie
              {"gracz": 0, "id": 4, "typ": 359, "x": 1.0, "y": 1.0, "z": 9.0, "teren": 1.0, "dz": 8.0}]      # obiekt Świata
        self.assertEqual([o["id"] for o in self.W.podejrzane(ob)], [1])

    def test_kopia_stoi_na_terenie(self):
        k = self.G.wysokosc_kopii
        # wzór na płaskowyżu 1,0 (z = 1,0) przeniesiony na teren 0 → 0; budynek z przesunięciem +0,01 zachowuje je
        self.assertAlmostEqual(k(self.h, self.h, (2.5, 2.5, 1.0), 6.5, 2.5), 0.0)
        self.assertAlmostEqual(k(self.h, self.h, (2.0, 2.0, 1.01), 7.0, 3.0), 0.01)
        # stok: wysokość z interpolacji w nowym miejscu
        self.assertAlmostEqual(k(self.h, self.h, (2.5, 2.5, 1.0), 4.5, 2.5), 0.5)

    def test_kopia_plywajaca_i_bledy(self):
        k = self.G.wysokosc_kopii
        self.assertAlmostEqual(k(self.h, self.h, (5.5, 9.5, 0.0), 6.5, 9.5), 0.0)      # okręt: poziom wody bez zmian
        with self.assertRaises(SystemExit):
            k(self.h, self.h, (5.5, 9.5, 0.0), 6.5, 2.5)                              # okręt na lądzie
        with self.assertRaises(SystemExit):
            k(self.h, self.h, (6.5, 2.5, 1.84), 7.5, 2.5)                             # wzór sam lewituje – wymaga jawnej decyzji


if __name__ == "__main__":
    unittest.main()
