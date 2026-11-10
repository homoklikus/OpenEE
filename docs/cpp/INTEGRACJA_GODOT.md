# Integracja OpenEE Core z Godot (GDExtension)

## 1. Przepływ danych

```text
GDScript (core_cpp.gd, sceny) ──► OpenEESymulacja (GDExtension, godot-cpp) ──► openee::Swiat (Core C++)
        ▲                                                                              │
        └──────────── PackedFloat64Array / Dictionary (migawka, diagnostyka) ◄──────────┘
```
- GDScript przygotowuje dane wejściowe (ścieżka DLL, parametry, punkty trasy) i rysuje migawkę. **Nie liczy ruchu.**
- `OpenEESymulacja` (`cpp/gdextension/src/`) tylko konwertuje dane. Stan świata należy do Core (`std::unique_ptr`).
  Do GDScript nie trafiają wskaźniki – tylko identyfikatory jednostek i kopie stanu.

## 2. API klasy `OpenEESymulacja` (RefCounted)

| Metoda | Działanie |
|---|---|
| `wersja() -> String` | wersja Core, godot-cpp i API |
| `zaladuj_tablice(sciezka_dll) -> Dictionary` | `{ok, komunikat, wariant, sha256}`; po sukcesie trzeba utworzyć świat |
| `uzyj_tablic_przyblizonych()` | tryb diagnostyczny (ostrzeżenie, `tablice_zgodne = false`) |
| `utworz_swiat(wariant) -> bool` | `"ee"` / `"aoc"`, teren syntetyczny etapu 27; false bez tablic |
| `dodaj_jednostke(parametry, x, y, kurs) -> int` | klucze: `a, vmax, alfa, wmax, rozmiar, c4, c8, t488, pochyla`; zwraca id (0 = błąd) |
| `nadaj_trase(id, punkty_xy, kurs_koncowy, start) -> bool` | `PackedFloat64Array [x0, y0, x1, y1, …]`, kurs `float` albo `null`, start `"rozkaz"` (8000) / `"advance"` |
| `rozkaz_ruchu(id, x, y, kurs_koncowy, shift) -> bool` | etap 29: rozkaz do punktu z kolejką celów; trasa z A* w Core |
| `ustaw_przejezdnosc(ix, iy, przejezdne)` | etap 29: przejezdność pola terenu syntetycznego |
| `takt(ile) -> int` | wykonuje `ile` taktów w jednym wywołaniu; zwraca licznik taktów |
| `migawka() -> PackedFloat64Array` | 12 pól na jednostkę (`pola_migawki()`), kolejność listy Core |
| `pola_migawki() -> PackedStringArray` | `id, x, y, z, v, omega, kurs, stan, tryb, zdjete_punkty, pozostalo_punktow, licznik_blokady_ms` |
| `jednostka(id) -> Dictionary` | jak wyżej + `stan_nazwa`, `macierz` (9 wartości) |
| `diagnostyka() -> Dictionary` | tablice, wariant, takty, zegar, dt, stan i liczba losowań RNG, zdarzenia nieobsługiwane, lista podsystemów ze statusem |
| `wczytaj_mape_scn(A, B, tekstura, flagi, f10, wysokosc, rodziny) -> Dictionary` | etap 30: surowe tablice kawałka 4 (z `ScenariuszEE.teren`) → `MapaTitan` w Core; `{ok, szerokosc, brzeg_s1/s2/d, skrot}` |
| `dodaj_obiekt_mapy(obiekt) -> bool` | etap 30: `{id, typ, gracz, X, Y, kwadrat, blokuje}` |
| `mapa_teren(x, y) -> int` / `mapa_pewnosc(x, y) -> int` | etap 30: teren komórki Titan (−1 poza mapą) / 0 pamięć gry, 1 reguła, 2 niepewne, 3 brak |
| `utworz_swiat_na_mapie(wariant, teren_dozwolony) -> bool` | etap 30: świat Core na siatce z mapy (16 bajtów tablicy typu +0x5D6) |
| `pole_przejezdne(x, y) -> bool` | etap 30: przejezdność pola w świecie Core |

