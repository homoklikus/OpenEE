# OpenEE – raport etapu 28: natywny rdzeń C++ (OpenEE Core), GDExtension i pierwsza implementacja fizyki Titan

Etap 28 rozpoczyna migrację deterministycznej symulacji OpenEE do natywnego rdzenia w C++20, połączonego z Godotem
przez GDExtension. Zaimplementowano pierwsze potwierdzone podsystemy Titan z atlasu (etapy 14–27):
- matematykę z tablicami oryginalnej DLL;
- generator losowy;
- teren;
- fizykę jednostki lądowej w wariantach EE i AoC;
- podstawową maszynę stanów;
- wzór odpychania.

Rdzeń przechodzi testy referencyjne etapu 27 **bitowo** w buildach Debug i Release oraz przez Godota.
Istniejący kod GDScript nie został zastąpiony – nowy rdzeń działa równolegle.

Szczegóły:
- **`docs/cpp/ARCHITEKTURA_CORE.md`** – moduły, niezależność od Godota, jednostka, warianty, granice odpowiedzialności;
- **`docs/cpp/BUDOWANIE.md`** – zależności, CMake, Debug/Release, flagi, testy, rozwiązywanie problemów;
- **`docs/cpp/INTEGRACJA_GODOT.md`** – API GDExtension, przepływ danych, cykl życia, zasady rozbudowy.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `6a770c2`, testy Godota 324/324.

## 1. Podsumowanie migracji architektury

| Warstwa | Odpowiedzialność | Gdzie |
|---|---|---|
| **OpenEE Core (C++20)** | deterministyczna symulacja: matematyka i fizyka Titan, jednostki, takt, maszyna stanów, generator; docelowo A*, kolizje, AI, ekonomia, lockstep, serializacja | `cpp/core/` |
| **GDExtension** | konwersja danych, takt na żądanie, migawki stanu, diagnostyka | `cpp/gdextension/`, `godot/openee.gdextension` |
| **Godot (GDScript)** | renderowanie, kamera, interfejs, animacje, audio, wejście, narzędzia, wybór danych wejściowych | `godot/` |

- Core kompiluje się i działa bez Godota: testy natywne uruchamiają go bez żadnej biblioteki Godota.
- Klasy symulacji nie używają typów Godota. Zależność od godot-cpp jest tylko w `cpp/gdextension/`.
- Wzór architektoniczny: OpenMW. Kod nie jest kopiowany ani z OpenMW, ani z Titan.

## 2. Struktura natywnego projektu

```text
CMakeLists.txt                         cele: openee_core, openee_tests, openee_gdextension
cpp/cmake/OpenEEFlagi.cmake            flagi zmiennoprzecinkowe
cpp/core/include/openee/*.hpp          12 nagłówków: f32, tablice_dll, matematyka, generator, teren, wariant,
                                       jednostka, fizyka, maszyna_stanow, kolizje, symulacja, interfejsy
cpp/core/src/*.cpp                     8 plików implementacji
cpp/tests/                             testy CTest (9 grup), json_mini, dane/trygonometria_referencja.json
cpp/gdextension/                       OpenEESymulacja, rejestracja, profil klas godot-cpp
cpp/thirdparty/godot-cpp               submoduł (tag 10.0.0-stable, 507ed9d)
godot/openee.gdextension, godot/bin/   opis rozszerzenia; biblioteki budowane lokalnie (ignorowane)
godot/silnik/symulacja/core_cpp.gd     pomocnik GDScript (dane wejściowe, wyszukiwanie DLL)
godot/sceny/diag_core.tscn/.gd         scena diagnostyczna
godot/testy/testy_gdextension.gd       testy integracji (osobno od 324 testów)
```

Razem ok. 2500 wierszy C++ (Core, testy, integracja).

## 3. Standard C++

- C++20 bez rozszerzeń GNU (`CMAKE_CXX_EXTENSIONS OFF`), CMake ≥ 3.22, tylko biblioteka standardowa.
- Typy budowania: Debug i Release. Testy przez CTest.
- Brak Dockera i usług zewnętrznych. Sieć jest potrzebna tylko raz – do pobrania submodułu.
- Flagi: `-ffp-contract=off -fno-fast-math -fno-associative-math -fno-reciprocal-math`; `-fexcess-precision=standard`,
  gdy kompilator ją obsługuje.
