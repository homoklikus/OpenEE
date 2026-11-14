# Precyzja numeryczna ruchu w Titan – UMArcTan2, tablice trygonometryczne, x87 i zapisy f32 (EE / AoC)

Wpis atlasu z etapu 27. Uzupełnia `fizyka_terenu.md` § 6 i `ruch_jednostki.md` § 6–7 o dokładną arytmetykę ruchu
jednostki lądowej. Kompilacje: `Empire Earth.exe` e352d7ae…, `EE-AOC.exe` db8fc5ce… oraz `Low-Level Engine.dll` z tych
samych instalacji.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pełny kod oryginału nie jest tu kopiowany. Opis podaje kroki własnymi słowami, adresy i stałe potrzebne do weryfikacji.

## 1. Wynik w skrócie

- Kurs jednostki nie jest przechowywany jako kąt. Czytany jest z macierzy orientacji przez `UMArcTan2(−m01, m11)`,
  a macierz zapisuje `SetOrientationYPR` z **tablicowych** cos i sin. Kurs jest więc skwantowany przez dwie tablice z
  DLL [P].
- `UMArcTan2` to nie libm `atan2`. Działa przez `UMArcCos` z tablicą 32769 pozycji i ma błąd do 4,9e-4 rad oraz
  martwą strefę poniżej ok. 2,4e-4 rad [P na danych EE 500].
- FPU pracuje w precyzji 53 bitów i zaokrągla do najbliższej (round-to-nearest-even). Operacje ruchu w rejestrach x87
  dają ten sam wynik co `double` (IEEE f64). Zapis do f32 następuje w ściśle określonych miejscach (§ 5) [P].
- Model odtwarzający te reguły (model v4) daje EE 517 bez rozbieżności, a AoC 505 kończy w tym samym takcie co gra.
  Wcześniej (v3) było +15 taktów (§ 7).

## 2. Funkcje z `Low-Level Engine.dll`

Import przez IAT: `UMArcTan2` EE 0xB306A4, AoC 0xB546A0. Adresy w DLL podano dla EE. Kod i tablice w DLL AoC są
identyczne bajt w bajt (porównanie zrzutów tablic), adresy są przesunięte (`UMArcTan2` AoC 0x10080DFF) [P].

### 2.1. `UMArcTan2` (EE DLL 0x1007DEBB)

- **Konwencja:** `float __cdecl UMArcTan2(float a, float b)`, wynik w ST0. Odpowiada `atan2(a, b)`: a to „y”, b to „x” [P].
- **Algorytm** [P]:
  1. b == 0 → wynik +π/2 dla a ≥ 0, −π/2 dla a < 0. Także (0, 0) daje **+π/2**, a nie 0 jak w libm.
  2. r = sqrt(a² + b²) w rejestrze (f64).
  3. c = f32(b / r), czyli zapis do zmiennej f32 na stosie.
  4. wynik = `UMArcCos(c)`; przy a < 0 wynik jest negowany.
- **Ćwiartki:** znak b wybiera gałąź acos (π − acos(−x) dla x < 0), znak a decyduje o negacji [P w teście modelu].
  Osie, zapis (a, b): (0, b > 0) → 0; (0, b < 0) → π, bo acos(−1) = π − acos(1); (a > 0, 0) → +π/2;
  (a < 0, 0) → −π/2.
- **Okolice ±π:** wynik zawsze w [−π, π]. Dla a = −0,0 (ujemne zero) negacja zachodzi tylko przy a < 0, więc −0,0 daje
  +π, a nie −π [W].
- **Martwa strefa:** dla |a/b| poniżej ok. 2,4e-4 wartość c = f32(b/r) zaokrągla się do 1,0f i wynik wynosi dokładnie 0 [P].
- **Błąd względem libm:** do 4,9e-4 rad (przy x tuż poniżej progu 0,9995, § 2.2) [P w porównaniu na siatce].

### 2.2. `UMArcCos` (EE DLL 0x1007DCC4)

- x ≥ 1 → 0; x == 0 → π/2; x < 0 → π − UMArcCos(−x) [P].
- 0 < x < f32(0,9995): tablica 0x100E9134 (32769 pozycji f32), indeks = rint(f32(x · 32768)), zaokrąglenie do
  najbliższej parzystej [P].
- f32(0,9995) ≤ x < 1: szereg arcus tangens z argumentu sqrt(1 − x²)/x ze stałymi f32 (bez tablicy) [P].

