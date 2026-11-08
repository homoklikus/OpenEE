# Budowanie OpenEE Core i GDExtension

Instrukcja dla Debiana 13 (i podobnych systemów Linux x86-64).

**Gracz nie musi nic budować** w przyszłych wydaniach binarnych. Ta instrukcja dotyczy wersji rozwojowej.

Do repozytorium nie trafiają:
- biblioteki i katalogi build;
- pliki DLL gry;
- tablice wyeksportowane z DLL.

## 1. Zależności

| Narzędzie | Wersja sprawdzona | Uwagi |
|---|---|---|
| kompilator C++20 | GCC 11.4 (Ubuntu 22.04), GCC 13.3 (Ubuntu 24.04) | Debian 13: `apt install g++ cmake git python3` |
| CMake | 3.22+ (sprawdzone 3.28 i 4.4) | |
| Python 3 | 3.10+ | generator wiązań godot-cpp (tylko GDExtension) |
| godot-cpp | **10.0.0-stable** (`507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`) | submoduł `cpp/thirdparty/godot-cpp`, API 4.7 |
| Godot | **4.7.2-stable** | `config/features` projektu: 4.7 |

Od wersji 10 godot-cpp jest wersjonowany niezależnie od Godota. Docelowe API wybiera się parametrem
(`GODOTCPP_API_VERSION=4.7`). Biblioteka zbudowana dla 4.7 działa w 4.7.x i nowszych, ale nie w starszych.
`openee.gdextension` ma `compatibility_minimum = "4.7"`.

Nie potrzeba Dockera ani usług sieciowych.

Sieć jest potrzebna tylko raz, do pobrania submodułu. Zwykłe uruchamianie gry niczego nie pobiera.

## 2. Pobranie godot-cpp

```bash
git submodule update --init cpp/thirdparty/godot-cpp     # przypięty commit 507ed9d (tag 10.0.0-stable)
```
Bez submodułu można wskazać inną kopię tej samej wersji: `-DOPENEE_GODOT_CPP_DIR=/ścieżka/godot-cpp`.

## 3. Budowanie

```bash
# Release (domyślnie) – Core, testy i GDExtension
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DOPENEE_INSTALACJA="/ścieżka/Empire Earth Gold Edition"
cmake --build build -j
ctest --test-dir build --output-on-failure

# Debug
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug -DOPENEE_INSTALACJA="…"
cmake --build build-debug -j && ctest --test-dir build-debug

# tylko Core i testy (bez godot-cpp)
cmake -S . -B build-core -DOPENEE_GDEXTENSION=OFF && cmake --build build-core -j
```

Opcje CMake:

| Opcja | Domyślnie | Znaczenie |
|---|---|---|
| `OPENEE_TESTY` | ON | buduj `openee_tests` i rejestruj testy CTest |
| `OPENEE_GDEXTENSION` | ON | buduj `openee_gdextension` (wymaga godot-cpp) |
| `OPENEE_INSTALACJA` | (puste) | katalog z „Empire Earth” i „Empire Earth - The Art of Conquest”; tylko dla testów z DLL |
| `OPENEE_GODOT_CPP_DIR` | `cpp/thirdparty/godot-cpp` | źródła godot-cpp |
| `GODOTCPP_TARGET` | `template_debug` | `template_debug` (edytor i uruchamianie projektu) albo `template_release` (eksport) |

Wynik GDExtension: `godot/bin/libopenee.linux.template_debug.x86_64.so`.
- libstdc++ i libgcc są linkowane statycznie: biblioteka zależy tylko od libc/libm.
- Godot rejestruje rozszerzenie po skanowaniu projektu. Po pierwszym zbudowaniu wykonaj
  `godot --headless --path godot --import`. Robi to też `./uruchom_openee.sh`, gdy zmieniły się skrypty.

## 4. Flagi i zgodność Debug/Release

- `cpp/cmake/OpenEEFlagi.cmake`:
  - `-std=c++20` (bez rozszerzeń GNU), `-ffp-contract=off`;
  - `-fno-fast-math`, `-fno-associative-math`, `-fno-reciprocal-math`;
  - `-fexcess-precision=standard`, gdy kompilator ją ma (GCC ≥ 13 dla C++).
- Na x86-64 arytmetyka idzie przez SSE2. `FLT_EVAL_METHOD == 0` jest sprawdzane w `f32.hpp`.
- 32-bitowe x86 bez SSE2 nie jest wspierane.

**Wynik etapu 28.**
- Skrót wszystkich przebiegów S1–S7 (`c36721320b3595e4`) jest identyczny dla:
  - GCC 13.3: Debug, Release `-O3`, Release `-O3 -march=haswell`;
  - GCC 11.4: Debug, Release `-O3` – dopiero po dodaniu bariery w `f32()`.
- **Problem znaleziony w GCC 11.4 `-O3`.** Wektoryzacja SLP w `fizyka.cpp` (para zapisów
  `x = f32(x + f32(krok·m01))`, `y = …`) dawała y większe o 1 ulp w takcie 9 przypadku S1. Rozbieżność rosła do 1,4e-4
  pola (S6).
  - Bisekcja: `-O2` poprawnie, `-O3 -fno-tree-slp-vectorize` poprawnie, `-O3` tylko dla `fizyka.cpp` – błędnie.
  - Poprawka: pusty `asm volatile` z ograniczeniem rejestru w `f32()`. Nie generuje instrukcji, ale zabrania łączenia
    konwersji.
  - Test `core_ruch` wykrywa taki problem od razu, dlatego **trzeba go uruchamiać po każdej zmianie kompilatora lub
    flag**.