- `f32.hpp` przerywa kompilację przy `-ffast-math` i przy `FLT_EVAL_METHOD != 0`.

## 4. Wersja Godota i godot-cpp

| Element | Wersja | Skąd ustalona |
|---|---|---|
| Godot | **4.7.2-stable (official)** | binarka używana w testach (`Godot_v4.7.2-stable_linux.x86_64`), `config/features` projektu „4.7”, dziennik startu |
| godot-cpp | **10.0.0-stable**, commit `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` | `git ls-remote` repozytorium godot-cpp; od wersji 10 wersjonowanie niezależne od Godota |
| API GDExtension | **4.7** (`GODOTCPP_API_VERSION`, `extension_api-4-7.json` z godot-cpp) | godot-cpp 10 obsługuje API 4.3–4.7 |
| `compatibility_minimum` | 4.7 | `godot/openee.gdextension` |

- Zależność przypięta jako submoduł z konkretnym commitem, nie gałąź `master`.
- Profil klas godot-cpp (`profil_godot_cpp.json`, 10 klas) skraca budowanie do ok. 3 minut na 2 rdzeniach.

## 5. Zaimplementowane moduły

| Moduł | Stan | Uwagi |
|---|---|---|
| arytmetyka `f32()`, `rint_parzyste` | wdrożony | bariera `asm` w `f32()` (§ 13) |
| tablice z DLL (PE jako dane) | wdrożony | 2 zweryfikowane warianty, tryb przybliżony tylko diagnostyczny |
| `MatematykaTitan`: UMCos, UMSin, UMArcCos (tablica + szereg), UMArcTan2, SetOrientationYPR, kurs z macierzy, kąt do celu, normalizacja | wdrożony | 81 przypadków bitowych |
| `GeneratorTitan` (LCG, licznik, odległość stanów) | wdrożony | jeden na świat |
| `TerenSiatka`: GetMeshZ, nachylenie, teren syntetyczny | wdrożony | import mapy – nie |
| `Jednostka`, `ParametryRuchu` | wdrożony | macierz 3×3 jako orientacja, kurs zawsze z macierzy |
| `FizykaLadowa`: tryby 0/3/4/5 | wdrożony | wszystkie 16 elementów z § 11 zadania: kierunek, kurs z macierzy, błąd kursu, przyspieszanie i hamowanie obrotu, macierz, przyspieszanie i hamowanie liniowe, reguła 45°, stok, dyskretna droga hamowania, BO-7, przesunięcie, z, osiągnięcie punktu, obrót końcowy |
| `WariantTitan` | wdrożony | obrót EE / AoC, kolejność kontaktów (przygotowana) |
| maszyna stanów | częściowy | parser podzbioru `.tai` + skrypt `land`; zdarzenia walki → fałsz + licznik |
| odpychanie 0x549179 | wzór | 5 przypadków bitowo; lista kontaktów – nie |
| interfejsy `INawigacja`, `IKolejkaCelow`, `IGrupy`, `IKolizje`, `podsystemy()` | interfejsy | jawny status „niewdrożony” |
| `Swiat` (takt) | wdrożony | kolejność od końca listy, 2 losowania na takt, BO-8 |

**Maszyna stanów.**
- Cykl Idle → PrepareToMove → LookForEnemies → Advance → GetNextMoveWaypoint → LookForEnemies → Advance … →
  TurnToUnitFacing → ReacquireGoal → Idle.
- Zachowane:
  - najwyżej jedno przejście na takt, kolejność przejść, leniwa ocena AND/OR;
  - akcje wejścia;
  - cykl trzech taktów przy zmianie punktu (10003 → 9000 → 2015 → 10003);
  - losowanie w ObstacleDetected;
  - BO-8 (termin +0x254, porównanie bez znaku).
- Parser sparsował lokalnie oryginalny `land.tai` z dołączeniami (34 stany). Przejścia stanów ruchu 8000, 2015, 10003,
  9000, 9006 i 5001 są identyczne ze skryptem wbudowanym [P].
- Zdarzenia z parametrami nie są obsługiwane – parser zgłasza błąd zamiast udawać obsługę.

## 6. Obsługa oryginalnych DLL