- Liczby przechodzą jako `float` GDScript (f64), więc wartości f32 z Core trafiają do Godota bez strat.
  `Vector2` (f32) nie jest używany na granicy.
- Jeden takt to jedno wywołanie, a migawka całego świata to drugie. Nie ma osobnych wywołań na jednostkę i pole.

## 3. Przykład

```gdscript
var sym: Object = CoreCpp.nowa_symulacja()          # null, gdy biblioteka niezbudowana
var r: Dictionary = sym.zaladuj_tablice(CoreCpp.znajdz_dll("ee", Konfiguracja))
if r["ok"] and sym.utworz_swiat("ee"):
    var id: int = sym.dodaj_jednostke({"a": 2.0, "vmax": 0.6, "alfa": 12.21731, "wmax": 13.96264,
        "rozmiar": 0.5, "c4": 0.5, "c8": 0.08185, "t488": 0.5}, 10.5, 10.5, 0.0)
    sym.nadaj_trase(id, PackedFloat64Array([10.5, 15.5]), null, "rozkaz")
    sym.takt(300)
    print(sym.jednostka(id))
```

Scena diagnostyczna: `./uruchom_openee.sh core` (`godot/sceny/diag_core.tscn`).
- Wybór gry: 1/2.
- Przypadek: ←/→.
- Start: spacja.
- Jeden takt: N.
- `--auto=N` – N taktów bez okna i wypis wyniku.

## 4. Cykl życia

- `OpenEESymulacja` to `RefCounted`. Zwolnienie ostatniej referencji niszczy świat Core.
- `zaladuj_tablice` / `uzyj_tablic_przyblizonych` usuwają istniejący świat, bo zmieniają matematykę.
- Core nie zna węzłów sceny. Takt wywołuje GDScript, np. w `_process` albo ze stałym krokiem gry.
  Czas gry wynika z liczby taktów (34,09 ms), a nie z czasu klatki.
- Rozszerzenie ładuje się na poziomie `MODULE_INITIALIZATION_LEVEL_SCENE`. `reloadable = false`.
- **Brak biblioteki:** Godot wypisuje błąd ładowania `openee.gdextension`, a `CoreCpp.dostepny()` zwraca false.
  Starsze sceny i 324 testy działają bez zmian (sprawdzone).

## 5. Rozbudowa bez logiki w GDScript

1. Nowy mechanizm najpierw w Core: moduł, testy natywne, przypadki referencyjne.
2. W `OpenEESymulacja` dodać tylko metodę przekazującą dane, np. rozkaz jako `Dictionary` → struktura Core.
3. Kolejne pola stanu dopisywać do migawki z nazwą w `pola_migawki()`. GDScript czyta je po nazwie.
4. Diagnostyka: liczniki w `openee::Diagnostyka`, status w `podsystemy()`.
5. Nie przenosić decyzji (prędkość, obrót, kolizje, losowania) do GDScript, także „tymczasowo”.

## 6. Etap 31 – walka przez GDExtension

Metody `OpenEESymulacja` (tylko przekazanie danych; decyzje w Core):
- `ustaw_walke(id, gracz, czlowiek, parametry: Dictionary, hp) -> bool` – parametry walki jednostki (atak, pancerz,
  zasięg, LOS, przeładowanie, klasy tablic, łuk, rozmiar, szukanie…);
- `ustaw_tablice_walki(tabele: Dictionary, wagi: Array) -> bool` – tablice obrażeń (trudność, mnożniki,
  trafienie 08/0C/10) i trzy rekordy wag wyboru celu z gry (odczyt `walka_tabele` / `walka_priorytety`);
- `rozkaz_ataku(id, cel) -> bool` – cel ataku w kolejce celów (jak rozkaz gracza);
- `walka(id) -> Dictionary` – migawka: HP, liczniki przeładowania i szukania, cel, stan;
- `zdarzenia_walki() -> Array` – zdarzenia z ostatnich taktów (do animacji i dźwięków).