- **Próba kontrolna:** `-std=gnu++20 -march=haswell -ffp-contract=fast` wygenerowało 16 instrukcji `vfmadd`, a testy
  S1–S7 i trygonometrii nadal przechodziły.
  - Obecne przypadki nie są więc czułe na każdą fuzję FMA.
  - Flaga `-ffp-contract=off` zostaje jako zabezpieczenie. Zgodność wynika z zasad, a nie tylko z testu.

## 5. Testy natywne

`ctest` uruchamia grupy `openee_tests <grupa>`:

| Test | Zakres | Bez DLL |
|---|---|---|
| `core_trygonometria` | 81 przypadków bitowych (UMArcTan2, UMArcCos, UMCos, UMSin, SetOrientationYPR), osie, martwa strefa, max błąd, tryb przybliżony | SKIP |
| `core_rng` | sekwencja LCG (100 000 kroków), ziarno, stan/2³¹, przepełnienie, odległość stanów | działa |
| `core_teren` | GetMeshZ (płasko, rampa, oba trójkąty), nachylenie | częściowo, wynik SKIP |
| `core_ruch` | S1–S7 bitowo f32, koniec ruchu, pierwszy rozbieżny takt, błędy diagnostyczne | SKIP |
| `core_odpychanie` | 5 przypadków 0x549179 bitowo | działa |
| `core_dll` | brak pliku, plik nie-PE, PE x86-64, SHA-256 (wektory FIPS), wczytanie EE i AoC | SKIP części z DLL |
| `core_tai` | parser (include, remove, zastępowanie, błąd parametrów), opcjonalnie oryginalny `land.tai` (`OPENEE_TAI`) | działa |
| `core_determinizm` | powtarzalność, niezależność od kolejności uruchomienia, 5 jednostek w jednym świecie | SKIP |
| `core_astar` | 18 przypadków A* bitowo z modelem e24: trasa, kolejność rozwijania, iteracje, wywołania | działa |
| `core_astar_gra` | mapa z gry (lokalnie): trasy A, C i liczba iteracji E zgodne z grą | SKIP bez `OPENEE_DANE_LOKALNE` |
| `core_krok` | 9 gałęzi testu kroku (to samo pole, przejezdne, ślizgi, cofnięcie, narożnik, jednostka blokująca, poza mapą, romb) | SKIP |
| `core_kolizje_takt` | ruchoma → stojąca większa, reguła (a), czołowe EE/AoC | SKIP |
| `core_kolejka` | zwykły rozkaz, Shift ×2, kolejność A → B → C, czyszczenie, Shift bez celu | SKIP |
| `core_scenariusze` | prosta trasa, objazd ściany, zakręty, cel nieosiągalny, wspólny cel | SKIP |
| `core_porownanie_gra` | Core kontra pomiary EE/AoC (6 serii jednej jednostki, 2 serie dwóch jednostek), metryki | SKIP bez danych lokalnych |
| `core_podsystemy` | wypis stanu wdrożenia | działa |

- Kod 77 oznacza SKIP. CTest wyświetla go jako „Skipped” i **nie liczy jako zaliczonego**.
- Ścieżki DLL: `OPENEE_INSTALACJA` (CMake albo zmienna środowiskowa), `OPENEE_DLL_EE`, `OPENEE_DLL_AOC`.
- Dane lokalne (etap 29, nie publikowane): `OPENEE_DANE_LOKALNE=…/Testy_MCP/e29`:
  - `astar_mapa_e24_lokalne.json` – dostępność pól mapy z gry;
  - `serie_porownawcze.json` – serie pomiarowe, teren i serie wielojednostkowe z Riverlands_MCP.
- `OPENEE_TAI` – katalog z wypakowanymi `.tai` (porównanie parsera).
- `OPENEE_DEBUG_POROWNANIE=1` – wypis taktów po pierwszej rozbieżności.

## 6. Godot

```bash
G=/ścieżka/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path godot --import                                        # rejestracja rozszerzenia
$G --headless --path godot --script res://testy/testy_gdextension.gd       # testy integracji (17)
$G --headless --path godot --script res://testy/uruchom_testy.gd           # dotychczasowe testy (324)
./uruchom_openee.sh core [--gra=aoc] [--dll=…] [--przypadek=N]            # scena diagnostyczna
```

## 7. Rozwiązywanie problemów

| Objaw | Przyczyna / rozwiązanie |
|---|---|
| `Brak godot-cpp w …` przy konfiguracji | `git submodule update --init cpp/thirdparty/godot-cpp` albo `-DOPENEE_GDEXTENSION=OFF` |
| `-fexcess-precision=standard for C++` (GCC 11/12) | stary plik flag – obecny `OpenEEFlagi.cmake` sprawdza obsługę flagi |
| `Can't open dynamic library … libopenee…so` | biblioteka niezbudowana; stare sceny działają dalej, testy GDExtension zgłaszają FAIL |
| klasa `OpenEESymulacja` nie istnieje po zbudowaniu | brak `godot --import` (plik `.godot/extension_list.cfg`) |
| `Nieznana wersja Low-Level Engine.dll (SHA-256 …)` | DLL inna niż zweryfikowane GOG + NeoEE; trzeba dodać deskryptor po sprawdzeniu adresów tablic |
| testy z DLL mają status SKIP | nie podano `OPENEE_INSTALACJA` / `OPENEE_DLL_*` |
| `core_ruch` FAIL po zmianie kompilatora | sprawdzić flagi (§ 4); nie łagodzić tolerancji |
