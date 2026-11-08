# OpenEE Core (C++) – architektura

Od etapu 28 deterministyczna symulacja OpenEE powstaje jako natywny rdzeń w C++20 (**OpenEE Core**). Godot zostaje
warstwą prezentacji: renderowanie, kamera, interfejs, animacje, dźwięk, wejście, narzędzia diagnostyczne. Obie warstwy
łączy cienka biblioteka **GDExtension**. Wzorem architektonicznym jest OpenMW: mechanika gry jako niezależny silnik,
niepodporządkowany systemowi scen. Kodu OpenMW ani Titan nie kopiujemy – Core implementuje zachowania opisane w
atlasie `docs/titan/`.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Podział i zależności

```text
OpenEE/
├── CMakeLists.txt                 cele: openee_core, openee_tests, openee_gdextension
├── cpp/
│   ├── core/include/openee/       nagłówki Core (bez Godota)
│   ├── core/src/                  implementacja Core
│   ├── tests/                     testy natywne (CTest), dane referencyjne trygonometrii
│   ├── gdextension/src/           OpenEESymulacja (godot-cpp) – jedyne miejsce z zależnością od Godota
│   ├── cmake/                     flagi zmiennoprzecinkowe
│   └── thirdparty/godot-cpp       submoduł Git, tag 10.0.0-stable (507ed9d)
├── godot/openee.gdextension       opis rozszerzenia dla Godota
├── godot/bin/                     zbudowane biblioteki (poza repozytorium)
└── godot/silnik/symulacja/core_cpp.gd   pomocnik GDScript (dane wejściowe, bez obliczeń ruchu)
```

```text
openee_tests ──► openee_core ◄── openee_gdextension ──► godot-cpp ──► Godot 4.7
                 (C++20, std)       (konwersja danych)
```

**Warunek niezależności:** `openee_core` kompiluje się i działa bez Godota. Nie używa `godot::Object`, `Node`,
`Vector2/3`, `RefCounted` ani scen. Typy własne: `Punkt2`, `Macierz3`, `Jednostka`, `Swiat`. Biblioteka standardowa
C++ wystarcza – brak innych zależności.

## 2. Moduły Core

| Moduł | Pliki | Zawartość | Źródło w atlasie |
|---|---|---|---|
| arytmetyka | `f32.hpp` | `f32()` z barierą, `rint_parzyste`, `podloga`, bity f32 | `precyzja_numeryczna.md` § 3–5 |
| tablice DLL | `tablice_dll.hpp/.cpp` | odczyt PE jako danych, deskryptory wariantów, SHA-256, FNV-1a, kontrola wartości; tryb przybliżony | § 2.5 |
| matematyka | `matematyka.hpp/.cpp` | `um_cos`, `um_sin`, `um_arccos`, `um_arctan2`, `set_orientation_ypr`, kurs z macierzy, kąt do celu, normalizacja | § 2 |
| generator | `generator.hpp/.cpp` | LCG Titan, licznik losowań, odległość stanów | `kolizje_objazdy.md` § 5 |
| teren | `teren.hpp/.cpp` | siatka wierzchołków, `get_mesh_z`, nachylenie, teren syntetyczny etapu 27 | `fizyka_terenu.md` § 1–3 |
| wariant | `wariant.hpp` | `WariantTitan`: reguła obrotu, kolejność odbudowy kontaktów | `precyzja_numeryczna.md` § 6 |
| jednostka | `jednostka.hpp` | `ParametryRuchu`, `Jednostka` (stan ruchu, trasa, liczniki) | `ruch_jednostki.md` § 3 |
| fizyka | `fizyka.hpp/.cpp` | `FizykaLadowa`: tryby 0/3/4/5, obrót EE/AoC, BO-7, reguła 45°, reguła stoku | `ruch_jednostki.md` § 5–8 |
| maszyna stanów | `maszyna_stanow.hpp/.cpp` | parser podzbioru `.tai`, skrypt wbudowany `land` (z tabeli atlasu), numery stanów | `skrypty_stanow.md` |
| kolizje | `kolizje.hpp/.cpp` | wzór odpychania 0x549179 | `walidacja_kolizji.md` § 2 |
| świat | `symulacja.hpp/.cpp` | `Swiat`: jednostki, takt, zdarzenia, akcje wejścia, migawka, diagnostyka | `specyfikacja_ruchu_godot.md` § 3 |
| interfejsy | `interfejsy.hpp` | `INawigacja`, `IKolejkaCelow`, `IGrupy`, `IKolizje`, status podsystemów | – |
| mapa (etap 30) | `mapa.hpp/.cpp` | `MapaTitan`: romb z SCN, linie brzegu, wysokości z maską istnienia, teren komórek (reguła + nadpisanie z pamięci gry, pewność pola), obiekty n×n, siatka dla typu | `import_mapy.md` |
| walka (etap 30) | `walka.hpp/.cpp` | `ParametryWalki`, `StanWalki`, `oblicz_obrazenia` (0x61DE61), `przyjmij_obrazenia` (0x6172BC), wybór tablicy trafień (część rozpoznana), `PojedynekTitan` (cykl 2012→2001→2021, licznik +0x2A0, moment trafienia) | `walka.md` |
| nawigacja (etap 29) | `nawigacja.hpp/.cpp` | `AStarTitan`: lista otwarta (lista + 53 kubełki, uzupełnianie po 15), zamknięta, sąsiedzi, reguła narożników, koszty 10/14 + kary, limity, wybór najbliższego, Bounded (koniec bez testu dostępności), przebieg rozwijania | `astar_pola.md`, `astar_wyniki.md` |