Godot nie liczy celu, zasięgu, obrotu ani obrażeń. Test: `godot/testy/testy_gdextension.gd` – „walka w Core przez
GDExtension” (ten sam pojedynek co `core_walka_swiat`: wybory 2, śmierci 1, HP 103 / 0).

## 17. Etap 36 – pierwsza grywalna potyczka (Core jako jedyna symulacja)

Nowe metody `OpenEESymulacja` (OpenEE Core 0.10.0):
- `stan_jednostek() -> Array` – migawka wszystkich jednostek po takcie: `{id, x, y, z, v, kurs, stan, tryb, gracz}`
  oraz dla jednostek z walką `{hp, hp_max, animacja, cel}` (cel = id jednostki z celu EEUGAttackUnit, 0 – brak);
- `zdarzenia_walki_od(od) -> Array` – zdarzenia walki od indeksu `od` (`indeks, takt, kto, cel, rodzaj, wartosc`;
  rodzaje: `wybor_celu`, `atak`, `trafienie`, `smierc`) – odczyt przyrostowy bez kopiowania całej historii;
- `ustaw_wrogow(g1, g2, wrog)` – dyplomacja par graczy; `takty() -> int`.

Warstwy po stronie Godota (bez logiki gry):

| Warstwa | Plik | Rola |
|---|---|---|
| model widoku | `godot/silnik/symulacja/symulacja_core.gd` (`SymulacjaCore`) | `krok()` = `takt(1)` + odczyt `stan_jednostek` i nowych zdarzeń; przepisuje pozycje/kursy do `JednostkaSym` (te same obiekty co stara symulacja GDScript), stan animacji z numeru stanu `.tai` (2001/2021 atak, 6000–6003 śmierć, v > 0 ruch); rozkazy gracza → `rozkaz_ruchu` / `rozkaz_ataku` tylko dla jednostek gracza lokalnego i tylko na żywe cele |
| stały krok | `zegar_symulacji.gd` | akumulator czasu, `KROK` = 0,35 s / 15 (takty EE 42,857/s), interpolacja `alfa` – render niezależny od tempa logiki |
| render | `widok_jednostek.gd` | modele CEM/MultiMesh, animacje VAT, synchronizacja po stabilnym id Core; `ukryj(id)` dla zwłok (prezentacja) |
| wejście | `sterowanie_rts.gd`, `zaznaczanie.gd`, `zaznaczenie_ee.gd` | LPM, ramka, PPM w teren (Shift – kolejka Core), PPM na wrogu – atak |
| scena | `godot/sceny/potyczka.gd`, `potyczka.tscn` (launcher: tryb 4) | mapa SCN → `wczytaj_mape_scn` + obiekty blokujące, jednostki z `dane/potyczka/*.json`, paski HP, zdarzenia, wynik, restart (nowy świat Core) |

Zasady: jeden autorytatywny `Swiat`; GDScript nie liczy ruchu, kolizji, tras ani walki; parametry ruchu i walki są
wyłącznie w pliku danych potyczki (pomiary) i trafiają do Core bez przeliczeń. Restart tworzy nowy obiekt
`OpenEESymulacja` i nowe warstwy widoku (węzły zdejmowane przez `remove_child` + `queue_free`).

Testy: `testy_gdextension.gd` – potyczka przez `SymulacjaCore` (rozkazy → wynik), determinizm (te same rozkazy w tych
samych taktach → ten sam skrót i kolejność zdarzeń), przerwanie ataku ruchem, zwłoki, sekwencja stanów rozkazu ataku
(619/620); rzeczywisty przebieg sceny z renderem: `xvfb-run … res://sceny/potyczka.tscn -- --potyczka-demo=70
--potyczka-restart --potyczka-zrzuty=… --potyczka-raport=…` (zdarzenia wejścia przez `Input.parse_input_event`).

## 18. Etap 37 – kąt szyku w rozkazie ruchu

