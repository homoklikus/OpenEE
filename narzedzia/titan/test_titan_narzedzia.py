#!/usr/bin/env python3
"""Testy narzędzi etapów 30–31 bez danych gry: pomiar_core (walidacja, konwersja ruchu i walki), struktury (schemat), switch_titan.
Uruchomienie: python3 narzedzia/titan/test_titan_narzedzia.py"""
import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pomiar_core as P  # noqa: E402
import struktury as S  # noqa: E402


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


if __name__ == "__main__":
    unittest.main()
