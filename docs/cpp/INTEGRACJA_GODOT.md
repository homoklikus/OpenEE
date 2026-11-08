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