## 3. Arytmetyka i determinizm

- Wartości rejestru x87 (PC_53) to `double`. Zapis do pamięci f32 w oryginale to `f32()` w kodzie. Kolejność działań
  jest przepisana z modelu v4 (etap 27) wyrażenie po wyrażeniu.
- Flagi: `-std=c++20` (bez rozszerzeń GNU), `-ffp-contract=off`, bez `-ffast-math`
  (`cpp/cmake/OpenEEFlagi.cmake`). `f32.hpp` przerywa kompilację przy `__FAST_MATH__` albo `FLT_EVAL_METHOD != 0`.
- **Bariera w `f32()`** (pusty `asm volatile` z ograniczeniem rejestru SSE/NEON) – dodana po wykryciu, że GCC 11.4
  z `-O3` (wektoryzacja SLP w `fizyka.cpp`) zmieniał wynik o 1 ulp w takcie 9 przypadku S1. `-O0`/`-O2` i GCC 13 tego
  nie robią (`docs/cpp/BUDOWANIE.md` § 4). Bariera nie dodaje instrukcji.
- Indeksy tablic: `rint_parzyste` liczone ręcznie, niezależnie od trybu zaokrąglania procesu.
- Kolejność jednostek: `std::vector` w kolejności dodania, takt od końca listy (0x547AAD). Identyfikatory to liczby
  nadawane przez `Swiat` (nie wskaźniki). Brak iteracji po kontenerach nieuporządkowanych.
- Jeden `GeneratorTitan` na świat. Losowania:
  - 2 na takt na początku taktu – [W]: adresy 0x546CE9 i 0x547C09, cel nieustalony;
  - 1 przy każdej ocenie ObstacleDetected (Advance, gdy punkt nie został osiągnięty);
  - wejście w Idle – warunkowe losowania niewdrożone [N], zliczane w diagnostyce.

## 4. Jednostka i dane

- `Jednostka` przechowuje znaczenie pól z EXE (przesunięcie EE w komentarzu), ale nie odwzorowuje układu pamięci
  32-bitowego procesu.
- **Orientacja to pełna macierz 3×3 (f32 jako double).** Kurs jest zawsze czytany z macierzy przez `UMArcTan2`
  (kwantowanie jak w Titan). Osobnego pola kąta nie ma.
- Trasa: wektor punktów f32, indeks zdjętych punktów i sumy długości odcinków (f32) do warunku R ≤ S.
- **Parametry ruchu** (`ParametryRuchu`) są wartościami wejściowymi:
  - z bazy gry będą to wartości f32;
  - zestaw syntetyczny podaje je dziesiętnie (np. α = 12,21731), tak jak model v4;
  - `a` i `vmax` są zaokrąglane do f32 w fizyce, jak w modelu;
  - czy α, ωmax, c4, c8 w oryginale wchodzą do obliczeń jako f32 z rekordu typu, nie zmienia wzorów – zależy od
    danych wejściowych [W].
- `tps = 1/dt` w rejestrze (model v4). Wariant z f32 EEPhysics+0x88 jest możliwy [N] – do sprawdzenia przy
  porównaniu z pomiarem obrotu.

## 5. Wariant EE / AoC

Struktura `WariantTitan` (`wariant.hpp`) jest jedynym miejscem różnic:
- `RegulaObrotu::ee` / `aoc` – wybór w `FizykaLadowa::obrot`;
- `OdbudowaKontaktow::po_zapisie` / `przed_zapisem` – przygotowane pod listę kontaktów (niewdrożoną).