### 2.3. `UMCos` / `UMSin` (EE DLL 0x1007DF28)

- tablica 0x100D9130 (16385 pozycji f32 dla [0, π]), indeks = rint(f32(|x| · 5215,18896)) [P];
- sin(x) liczony jako UMCos(π/2 − x) [P].

### 2.4. `SetOrientationYPR` (EE DLL 0x100472D3)

- Buduje macierz obrotu z odchylenia (yaw), pochylenia (pitch) i przechyłu (roll) przez `UMCos`/`UMSin` [P].
- Dla roll = 0 i pitch = 0: m01 = −sin(Y), m11 = cos(Y), m21 = 0, oba z tablicy [P].
- Pomiar: wszystkie 1251 wartości macierzy z przebiegu EE 500 to dokładnie wartości tablicowe (lub ich iloczyny przy
  pochyleniu) [P].

### 2.5. Czy tablice można wygenerować wzorem

Nie dokładnie [P]:
- cos: 15807 z 16385 pozycji = f32(round(cos(i·π/16384), 6)); najlepszy znaleziony wariant – 16259 pozycji;
- acos: 32012 z 32769 pozycji.

Wniosek dla OpenEE: wierna arytmetyka wymaga **tablic z lokalnej instalacji użytkownika** (wczytanie z
`Low-Level Engine.dll` przy starcie, tak jak inne dane oryginalne). Tablic nie wolno dodawać do repozytorium
(`docs/ZASOBY_ORYGINALNE.md`). Wzór przybliżony może być tylko trybem awaryjnym, oznaczonym jako niezgodny.

## 3. Stan FPU

- Start procesu: CRT ustawia `_controlfp(_PC_53, _MCW_PC)` (EE 0x683914) [P/W].
- Każdy wątek symulacji przywraca precyzję 53 bity i zaokrąglanie do najbliższej po każdym `Receive` (obsłudze
  komunikatów). Zmiany słowa sterującego w innych wątkach nie przenoszą się więc na symulację [W].
- Precyzję 24 bity ma tylko wątek grafiki [W].
- **Równoważność z f64** [P]: przy PC_53 każda pojedyncza operacja x87 (+, −, ·, /, sqrt) daje ten sam wynik co IEEE
  double, a pośrednie wartości nie mają dodatkowego wykładnika, bo zakres jest mały. Model w Pythonie (`float` = f64,
  `numpy.float32` w punktach zapisu) odtwarza EE 517 i AoC 525 bitowo.

## 4. Zaokrąglanie do liczb całkowitych

- Indeksy tablic: `fistp` w trybie do najbliższej parzystej (rint) [P].
- Liczba kroków hamowania obrotu w AoC: zaokrąglenie w górę (ceil) [W].

## 5. Tabela operacji ruchu i punktów zapisu (EE 0x548645 / 0x54880E / 0x548266)

„rej.” = wartość zostaje w rejestrze x87 (f64), „f32” = zapis do zmiennej f32 i ponowny odczyt.

| Wielkość | Wzór | Precyzja | Uwagi |
|---|---|---|---|
| d (odległość do punktu) | sqrt(Δx² + Δy²) | obliczenie rej., zapis f32 | porównanie z 0,05 na wartości **z rejestru** [P] |
| kurs bieżący cur | UMArcTan2(−m01, m11) | f32 | z macierzy, nie z pola kąta [P] |
| kurs do celu des | UMArcTan2(f32(−Δx), f32(Δy)) | f32 | [P] |
| diff | des − cur, normalizacja ±2π stałymi f32 (π 0x828020, 2π 0x828018, −π 0x82ACE0) | rej., zapis f32 | [P] |
| n (kroki hamowania obrotu) | f32(c8 · tps · \|ω\|) | f32 | [P] |
| S_rot | (n+1)·n·0,5·α·dt² | rej. | porównanie S_rot < \|diff\| [P] |
| ω′ | ω ± α·dt, obcięcie do ±ωmax lub do zera | rej., zapis f32 | [P] |
| krok kąta | ω′·dt; gdy \|krok\| > \|diff\| i ten sam znak → diff | f32 | [P] |
| yaw | f32(krok + cur) | f32 | potem SetOrientationYPR [P] |
| k (kroki hamowania liniowego) | f32(c4 · tps · v) | f32 | [P] |
| S | (k+1)·k·0,5·dt²·a | rej., zapis f32 | S < 1e-4 → 0 [P] |
| R ≤ S | R = droga do końca trasy (f32 z sum odcinków) | porównanie f32 z f32 | [P] |
| v′ (przyspieszanie) | v + a·dt w rej.; > vmax → vmax; inaczej przy ostatnim punkcie v′ > d → d (BO-7) | rej., zapis f32 | wartość v + a·dt **z rejestru** decyduje o gałęzi „vmax” [P, EE 517] |
| v′ (hamowanie) | v − a·dt; < 0,005 → 0 | rej., zapis f32 | [P] |
| krok drogi | f32(v′·dt) | f32 | [P] |
| pozycja | x = f32(x + f32(krok · m01)), y = f32(y + f32(krok · m11)) | f32 po każdym składniku | m01/m11 z macierzy **nowego** kursu [P] |
| z | GetMeshZ(x, y) | f32 | `fizyka_terenu.md` § 1 |
| nachylenie | asin(Δz/1,3) przez UMArcCos(f32(Δz · −0,769230783)) − f32(π/2) | f32 | punkty P ± 0,65·oś przodu z macierzy [P] |