- Loader (`tablice_dll.cpp`) czyta `Low-Level Engine.dll` jako dane. Nie używa `dlopen` ani nie wykonuje kodu.
- Kolejne kroki:
  1. MZ/PE, i386/PE32, tablica sekcji i zakresy;
  2. SHA-256 pliku (własna implementacja, wektory FIPS w testach);
  3. zgodność `TimeDateStamp` i bazy obrazu z deskryptorem;
  4. VA → RVA → offset przez sekcje, cała tablica w danych surowych jednej sekcji;
  5. FNV-1a tablicy;
  6. kontrola wartości: krańce, monotoniczność, odchyłka od cos/acos < 2e-6.
- Wspierane cztery pliki (sumy w `docs/cpp/ARCHITEKTURA_CORE.md` § 10). Tablice są bajtowo identyczne:
  - EE i AoC z instalacji GOG + NeoEE;
  - EE i AoC z czystej instalacji GOG (referencyjnej).
- Dwa ostatnie dodano, gdy test Godota wybrał z konfiguracji instalację referencyjną, a loader odrzucił ją jako
  „nieznaną wersję”. Sumy pliku są inne, a rozmiar, znacznik czasu i adresy tablic – te same, co sprawdzono
  wyszukaniem bajtów tablic.
- Nieznana wersja kończy się czytelnym błędem z sumą pliku. Brak pliku też daje czytelny błąd.
- Bez DLL testy wymagające tablic mają status **SKIP**.
- Tryb przybliżony (wzór, 578 pozycji cos różnych od oryginału) jest oznaczony `zgodne_z_oryginalem = false` i daje
  ostrzeżenie w Godocie.
- Do repozytorium nie trafiają DLL ani tablice. Plik `cpp/tests/dane/trygonometria_referencja.json` zawiera wyniki
  funkcji dla 81 wybranych argumentów (wzorce bitowe). Kilkadziesiąt z nich to pojedyncze wartości tablicowe,
  a nie eksport tablic.

## 7. Testy matematyki Titan

`core_trygonometria`: **PASS**.
- 81 przypadków porównanych bitowo z modelem referencyjnym etapu 27:
  - UMArcTan2: 28 przypadków – ćwiartki, osie, (0,0), −0, okolice 0 i ±π, wartości bardzo małe; wynik f64 i f32;
  - UMArcCos: 17 przypadków, w tym gałąź szeregu i |x| ≥ 1;
  - UMCos i UMSin: po 14 przypadków, w tym zawijanie;
  - SetOrientationYPR: 8 macierzy po 9 elementów.
- Własności:
  - (0,0) → +π/2, (0,−1) → π, (−1,0) → −π/2;
  - martwa strefa (2e-4 → 0);
  - max |UMArcTan2 − atan2| = 4,543e-4 rad na siatce 62 801 kątów (etap 27: do 4,9e-4).

`core_teren`: **PASS**.
- GetMeshZ: płasko, wierzchołek, płaskowyż, rampa, oba trójkąty pola.
- Nachylenie rampy 0,15/pole: 0,150562406 rad. Symetria pod górę / w dół.

## 8. Testy RNG

`core_rng`: **PASS**.
- 100 000 kroków LCG zgodnych z niezależnym obliczeniem 64-bitowym; licznik losowań.
- `losuj()` = stan/2³¹; przepełnienie 32-bitowe.
- Odtwarzalność przy tym samym ziarnie; odległość 342 kroków (pomiar etapu 27).

`core_determinizm`: **PASS**.
- Te same skróty przebiegów przy powtórzeniu i w odwrotnej kolejności przypadków.
- 5 jednostek w jednym świecie, 300 taktów: wszystkie w Idle, 1835 losowań.

## 9. Testy fizyki EE

- Przypadki S1, S2, S3, S4, S4b, S5, S6, S7 (wariant EE): **wszystkie bitowo zgodne**:
  - x, y, v, ω, kurs jako f32;
  - stan i zdjęte punkty – dokładnie;
  - takt końca ruchu.
- Obejmują przyspieszanie, hamowanie z obrotem końcowym, BO-7, obrót i regułę 45°, obrót w miejscu, trasę z dwoma
  zakrętami i zmianami punktów, podjazd z regułą stoku oraz zjazd.

## 10. Testy fizyki AoC

S5a (Aleksander, decyzja obrotu AoC 0x554F56 / 0x554738): **bitowo zgodny**, koniec w takcie 231. Wariant wybierany
przez `WariantTitan::aoc()`.