Tablice, prędkość, zapisy f32 i teren są wspólne [P].

## 6. Takt

`Swiat::takt()` (EEPhysics 0x546C63):
1. czas gry += 1000·1,5/44 ms (zegar ms jako u32 do BO-8);
2. 2 losowania globalne;
3. jednostki od końca listy:
   - krok maszyny stanów (najwyżej jedno przejście, leniwa ocena AND/OR, akcja wejścia, BO-8 w Idle);
   - fizyka według trybu;
   - krok końcowy: przy braku kontaktów i pchania licznik blokady = 0.

## 7. Maszyna stanów

- **Parser podzbioru `.tai`:**
  - stany, przejścia z jednym zdarzeniem, `allof`/`anyof`, `true()`/`false()`, `remove()`;
  - zastępowanie przejścia w miejscu, `#include`, komentarze jednym ukośnikiem;
  - zdarzeń z parametrami nie obsługuje – zgłasza błąd.
  - Lokalnie sparsował oryginalny `land.tai` z dołączeniami (34 stany). Przejścia stanów ruchu są identyczne ze
    skryptem wbudowanym (test `core_tai` z `OPENEE_TAI`).
- **Skrypt wbudowany `land`:** własny zapis tabeli z `skrypty_stanow.md` § 4 (bez kopii pliku gry).
- **Zdarzenia zaimplementowane:**
  - punkty trasy, ObstacleDetected z losowaniem;
  - typy celu (tylko „miejsce”), cel od gracza;
  - UnitFacingNotRequired / CompletedUnitFacing [W, model v4], AlwaysTrue.
- **Pozostałe zdarzenia** (walka, transport, mury, ICL) zwracają fałsz i są liczone w `Diagnostyka`.
- **Akcje wejścia:** Idle, Advance, GetNextMoveWaypoint, TurnToUnitFacing, ReacquireGoal (tryb 3 [H]).
  RepathAroundObstacle i stany walki są oznaczane jako niewdrożone.

## 8. Granice odpowiedzialności

- **Core:** stan świata, takt, matematyka, decyzje. Jedyny właściciel `Jednostka` i generatora.
- **GDExtension:** konwersja `Dictionary`/`PackedFloat64Array` ↔ typy Core, migawki, diagnostyka. Bez logiki gry.
- **GDScript:** wybór danych wejściowych (pliki, ścieżka DLL), wyświetlanie migawki. Bez obliczeń ruchu.

## 9. Niewdrożone (jawnie)

`podsystemy()` zwraca stan, widoczny w testach (`core_podsystemy`) i w diagnostyce GDExtension.

| Mechanizm | Stan |
|---|---|
| test pojedynczego kroku | niewdrożony – Core nie ma pól nieprzejezdnych |
| lista kontaktów, zastosowanie push (0x549A08), reguła (a) | niewdrożone; wzór 0x549179 – wdrożony i testowany |
| kolejka celów, Shift, punkty +0x32 | niewdrożone (jeden cel bieżący) |
| A*, graf podsektorów, objazd 9002 | niewdrożone; trasa podawana z zewnątrz, wejście w 9002 zliczane |
| grupy i szyk | niewdrożone |
| losowania przy wejściu w Idle | niewdrożone [N] |
| import mapy scenariusza do `TerenSiatka` | niewdrożony (teren syntetyczny) |

## 10. Tablice z DLL

| Wariant | SHA-256 pliku | TimeDateStamp | VA cos / acos |
|---|---|---|---|
| EE (GOG + NeoEE) | `0350ef77…e68b05b` | 0x3D7FC01B | 0x100D9130 / 0x100E9134 |
| AoC (GOG + NeoEE) | `4acf0404…cbefb` | 0x3D5D6AFB | 0x100DD8A4 / 0x100ED8A8 |
| EE (GOG, instalacja referencyjna) | `e3f6a2f6…eb003214` | 0x3D7FC01B | 0x100D9130 / 0x100E9134 |
| AoC (GOG, instalacja referencyjna) | `adbd1a05…50cf69` | 0x3D5D6AFB | 0x100DD8A4 / 0x100ED8A8 |

- Pełne sumy są w `tablice_dll.cpp`.
- Tablice są bajtowo identyczne (FNV-1a 0xC19C0CCE748B6A61 / 0x9635BBCFCB0049B6).
- Czysta instalacja GOG i instalacja z NeoEE mają inne sumy plików, ale ten sam rozmiar, znacznik czasu i adresy tablic.
  Sprawdzono to wyszukaniem bajtów tablic w obu plikach. Wykryte w etapie 28, gdy test Godota wybrał instalację
  referencyjną z konfiguracji.