Reguła stoku, test kroku i kolizje: `fizyka_terenu.md` § 3–4, `kolizje_objazdy.md` § 3, `walidacja_kolizji.md`.

## 6. Różnice EE / AoC w arytmetyce

- **Decyzja obrotu AoC jest inna** (0x554F56) [P]:
  - EE: przyspieszaj, gdy S_rot < |diff|, inaczej hamuj ω do zera;
  - AoC: liczy m = ceil(f32(c8·tps·ω1)) − 1 dla ω1 = α·dt + |ω|, drogę hamowania S = α·(m(m+1)/2 + 1)·dt² i resztę
    rem = |diff| − dt·ω1. Przyspiesza tylko wtedy, gdy rem ≥ 0 i m·dt·ω1 − S < rem;
  - AoC hamuje (0x554738) tak, że |ω| nie spada poniżej α·dt, dopóki diff ma ten sam znak. Jednostka „dojeżdża” kątem
    ze stałą prędkością minimalną zamiast zatrzymać obrót i ruszyć ponownie.
- Pozostałe operacje (prędkość, zapis pozycji, tablice) są takie same [P: AoC 525 bitowo].

## 7. Wpływ na model i pierwszy rozbieżny takt

| Przebieg | v3 (f64 + libm atan2) | v4 (tablice + zapisy f32) |
|---|---|---|
| EE 517 ok. 1,4 pola | 0,0000 / 0,0001, 0 rozbieżnych | 0,0000 / 0,0000, 0 rozbieżnych |
| EE 500 cały przebieg | śr. 0,0106, max 0,0262 | śr. 0,0082, max 0,0497 |
| AoC 505 (obrót AoC) | koniec +15 taktów | koniec w tym samym takcie, śr. 0,0016 |

- **EE 500:** pierwszy rozbieżny takt 48 w obu modelach. Przyczyna: znak drgania ω (±α·dt) przy prawie wyrównanym
  kursie. W kilku taktach v4 wybiera inny znak niż gra. Średnia się poprawia, ale maksimum rośnie. Przyczyny nie
  ustalono [N]. Kandydaci: kolejność odczytu macierzy po pochyleniu (pitch na stoku), punkt trasy wyliczony z serii
  zamiast odczytany z kolejki, wartość d porównywana przed zapisem.
- **AoC 505:** przyczyną +15 taktów była reguła obrotu AoC (§ 6), a nie arytmetyka. Pierwsza rozbieżna gałąź to decyzja
  obrotu w takcie ok. 70 (model z obrotem EE przyspiesza ω, gra hamuje). Po wprowadzeniu wariantu AoC pierwszy
  rozbieżny takt przesuwa się na 224, a koniec ruchu wypada w tym samym takcie [P].

## 8. Wymagania dla implementacji Godot

- GDScript liczy `float` w f64 – to odpowiada x87 przy PC_53 (§ 3). Zapisy f32 trzeba wykonywać jawnie, np. przez
  `PackedFloat32Array` z jednym elementem albo funkcję pomocniczą zaokrąglającą do f32 [W].
  `Vector2`/`Vector3` w standardowej kompilacji Godota to f32 i **nie** nadają się do obliczeń pośrednich.
- Nie wolno używać `atan2`, `cos`, `sin` ani `acos` z Godota w symulacji. Tylko odtworzone `um_arctan2`, `um_cos`
  i `um_arccos` z tablicami z DLL.