## 11. Wyniki S1–S7

| Przypadek | Wynik | Takty porównane | Koniec (oczek.) | Pierwszy rozbieżny takt | Max błąd poz. / v / kurs |
|---|---|---|---|---|---|
| S1 przyspieszanie | PASS | 22 | 255 (255) | – | 0 / 0 / 0 |
| S2 hamowanie do celu | PASS | 56 | 273 (273) | – | 0 / 0 / 0 |
| S3 krótki BO-7 | PASS | 34 | 67 (67) | – | 0 / 0 / 0 |
| S4 obrót i ruch | PASS | 65 | 129 (129) | – | 0 / 0 / 0 |
| S4b obrót w miejscu | PASS | 22 | 22 (22) | – | 0 / 0 / 0 |
| S5 trasa EE | PASS | 136 | 270 (270) | – | 0 / 0 / 0 |
| S5a trasa AoC | PASS | 116 | 231 (231) | – | 0 / 0 / 0 |
| S6 podjazd | PASS | 247 | 737 (737) | – | 0 / 0 / 0 |
| S7 zjazd | PASS | 200 | 597 (597) | – | 0 / 0 / 0 |

- Tolerancje nie były potrzebne ani użyte.
- Skrót zbiorczy wszystkich przebiegów: `c36721320b3595e4`.
- **Zastrzeżenie:** wartości oczekiwane to wyniki modelu v4 (Python), a nie pomiary gry. Zgodność bitowa dowodzi
  wiernego przeniesienia modelu do C++. Zgodność modelu z grą opisuje `docs/titan/testy_referencyjne_ruchu.md` § 5
  (EE 517 bitowo, EE 500 max 0,05 pola, AoC 505 koniec +0).

**Uwaga do danych etapu 27.**
- Generator zestawu syntetycznego liczył nachylenie przez `teren_model.um_arccos` bez wczytanej tablicy, czyli przez
  `acos` z wzoru.
- Po wczytaniu tablicy wszystkie przypadki dają identyczne wartości w taktach zapisanych w zestawie. Plik nie wymaga
  zmiany.
- C++ używa tablicy, zgodnie z oryginałem.

## 12. Odpychanie

`core_odpychanie`: **PASS** – 5 przypadków 0x549179 bitowo:

| Przypadek | Wynik |
|---|---|
| 1 | push o = (0,02860546057113178; 0,0025393204670333125) – pomiar EE 535: (0,0286; 0,0025) |
| 2 | (0,14777787143361643; 0,0024690616689913014) |
| 3 | (0,08307692857889037; 0,03692307618948121) |
| 4 | budzik (0,001; 0,001) i odbicie u = (−0,18330421153898868; −0,0814685314476904) |
| 5 | brak kolizji |

Wzór nie jest jeszcze włączony do taktu (brak listy kontaktów).

## 13. Debug / Release

| Kompilator | Build | Skrót S1–S7 | Wynik |
|---|---|---|---|
| GCC 13.3 (Ubuntu 24.04) | Debug | `c36721320b3595e4` | 9/9 |
| GCC 13.3 | Release `-O3` | `c36721320b3595e4` | 9/9 |
| GCC 13.3 | Release `-O3 -march=haswell` | `c36721320b3595e4` | 9/9 |
| GCC 11.4 (Ubuntu 22.04, maszyna z Godotem) | Debug | `c36721320b3595e4` | 9/9 |
| GCC 11.4 | Release `-O3` – **przed poprawką** | `fa65d66efe5e88de` | **8/9 przypadków ruchu FAIL** |
| GCC 11.4 | Release `-O3` – po poprawce | `c36721320b3595e4` | 9/9 |

**Przyczyna różnicy w GCC 11.4.**
- Wektoryzacja SLP w `fizyka.cpp` (para zapisów pozycji) dawała y większe o 1 ulp w takcie 9 przypadku S1.
  Rozbieżność narastała do 1,4e-4 pola (S6).
- Bisekcja: `-O2` poprawnie; `-O3 -fno-tree-slp-vectorize` poprawnie; `-O3` tylko dla `fizyka.cpp` – błędnie.
- **Poprawka:** pusta bariera `asm volatile` w `f32()`. Nie dodaje instrukcji, ale zabrania optymalizatorowi łączenia
  konwersji.