Nowa metoda `kat_rozkazu(ids: Array, x, y) -> float` (OpenEE Core 0.11.0): kąt szyku PPM z oryginału (środek
prostokąta zaznaczonych jednostek → punkt kliknięcia, UMArcTan2). `SymulacjaCore.rozkaz_grupy` liczy go w chwili
kliknięcia i podaje jako kurs końcowy do `rozkaz_ruchu` – jednostki obracają się na końcu ruchu jak w EE (9006).
Testy GDExtension: 30 (+2: kąt z pomiaru 616, ponowny wybór celu nieosiągalnego po 30 s).

## 19. Etap 38 – OpenEE Core 0.12.0 (testy GDExtension: 33)

- `ustaw_modyfikator_wysokosci(wlaczony: bool)` – reguły 0x61E500 z cfg gry (`ModyfikatorWysokosci::z_gry`).
- `ustaw_efekty_obszaru(dane: Dictionary) -> int` i `odtworz_efekty_obszaru()` – szablony i budynki w formacie
  narzędzia `narzedzia/titan/efekty_obszaru.py` (jak `wczytaj_efekty` w testach Core); `morale(id) -> Array`.
- `ustaw_walke`: nowe klucze `regeneracja` (typ+0x578), `regeneracja_ms` (stan licznika +0x290 na starcie),
  `ai_szuka_wrogow`, `ai_poscig_poza_icl`, `ai_wraca_do_icl`, `ai_moze_swobodnie` (domyślne jak dotąd).

## 20. Etap 39 – OpenEE Core 0.13.0 (testy GDExtension: 34)

- `walka(id)["kolejka"]` – pełna kolejka celów jednostki: `rodzaj` (EEUGAttackUnit / EEUGLocation), `x`, `y`, `cel`,
  `od_gracza`, `proby`. Godot tylko odczytuje; wybór miejsca podejścia (0x63234D) liczy Core.

## 21. Etap 40 – OpenEE Core 0.14.0 (testy GDExtension: 38)

- `ustaw_graf_podsektorow(dane: Dictionary) -> int` – graf podsektorów w formacie odczytu Riverlands_MCP
  `podsektory` (tryb diagnostyczny „graf z gry”; budowa podsektorów w Core nieodtworzona).
- `sciezka_grafu(x0, y0, x1, y1) -> Array` – ścieżka A* grafu (od celu do startu).
- `diagnostyka()`: `graf_z_gry`, `graf_prosby`, `graf_punkty`, `graf_ostatnia`.

## 22. Etap 41 – OpenEE Core 0.15.0 (testy GDExtension: 40)

- `zbuduj_graf_z_przydzialu(id_xH: PackedInt32Array, W, H, komorka) -> int` – graf z przydziału pól (punkty
  0x42C2D5 i sąsiedzi 0x4246E8 liczone w Core); `diagnostyka()["graf_zrodlo"]` – jawne źródło grafu.

## 23. Etap 42 – OpenEE Core 0.16.0 (testy GDExtension: 44)

- `zbuduj_graf_z_wejscia(wejscie: Dictionary, komorka) -> Dictionary` – regiony 0x4240D3, przydział podsektorów
  0x42434F, punkty i sąsiedzi w Core; słownik w układzie odczytu Riverlands_MCP `regiony_wejscie` (N, rodzaj_pola,
  bajt14 / siatka_wys, obiekty pól, typy, brzeg; `obszar` i `obszary_rodzaj_id` opcjonalne – bez nich obszary z
  modelu pomiarowego). Wynik: `regionow`, `obszarow`, `podsektorow`, `regiony` i `przydzial` (PackedInt32Array, x·N + y);
  graf instalowany w świecie, `diagnostyka()["graf_zrodlo"]` = „Core z wejścia mapy”.
- Logika wyłącznie w Core (`zbuduj_obszary`, `zbuduj_siatke_regionow`, `zbuduj_przydzial_podsektorow`, `zbuduj_graf_z_wejscia`).