- Loader:
  - sprawdza MZ/PE, i386/PE32 i tablicę sekcji;
  - liczy SHA-256 pliku i porównuje znacznik czasu oraz bazę obrazu;
  - przelicza VA → RVA → offset przez nagłówki sekcji;
  - sprawdza zakres sekcji, FNV tablicy, monotoniczność i odchyłkę od cos/acos < 2e-6.
- Nieznana wersja kończy się błędem z sumą pliku. Nie ma heurystycznego szukania tablic.

## 11. Etap 29 – nawigacja, test kroku, kolizje w takcie, kolejka celów

- **A\*** (`AStarTitan::szukaj`):
  - port modelu weryfikacyjnego etapu 24;
  - 18 syntetycznych przypadków bitowo zgodnych z modelem (trasa, kolejność rozwijania, iteracje, wywołania);
  - na mapie z gry (lokalnie) trasy A i C identyczne z grą, E: 145 iteracji w 8 wywołaniach = gra.
- **Prośba o trasę** (`Swiat::przygotuj_trase`):
  - Bounded (m = d + 4, d > 20 → d/20; prostokąt ±(m+1)), przy porażce pełne A* od końca Bounded (limit 3000);
  - punkty (x + 0,5; y + 0,5), pominięcie pola startu, ostatni punkt = dokładny cel [W];
  - **synchronicznie** – w grze pełne A* rozkłada się na kolejne takty, więc trasa jest gotowa później [W];
  - kary za stojące jednostki +50/+150 [W, bez pomiaru].
- **Przejezdność:**
  - `TerenSiatka::ustaw_przejezdnosc` / `pole_przejezdne`, linie brzegu rombu;
  - import z mapy scenariusza – niewdrożony.
- **Test kroku** (`FizykaLadowa::test_kroku`):
  - kolejność: to samo pole → teren/obiekty → przekątna (jedna komórka boczna) → ślizg y → ślizg x → cofnięcie;
  - przycięcie do brzegu, +0x248 przy ślizgu;
  - **zwykłe jednostki nie blokują pola** [P – pomiary 546/547]. Mechanizm +0x20C/+0x330 = 2 zostaje dla obiektów
    blokujących (callback `srodek_w_polu`, w świecie nieużywany, dopóki obiekty stałe nie są importowane).
- **Kolizje w takcie** (`Swiat::krok_koncowy`, `zastosuj_push`, `odbuduj_kontakty`):
  - lista kontaktów odbudowywana przy zmianie komórki – EE od nowej, AoC od starej pozycji [W];
  - **obiekt na listach pól swojego obrysu** [H, wspierane pomiarem 547: 0 taktów z inną obecnością kontaktu];
  - 0x549179 i reguła (a) (zaliczenie punktu – [H]), 0x549A08 (przycięcie, test pola, +0x248, dosadzenie);
  - budzik, kolejność od końca listy.
- **Kolejka celów** (`Swiat::rozkaz_ruchu`):
  - zwykły rozkaz: wyczyszczenie, cel na początek, 8000;
  - Shift: na koniec (bez celu – jak zwykły);
  - wejście w Idle zdejmuje cel i aktywuje następny;
  - punkty +0x32, porzucenie i BO-4 – niewdrożone.
- **9002:** A* w oknie ±50 pól – **niezweryfikowany dynamicznie**, liczony w `Diagnostyka::objazdy_niezweryfikowane`.

## 12. Etap 30 – mapa SCN, kontakty z okna pól, walka

- **Mapa:** `MapaTitan::z_scn` jest jedyną interpretacją danych SCN w projekcie (Godot przekazuje surowe tablice
  przez GDExtension, narzędzia Python tylko dekodują). `MapaTitan::siatka(teren_dozwolony)` buduje `TerenSiatka`
  z maską istnienia wierzchołków (romb) i przejezdnością: teren dozwolony dla typu, linie brzegu, obiekty
  blokujące n×n. `TerenSiatka::get_mesh_z` zwraca 0 poza rombem (jak 0x4C0201).
- **Kontakty:** okno pól wokół jednostki (R = max(0,5; 0,5·s)), kandydaci po polu obiektu (+0x1C/+0x20) – zamiast
  hipotezy obrysu z etapu 29 (`import_mapy.md` § 4).
- **Walka:** moduł niezależny od `Swiat` – wzór obrażeń, HP, przeładowanie i model pojedynku. Integracja z maszyną
  stanów `Swiat` (zdarzenia CanISeeEnemy, UnitInWeaponRange, FacingEnemyUnit…) – następny etap; do tego czasu
  zdarzenia walki w `Swiat` zostają fałszem z licznikiem (diagnostyka).