- Porównania graniczne (d < 0,05, R ≤ S, v + a·dt > vmax) muszą dostać tę samą wartość co w oryginale: z rejestru albo
  po zapisie f32, zgodnie z tabelą w § 5.
- Testy referencyjne porównują reprezentacje bitowe f32 (`testy_referencyjne_ruchu.md`).

## 9. Niewiadome

- Przyczyna kilku rozbieżnych znaków ω w EE 500 [N].
- Pełna lista wątków i miejsc przywracania słowa sterującego FPU (np. podczas wczytywania zapisu gry) [W/N].
- Adresy `UMArcCos` i `UMCos` w DLL AoC (tablice identyczne) [W].

## 10. Etap 53 – trzy nowe obserwacje

1. **Zegar gry jest skwantowany jak f32** [P; przyczyna H]. EEPhysics +0xD0 rośnie o 34,0909 ms na takt poniżej
   524 288 ms, a o 34,0625 ms (16 × 34 + 1 × 35) w przedziale [524 288; 1 048 576) – nagrania `e52_677_dwa` (obie strony
   granicy), `e52_678`, `e53_705_*`. Kwant 1/16 ms odpowiada dokładności f32 w [2^19, 2^20). Liczniki odejmujące stałe
   34 ms (produkcja) nie zależą od tego. Narzędzia porównują nagrania po numerze taktu (`produkcja.md` § 5.7).
2. **Kurs po wczytaniu scenariusza nie leży na siatce tablic** [P]. Jednostka „pod 45°” ma w pamięci m01 = 0,7070934,
   m11 = −0,7071197 (kąt o 1,9·10⁻⁵ rad za −3π/4). Decyzja prędkości ma próg |diff| ≤ π/4 (0x548645): dla tarana
   (α = 1,745 rad/s²) gra w pierwszym takcie tylko się obraca (v = 0), a Core z macierzą odtworzoną z kąta przez `UMCos`
   – przyspiesza. `Swiat::ustaw_kurs_macierzy` i `odtworz_scenariusz.gd --macierz=1` ustawiają macierz z nagrania;
   wtedy tor tarana zgadza się co takt. Dla gwardii (α = 12,2) obie gałęzie progu dają przyspieszanie, dlatego
   wcześniejsze nagrania tego nie pokazały.
3. **Reguła stoku na granicy progu** [P; przyczyna N]. Taran na pochyłym wierszu oscyluje 0,4318 ↔ 0,4659 (próg
   vmax·(1 − s·0,5)); Core odtwarza oscylację, ale w jednym takcie hamuje, gdy gra przyspiesza (EE t = 55226, AoC
   t = 54715; EE 57749 na innym wierszu), po czym wzór wraca przesunięty o takt, a pozycja różni się o 0,0023 pola.
   v jest wtedy równe progowi co do zaokrąglenia f32. Czułość typu +0x488 tarana nie była odczytana (przyjęto 0,5).

## 11. Etap 54 – model zegara gry w narzędziach porównania

- Zegar gry (EEPhysics +0xD0, f32) rośnie co takt o 1500/44 ms zaokrąglone do kwantu f32 bieżącej wartości:
  **34,09375 ms dla 65 536…524 288 ms** (kwant 1/128…1/32 ms) i 34,0625 ms powyżej 524 288 ms (etap 53) [P: AoC 713 –
  czas utworzenia jednostki 303 189 ms wobec siatki 1500/44: +19,8 ms = 6970 taktów × 0,00284; EE 714, 716 – to samo].
- Skutek: po około 5600 taktach powyżej 65 536 ms surowy czas próbki odbiega od siatki Core o ponad pół taktu i
  dopasowanie „najbliższa próbka w ±16 ms” wybiera sąsiedni takt.
- `odtworzenie_nagrania.py`: `takt_zegara(t)` przelicza czas gry na numer taktu; `porownaj` i `porownaj_zbieranie`
  dopasowują próbki po czasie przeliczonym na siatkę 1500/44. Dla t ≤ 65 536 ms przeliczenie jest tożsamością, więc
  wcześniejsze wyniki się nie zmieniają (regresja etapu 54). `porownaj_produkcje` liczy takty różnicami czasu
  (etap 53); czas utworzenia i przebieg nowych jednostek – po numerze taktu.
- Symulacja Core nie zależy od zegara gry (takt = 1500/44 ms); zmiana dotyczy tylko narzędzi.