- Test referencyjny wykrył problem od razu. Tolerancji nie dodano.

**Próba kontrolna FMA.** `-ffp-contract=fast -march=haswell` (16 instrukcji `vfmadd`) nie zmieniła wyników obecnych
przypadków. Flaga `-ffp-contract=off` zostaje jako zabezpieczenie.

## 14. Wyniki testów GDExtension

Godot 4.7.2, `--headless --script res://testy/testy_gdextension.gd`: **17 zaliczonych, 0 niezaliczonych,
0 pominiętych**.
- klasa `OpenEESymulacja` zarejestrowana – biblioteka załadowana przez Godot;
- brak DLL: czytelny błąd, świat się nie tworzy;
- tryb przybliżony oznaczony jako niezgodny;
- wczytanie tablic z DLL użytkownika (EE) – ścieżka znaleziona przez konfigurację OpenEE, bez zmiennych środowiskowych;
- S1–S7 i S5a **przez GDExtension, bitowo**, z tymi samymi taktami końca;
- `takt(100)` daje to samo co 100 × `takt(1)`;
- diagnostyka: tablice zgodne, RNG liczy losowania, zdarzenia nieobsługiwane zliczane.

Scena diagnostyczna (`./uruchom_openee.sh core`, tryb `--auto=300 --gra=aoc --przypadek=6`):
- DLL AoC znaleziona przez konfigurację OpenEE (bez zmiennych środowiskowych);
- S5a po 300 taktach: x = 12,689332, y = 14,252556, kurs −0,220169, stan 5000 (Idle);
- wartości zgodne z referencją.

Przepływ: GDScript → GDExtension → Core C++ → GDExtension → Godot. W GDScript nie ma obliczeń ruchu.

**Bez zbudowanej biblioteki** (sprawdzone przez zmianę nazwy pliku):
- Godot wypisuje błąd ładowania rozszerzenia;
- test integracji zgłasza **FAIL** (nie SKIP);
- 324 dotychczasowe testy przechodzą.

## 15. Regresja starego Godota

| Test | Wynik |
|---|---|
| `uruchom_testy.gd` z biblioteką | **324/324** |
| `uruchom_testy.gd` bez biblioteki | **324/324** |
| CTest Release (GCC 11.4, z DLL) | 9/9 zaliczonych |
| CTest Debug (GCC 11.4, z DLL) | 9/9 zaliczonych |
| CTest bez DLL (GCC 13.3) | 4 zaliczone, 5 **pominiętych** (trygonometria, teren, ruch, dll, determinizm), 0 niezaliczonych – CTest liczy SKIP osobno |
| `git diff --check` | czysto |

Moduły `jednostka_sym.gd`, `sciezki.gd`, `polityka_ruchu.gd`, `formacja_ee.gd` i `symulacja.gd` nie były zmieniane.
`godot/project.godot` nie był zmieniany.

## 16. Niezaimplementowane mechanizmy

| Mechanizm | Stan w Core |
|---|---|
| test pojedynczego kroku (ślizg, komórka ze środkiem jednostki, +0x20C) | niewdrożony – brak pól nieprzejezdnych |
| lista kontaktów, zastosowanie push (0x549A08), reguła (a), kolejność EE/AoC | niewdrożone (wzór 0x549179 jest) |
| RepathAroundObstacle (9002) | niewdrożony; wejście zliczane w diagnostyce, trasa nie jest przygotowywana |
| A* po polach, graf podsektorów | niewdrożone; trasa z zewnątrz (`nadaj_trase`) |
| kolejka celów, Shift, punkty +0x32 | niewdrożone; jeden cel bieżący |
| grupy, parametry szyku | niewdrożone |
| losowania przy wejściu w Idle | niewdrożone [N] – warunek nieustalony |
| zdarzenia walki, transportu, murów, ICL | zwracają fałsz i są liczone |
| duże jednostki (rozmiar ≥ 1) | niewdrożone [H] |
| import terenu scenariusza | niewdrożony – teren syntetyczny |
| serializacja, lockstep, AI, ekonomia | poza zakresem etapu |

## 17. Problemy i ograniczenia

1. **Wartości referencyjne pochodzą z modelu.** Zgodność z grą jest taka, jak modelu v4. EE 500 ma niewyjaśnione
   rozbieżności znaku drgania ω [N].