- **Narzędzie** `cpp/tools/openee_porownaj` – porównanie serii pomiarowej z Core (§ BUDOWANIE 5).

## 13. Etap 31 – walka w `Swiat`

- **Jedna lista jednostek, jeden zegar, jeden RNG.** Walka nie ma osobnego świata: `Jednostka` dostaje opcjonalne
  `BojJednostki` (parametry walki, HP, liczniki +0x2A0/+0x2AC, ustawienia AI +0x208, cel walki, ICL) oraz gracza i
  flagę człowieka. Dyplomacja: `Swiat::ustaw_wrogow`. Tablice obrażeń i wagi celu: `ustaw_tablice_walki`.
- **Jedna maszyna stanów i jedna kolejka celów.** Cel ataku to `CelRuchu{TypCelu::jednostka}` w tej samej kolejce
  co cele ruchu; zdarzenia celu (`ZD_CELU`) są fałszem z diagnostyką, gdy czołowy cel nie jest jednostką.
  `Swiat::zdarzenie()` deleguje do `zdarzenie_walki` tylko dla jednostek z `boj`.
- **Bez drugiej nawigacji ani fizyki.** Wejście 8000 dla celu „jednostka” liczy punkt podejścia
  (`punkt_podejscia`: przechwycenie 0x62C963 z BO-10 albo 8 slotów 0x63234D) i ustawia pole celu; dalej zwykły
  PrepareToMove/A*. FaceEnemyUnit/AttackEnemyUnit używają nowego trybu fizyki `TrybRuchu::do_celu` (EEPMLand
  vt+0x10: obrót do celu, hamowanie v' = max(0, v − dt·a)).
- **Moduł `walka`** (bez stanu): `ocena_celu` (0x6399CA), `w_zasiegu_punktowy` (0x631501), `przeladowanie_aoc`
  (0x5FEA22), `modyfikator_wysokosci` (0x61E500), wzór obrażeń z etapu 30.
- **Takt:** przed fizyką ustawiany jest punkt celu walki; po fizyce `liczniki_walki` (−34 ms, szukanie, trafienie
  przy 1122 ms od wejścia w 2001, śmierć → 6000). AoC: jedno `rng_.losuj()` na każde wejście w 2001 – żadnych
  innych losowań. EE – bez losowań.
- **Założenia [N]** są liczone w `Diagnostyka::zalozenia_walki` z opisem ostatniego (np. kolejność kandydatów =
  lista Core, r = 1 bez cfg wysokości) – wynik testu porównawczego zawsze je pokazuje.
- **Zdarzenia walki** (`zdarzenia_walki()`): takt, jednostka, rodzaj (wybór celu, atak, trafienie, śmierć), cel,
  wartość – do testów i do warstwy prezentacji.
- **Testy:** `core_walka` (wzór, pojedynek z etapu 30 – bez zmian), `core_walka_swiat` (elementy, pojedynek
  syntetyczny ze skrótem zdarzeń, 2 na 1, okna gry 578/580 z danymi lokalnymi).

## 14. Etap 32 – korekty z kodu Titan (obrót, walka)

- `Swiat::ukonczony_obrot` – CompletedUnitFacing 0x614F52 (|Δkurs| ≤ 1° f32, bez warunku v, ω); przy prawdzie
  macierz ustawiana na kurs celu. Funkcja publiczna (test na taktach 9006 z pomiarów).
- `FizykaLadowa::obrot` – przycięcie kroku jak 0x548477 (bez przycięcia przy Δ = 0); `tryb_hamowanie` obraca o ω′·dt
  (0x548920), gdy ω ≠ 0; tryb 5 nie zeruje ω; stan 5001 nie zmienia trybu ruchu.
- `ModyfikatorWysokosci::z_gry(aoc)` – cfg z odczytu gry (2,0 / 1,0 / 1,5 / 0,8), AoC z rodzajem celu 30.
- Test `core_walka_swiat` porównuje także kurs i ω (pola `kurs`, `w` z `pomiar_core walka`) i wypisuje
  PIERWSZY ROZBIEŻNY TAKT okna z rodzajem różnicy. Okno AoC 580 G1 – symulowane na tablicach AoC z gry (588).
- Przypadki S2, S4, S4b, S5 przeliczone (`testy_referencyjne_ruchu.md`); `core_porownanie_gra`: Core nie gorszy
  od modelu v4 względem gry.