2. **Założenia modelu przeniesione do C++:**
   - UnitFacingNotRequired / CompletedUnitFacing wymagają v = 0 i ω = 0 [W];
   - próg kursu końcowego 0,0175 rad [W];
   - ReacquireGoal przełącza na tryb 3 [H];
   - tps = 1/dt w rejestrze zamiast f32 EEPhysics+0x88 [N];
   - parametry zestawu syntetycznego to liczby dziesiętne, a nie f32 z bazy.
3. **Miejsca 2 losowań na takt** znamy tylko z adresów, ich cel jest nieustalony [W]. Kolejność względem pętli
   jednostek nie jest zweryfikowana.
4. **GCC 11 `-O3`** zmieniał wynik do czasu dodania bariery (§ 13). Inne kompilatory (Clang, MSVC) nie były sprawdzane.
5. **Debian 13 nie był dostępny bezpośrednio.** Budowano na Ubuntu 22.04 (GCC 11.4, glibc 2.35 – maszyna z Godotem)
   i Ubuntu 24.04 (GCC 13.3). Biblioteka zależy tylko od libc/libm (libstdc++ statycznie), więc powinna działać na
   Debianie 13 (glibc 2.41) [W].
6. **Godot rejestruje rozszerzenie dopiero po `--import`.** Bez biblioteki wypisuje błąd ładowania przy każdym starcie –
   stare sceny działają.
7. **Parser `.tai`** obsługuje tylko podzbiór składni.
8. **Submoduł godot-cpp** trzeba pobrać przed budowaniem GDExtension (`git submodule update --init`).

## 18. Rekomendacja etapu 29

Etapu 29 nie rozpoczęto. Proponowany zakres:
1. **Kolizje w takcie:**
   - lista kontaktów przy zmianie komórki (kolejność EE/AoC z `WariantTitan`);
   - 0x549179 z regułą (a), zastosowanie 0x549A08, licznik +0x248;
   - przypadki z pomiarów EE 535/536 jako testy (lokalnie).
2. **Test pojedynczego kroku** i pola nieprzejezdne w `TerenSiatka`: import siatki i przejezdności ze scenariusza
   (czytnik SCN istnieje w GDScript – przenieść do Core albo przekazać dane przez GDExtension).
3. **A* po polach** (etap 24) w Core z testami z `astar_wyniki.md`. Kolejka celów i Shift (etap 21).
4. **Narzędzie porównania z pomiarami gry:** wczytanie lokalnych serii (EE 500/517, AoC 505/525) i metryki jak w
   etapie 27, aby mierzyć zgodność Core z grą, a nie tylko z modelem.
5. Rozważenie `template_release` i eksportu oraz sprawdzenie Clang. Pozostałe zdarzenia stanów – w miarę potrzeb.

## Zmiany w repozytorium

- **Nowe pliki:**
  - `CMakeLists.txt`, `.gitmodules`, `cpp/` (Core, testy, GDExtension, flagi);
  - submoduł `cpp/thirdparty/godot-cpp` (tylko odnośnik do commitu);
  - `godot/openee.gdextension`, `godot/bin/README.md`;
  - `godot/silnik/symulacja/core_cpp.gd`, `godot/sceny/diag_core.gd/.tscn`, `godot/testy/testy_gdextension.gd`
    (z plikami `.uid`);
  - `docs/cpp/ARCHITEKTURA_CORE.md`, `BUDOWANIE.md`, `INTEGRACJA_GODOT.md`.
- **Zmienione:**
  - `.gitignore` (artefakty C++);
  - `AUTORZY.md` (godot-cpp, MIT);
  - `uruchom_openee.sh` (tryb `core`);
  - `docs/titan/specyfikacja_ruchu_godot.md` (adnotacja etapu 28, § 8).
- `RAPORT_ETAP_27.md` przeniesiony do `raporty/archiwum/`. Zaktualizowane:
  - `raporty/README.md`, `README.md`;
  - `docs/HISTORIA.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/titan/README.md`;
  - `dane/launcher/aktualnosci.json`.
- **Bez zmian:** `godot/project.godot` (lokalna zmiana użytkownika nie trafiła do commitu), dotychczasowe moduły
  GDScript, Riverlands_MCP, instalacje gry.

## Commit

Jeden commit lokalny. Bez `git push`.
