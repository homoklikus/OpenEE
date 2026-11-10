# Architektura wyszukiwania tras – Empire Earth / The Art of Conquest

Wpis atlasu Titan, etap 23. Opisuje budowę podsystemu tras: obiekty i ich relacje, wybór maszyny wyszukiwania,
przepływ jednej prośby, budżety i odraczanie obliczeń na kolejne takty. Wejście do podsystemu (kto i kiedy prosi o
trasę, punkty +0x32) opisuje `nawigacja_wejscie.md`. Wnętrze A* po polach, `Bounded` i przekazanie trasy jednostce:
**`astar_pola.md`**, **`astar_wyniki.md`** (etap 24).

Poza zakresem pozostają: pętla A* (poza miejscem, w którym liczy budżet), heurystyka, koszty pól, wygładzanie trasy,
przeszkody dynamiczne, kolizje, ruch fizyczny, nawigacja morska, powietrzna i kosmiczna oraz budowa sektorów.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu (instrukcje przeczytane, bez pomiaru);
- **[H]** hipoteza;
- **[N]** nieustalone;
- **[R]** wyłącznie nazwa klasy z RTTI, bez potwierdzenia w kodzie.

Adresy: EE `Empire Earth.exe` (e352d7ae…), AoC `EE-AOC.exe` (db8fc5ce…).

## 1. Wynik w skrócie

1. **Trzy warstwy danych mapy, nie jedna hierarchia klas** [W: konstruktory i odczyty; P: liczności w pamięci].
   - **Sektory** (`EEAIPathSector`) to stała siatka kwadratów mapy, np. 15 × 15 sektorów po 19 pól na mapie 280 × 280.
   - **Podsektory** (`EEAIPathSubSector`) są węzłami grafu połączeń. Każdy należy do jednego sektora (wskaźnik +0x44)
     i ma własny identyfikator (+0x50) oraz punkt reprezentatywny (+0x3C, +0x40). Na badanej mapie było ich 1858.
   - **Obszary** (`EEAIPathArea`) to osobny podział mapy z własną siatką pól. Na badanej mapie było ich 44.
     Wyszukiwanie dla jednostek nie przechodzi przez obszary. Służą tylko do szybkiego porównania „ten sam obszar?”
     przy liczeniu budżetu.
2. **Wyszukiwanie dwuetapowe** [W: kod; P: pomiar maszyn].
   - Najpierw A* po **grafie podsektorów** (`EEAIAStarGraphMachine`). Wynik to lista punktów reprezentatywnych.
   - Potem A* po **polach mapy** (`EEAIAStarMachine<EEAIAStarStorage, EEAIAStarPathfindingGoal, EEMap>`) do najbliższego
     celu.
   - Etap pośredni zamienia wynik grafu na cele `EEUGLocation` +0x32 w kolejce jednostki. Wyszukiwanie po polach
     prowadzi do pierwszego z nich.
   - Prośba grupowa kończy się na etapie grafu.
3. **Pozostałe maszyny A* z RTTI** nie obsługują próśb jednostek.
   - Maszyny `PathSector`, `PathArea`, `Continent`, `Hill` i `ChokePoint` budują i przebudowują dane mapy w
     `EEAIContinentManager` [W: graf wywołań].
   - Maszyna `Bounded` to szybka próba w prostokącie wokół startu i celu, wykonywana przed pełnym A* po polach [W].
4. **Wybór maszyny** zależy od rodzaju prośby i od środowiska ruchu jednostki [W: kod].
   - Prośba grupowa → maszyna grafu.
   - Prośba jednostki → opcjonalnie maszyna grafu, potem maszyna `Bounded`, potem maszyna pól.
   - Klucz maszyny pól: 1 ląd, 2 morze (EE i AoC). AoC dodaje 0x10 – kosmos.
5. **Budżety są liczone w iteracjach A*.** Jedna iteracja to zdjęcie węzła z listy otwartej i rozwinięcie jego
   sąsiadów [W: pętla; P: liczniki w pamięci]. Każda maszyna ma dwa limity:
   - **limit na wywołanie** (cel +0x20) – po jego osiągnięciu maszyna zawiesza się z zachowanym stanem (+0x1D albo
     +0x24 = 1);
   - **limit całkowity** (cel +0x24) – po jego osiągnięciu wyszukiwanie kończy się bez wyniku.

   −1 oznacza brak limitu.
   - **0xF z etapu 22** to limit całkowity pierwszej próby po świeżym rozkazie (cel +0x34 = 1).
   - **−1 z etapu 22** oznacza „wylicz z odległości euklidesowej startu i celu”.
6. **Odraczanie** [W: kod; P: pomiar].
   - Zawieszona prośba trafia do kolejki menedżera: +0x5C dla pól, +0x70 dla grafu.
   - `EEPhysics` w każdym takcie symulacji woła obsługę kolejek. Na kolejkę przypada łącznie około 32 iteracji na takt.
   - Limit na wywołanie każdej zawieszonej maszyny rośnie o 1 przy każdym ponownym wstawieniu, aż do 32.
   - Zmierzona prośba po polach rozłożyła się na 12 wywołań.

## 2. Diagram zależności

```
 obsługa stanu grupy 8000 ──► EEGroup… 0x5F670A ──┐            „PrepareToMove” 0x6222A8
                                                  │                     │
                                                  ▼                     ▼
                         EEPathManager (globalny EE 0x917D00, AoC 0x92FCB8)
     prośba grupowa 0x4A15E7                         prośba jednostki 0x4A1AFF
          │                                           │ (a) etap grafu, gdy cel świeży
          │                                           │     0x4A164F ──┐
          ▼                                           │                ▼
  0x4A1681 uruchom maszynę grafu ◄────────────────────┘   pula +0x98 (klucz 1)
          │   EEAIAStarGraphMachine<GraphStorage, PathGraphGoal, EEAIPathSubSector>
          │   dane: EEAIContinentManager (globalny EE 0x917BC8)
          │        └─ podsektory (+0x5C/+0x60) ── sektor (+0x44) ── siatka sektorów (+0xDC)
          │
          ├─ skończona ─► 0x4A26E3 ─► EEAutoPathRequest+0x08 (grupa)
          │                       └─► cele EEUGLocation +0x32 (jednostka)
          └─ zawieszona ─► węzeł EEPathManagerNode ─► kolejka +0x70
                                                      │
                     (b) szybka próba Bounded 0x4A24E1 │ maszyna +0xBC (klucz 4, prostokąt)
                     (c) A* po polach                  ▼
                         pula +0x84 (klucz 1/2[/0x10]) EEAIAStarMachine<Storage, PathfindingGoal, EEMap>
                           ├─ skończona ─► 0x4A327E ─► trasa (wektor punktów 12 B) ─► jednostka 0x5EE4E6
                           └─ zawieszona ─► kolejka +0x5C

 EEPhysics vtable +0x20 (takt) ─► 0x4A396B: kolejka +0x70 (0x4A399B) → kolejka +0x5C (0x4A3F1A)
                                            → przebudowa sektorów (0x4A3641 → EEAIContinentManager 0x4278C3)
 zmiana mapy (obiekt postawiony/usunięty) ─► 0x4288A7 ─► EEPathManager 0x4A36F3 („przebuduj za t ms”)
```

## 3. Klasy i obiekty

### 3.1 Obiekty globalne

| Obiekt | EE | AoC | Rola | Pewność |
|---|---|---|---|---|
| `EEPathManager` | 0x917D00 (konstruktor 0x4A09E8, vtable 0x827C44) | 0x92FCB8 (vtable 0x83C438) | prośby, pule maszyn, kolejki odroczeń, takt | [P] |
| `EEAIContinentManager` | 0x917BC8 (konstruktor 0x422B4D, vtable 0x8261FC) | (vtable inny adres) | dane mapy dla tras: obszary, sektory, podsektory, siatki | [P] |
| `EEMap` | wskaźnik w 0x9183BC | – | mapa pól; szerokość w +0x1816FC | [W] |

Oba obiekty globalne mają statyczne konstruktory obok siebie (EE 0x533D53 i 0x533D7D).

### 3.2 `EEPathManager` – pola istotne dla architektury

| Pole | Znaczenie | Pewność |
|---|---|---|
| +0x04 | `UMemoryPool<EEPathManagerNode>` – węzły kolejek (0x4A14B8) | [W] |
| +0x48 (liczba +0x58) | dziennik nieudanych prób: jednostka (+0x08), czas (+0x0C), pole celu. Ponowna prośba tej samej jednostki o to samo pole w ciągu 4 s dostaje mnożnik budżetu 3 (0x4A0CE8). Co 10 s czyszczony (0x4A3A54) | [W]; liczba zmienna w pomiarze [P] |
| +0x5C (liczba +0x6C) | kolejka zawieszonych prośb po polach (węzeł +0x10 = maszyna) | [W]; pusta w pauzie [P] |
| +0x70 (liczba +0x80) | kolejka zawieszonych prośb po grafie (węzeł +0x14 = maszyna) | [W]; pusta w pauzie [P] |
| +0x84 (liczba +0x94) | pula wolnych maszyn pól (0x11C B), klucz w maszynie +0x0C | [P] (2 → 4 maszyny) |
| +0x98 (liczba +0xA8) | pula wolnych maszyn grafu (0xD8 B) | [P] (1 maszyna) |
| +0xBC | jedna maszyna `Bounded` (0x148 B), odtwarzana przy zmianie mapy | [P] (istnieje) |
| +0xC0 / +0xC4 | czasy następnych porządków (+10 s, +30 s) | [W] |
| +0xD0 | licznik identyfikatorów prośb grupowych (rośnie tylko w 0x4A15E7) | [P] (3 → 5 → 6) |
| +0xD4 / +0xD8 | czas i flaga zaplanowanej przebudowy sektorów | [W]; +0xD4 ustawione w pomiarze [P] |

### 3.3 `EEAIContinentManager` – kontenery i siatki

| Pole | Zawartość | Wartość na badanej mapie | Pewność |
|---|---|---|---|
| +0x3C (początek +0x40) | wektor `EEAIPathArea*`; licznik +0x124 | 44 | [P] |
| +0x4C (początek +0x50) | wektor `EEAIPathSector*` (rozmiar = liczba komórek + 1) | 226 = 15 · 15 + 1 | [P] liczba; [W] zawartość |
| +0x5C (początek +0x60) | wektor `EEAIPathSubSector*`, indeks = identyfikator podsektora | 1858, po przebudowie 1859 | [P] |
| +0xDC | `EEAIPathSectorRegionInformation` – siatka sektorów: rozmiar komórki (+0xE0), jego kwadrat (+0xE4), liczba komórek w poziomie i pionie (+0xE8, +0xEC) | 19, 361, 15, 15 | [P] |
| +0xF4 | siatka pól → identyfikator obszaru (u16) | wskaźnik niezerowy | [P] |
| +0xF8 | siatka pól → identyfikator podsektora (u16); gdy pusta, wyszukiwanie zastępcze 0x42609F | **0** (pusta) | [P] |
| +0x128 / +0x12C | wymiary mapy w polach | 280 / 280 | [P] |
| +0x130 | flaga „przebudowa w toku” (blokuje 0x4288A7) | 0 | [W] |

Inne wektory (+0x1C, +0x2C, +0x6C … +0xCC) należą do budowy danych (kontynenty, wzniesienia, przewężenia) i nie są
tu rozpoznane [N].

### 3.4 Struktury mapy

| Klasa | Konstruktor (EE) | Rozmiar | Powiązanie z mapą | Identyfikator | Współrzędne | Pewność |
|---|---|---|---|---|---|---|
| `EEAIPathSector` | 0x42E4C5; tworzenie 0x42434F | 0x4C | jedna komórka siatki +0xDC | +0x48 (u16, kolejny) | +0x40 / +0x44 = komórka (i, j); +0x30 = prostokąt pól | [P] kod |
| `EEAIPathSubSector` (baza `AStarGraphableObjectBase`) | 0x42E757; tworzenie 0x41E990 | 0x60 | sektor nadrzędny +0x44 | +0x50 (u16) = indeks w wektorze +0x5C | +0x3C / +0x40 = punkt reprezentatywny (pole) | [P] kod; punkty w pomiarze etapu 22 |
| `EEAIPathArea` | 0x41C4C4; tworzenie 0x41B49A, 0x4272C8 | 0x88 | siatka +0xF4 | +0x78, +0x7A (u16) | [N] | [W] |
| `EEAIPathSectorRegionInformation` | (część managera +0xDC; wypełnienie 0x42E485) | – | rozmiar komórki = f(rozmiar mapy) | – | – | [P] |

- **Rozmiar komórki** zależy od rozmiaru mapy. Kod 0x424447 wybiera 19 dla mapy do 160 pól, 21 dla mapy do 220 pól,
  a dla większych inną wartość [W].
- **Sąsiedztwo podsektorów:** wektor wskaźników na sąsiadów w +0x2C (początek +0x30, koniec +0x34). Tworzy go
  konstruktor podsektora, a pętla grafu 0x4A5807 przechodzi go od końca [W].
- **Podsektor +0x54** to mała wartość wyliczeniowa (rodzaj, np. 4, 5 w 0x42E814). Służy jako indeks tablicy bajtów w
  maszynie grafu (+0xC0) [W]. Znaczenie rodzajów [N].
- **Dane wodne i lądowe** nie mają osobnych grafów. Środowisko wybiera modyfikator celu (§ 4), a nie inny zbiór
  sektorów [W]. Pełnego rozdzielenia danych morskich nie badano.

### 3.5 Maszyny wyszukiwania

| Klasa (RTTI) | vtable EE | Rozmiar | Tworzona w | Rola | Pewność |
|---|---|---|---|---|---|
| `EEAIAStarGraphMachine<GraphStorage, PathGraphGoal, EEAIPathSubSector>` | 0x827CC4 (storage +0x28, cel +0x64) | 0xD8 | 0x4A43E7 ← 0x4A1351 | A* po grafie podsektorów | [P] |
| `EEAIAStarMachine<Storage, PathfindingGoal, EEMap>` | 0x827C68 (storage +0x20, cel +0x6C, modyfikator celu +0x9C) | 0x11C | 0x4A42D1 ← 0x4A13EE | A* po polach | [P] |
| `EEAIAStarMachine<BoundedStorage, BoundedPathGoal, EEMap>` | 0x827D10 | 0x148 | 0x4A44E0 ← 0x4A0EBC | szybka próba w prostokącie | [W] |
| `…<PathSectorStorage, PathSectorGoal>` | 0x826320 | – | 0x4290A2 ← 0x42434F, 0x4278C3 | budowa i przebudowa podsektorów | [W] |
| `…<PathAreaStorage, PathAreaGoal>` | 0x8262C4 | – | 0x429007 ← 0x423E3F, 0x4240D3 | budowa obszarów | [W] |
| `…<ContinentStorage, ContinentGoal>` | 0x82620C | – | 0x428EA5 ← 0x423452 | budowa kontynentów | [W] |
| `…<HillStorage, HillGoal>` | 0x826268 | – | 0x428F86 ← 0x423C9D | budowa wzniesień | [W] |
| `…<ChokePointStorage, ChokePointGoal>` | 0x826120 | – | 0x420B76 ← 0x420946 | przewężenia (AI) | [W] |
| `EEAIAStarFastStorage`, `EEAIAStarTerrainStorage` | – | – | – | brak konstrukcji w badanych ścieżkach | [R] |

Wszystkie maszyny dziedziczą po `EEAIAStarMachineBase` albo `EEAIAStarGraphMachineBase`. Nie tworzą jednej linii:
każda specjalizacja szablonu ma własny storage i własny cel.

### 3.6 Modyfikatory celu

| Klasa | Gdzie | Rola | Pewność |
|---|---|---|---|
| `EEAIPathGoalModifierSea` (EE 0x827C54, AoC 0x83C458) | maszyna pól z kluczem 2 (0x4A13EE) | ruch morski | [P] kod |
| `EEAIPathGoalModifierSpace` (AoC 0x83C448) | maszyna pól z kluczem 0x10 (AoC 0x4A6724) | ruch kosmiczny, tylko AoC | [P] kod |
| `EEAIGPModifierEnemyAvoidance` (0x825CB0, 0x50 B) | „PrepareToMove”, gdy typ jednostki vtable +0xD0 zwróci prawdę → cel grafu +0x4C (0x41E6E8) | omijanie wroga na etapie grafu | [W] |
| `EEAIGPGModifierComputerPlayerWallPather` | – | AI, mury | [R] |

## 4. Wybór maszyny

| Prośba | Maszyna | Warunek | Pewność |
|---|---|---|---|
| grupowa (0x4A15E7 → 0x4A1681) | graf, klucz 1 | zawsze. Argumenty z 0x5F6795: klucz 1, budżet −1, bez modyfikatora | [W] |
| jednostki, etap grafu (0x4A1AFF → 0x4A164F → 0x4A1681) | graf, klucz 1 | bajt 1C = 1. „PrepareToMove” ustawia go, gdy cel jest celem położenia, nie jest punktem +0x32 i ma +0x1D = 0. Inne cele: +0x1D = 0 | [W] |
| jednostki, szybka próba (0x4A24E1) | `Bounded`, klucz 4 | bajt 14 = 0. Sukces (+0xAD) kończy prośbę bez pełnego A*. W AoC pomijana dodatkowo przy jednostce +0x8C ≥ 7 i nowym argumencie | [W] |
| jednostki, pola (0x4A13EE) | pola, klucz 1 / 2 (EE: typ +0x5D7); AoC 1 / 2 / 0x10 (0x634AD8(1), 0x634AD8(0xC)) | pozostałe przypadki | [P] kod |

**Pule maszyn.**
- Maszyna grafu jest brana z puli tylko wtedy, gdy jej +0x58 równa się liczbie podsektorów + 1 (0x4A1351).
  W przeciwnym razie powstaje nowa. Pomiar: +0x58 = 1859 przy 1858 podsektorach; po przebudowie mapy pula dostała
  nową maszynę z +0x58 = 1860 [P].
- Maszyna pól jest brana z puli, gdy klucz się zgadza (+0x84 w maszynie) [W].

## 5. Przepływ jednej prośby jednostki lądowej

Przypadek: zwykły PPM, jednostka lądowa, cel położenia.

1. **Wejście** [W, `nawigacja_wejscie.md`]. „PrepareToMove” woła 0x4A1AFF z argumentami:

   | Argument | Wartość |
   |---|---|
   | pole jednostki | (+0x1C, +0x20) |
   | pole celu | |
   | bajt 14 | 0 |
   | budżet 18 | 0xF przy +0x34 = 1, inaczej −1 |
   | bajt 1C | etap grafu |
   | obiekt 20 | modyfikator `EnemyAvoidance` albo 0 |
2. **Normalizacja.** Start i cel przechodzą przez 0x4A668A (poprawienie pola na dostępne) [W].
3. **Etap grafu** (gdy bajt 1C = 1), 0x4A1681:
   - pole → podsektor przez `EEAIContinentManager` 0x42C52F (siatka +0xF8 albo wyszukiwanie zastępcze);
   - maszyna dostaje komórkę sektora nadrzędnego (+0x44 → +0x40, +0x44) i identyfikator podsektora (+0x50) dla
     startu (vtable +0x2C) i celu (vtable +0x20) [P: kod; pomiar – komórki (8, 6) i (7, 6) dla celów (170, 131) i
     (150, 115) przy komórce 19 pól];
   - cel grafu dostaje jednostkę (+0x48), gracza (+0x1C), modyfikator (+0x4C) i limit na wywołanie 0xF (+0x20);
   - limit całkowity wylicza 0x4A0CE8;
   - uruchomienie: vtable +0x18.
4. **Wynik grafu** (0x4A26E3):
   - storage oddaje listę identyfikatorów podsektorów;
   - dla jednostki: punkty reprezentatywne podsektorów od pierwszego do przedostatniego bez ostatniego
     (`i < n − 2`) stają się celami `EEUGLocation` (+0x32) na początku kolejki (0x5F05BD). Cel bieżący dostaje
     +0x1D = 1 („etap grafu wykonany”);
   - przy 1–2 podsektorach na trasie punkty nie powstają. Pomiar A i B: graf przeszedł 1 i 2 iteracje, kolejka bez
     punktów [P];
   - etap 39: etap grafu działa także dla celu ataku (PrepareToMove 0x622431: bajt +0x1C = cel+0x1D == 0). Pomiar
     619/620: druga gwardia dostaje EEUGLocation (163,5; 103,5) przed EEUGAttackUnit w takcie pierwszego
     PrepareToMove; drugi PrepareToMove tego celu już bez punktu (+0x1D = 1) [P pomiar; W kod]. Core: graf
     podsektorów niewdrożony – brak tych punktów (`walka.md` § 29);
   - dla grupy: punkty w kolejności od startu trafiają do `EEAutoPathRequest`+0x08, długość +0x48 (suma
     |Δx| + |Δy|), gotowość +0x4C = 1;
   - wartość zwracana: czy ostatni podsektor ma identyfikator celu.
5. **Zawieszenie grafu.** Gdy maszyna ma +0x24 = 1, węzeł (+0x14 maszyna, +0x18 prośba, +0x1C jednostka, +0x08 pole
   celu) trafia do kolejki +0x70, a 0x4A1AFF kończy pracę. Jednostka czeka.
   - Po zakończeniu w takcie 0x4A2A4C wykonuje krok 4.
   - Następnie, gdy na początku kolejki stoi punkt +0x32, sama woła 0x4A1AFF(jednostka, pole jednostki, punkt, 0, −1,
     0, 0), czyli prośbę po polach do pierwszego punktu [W].
6. **Cel pól.** Gdy graf skończył od razu, a na początku kolejki stoi teraz punkt +0x32, polem celu staje się ten
   punkt [W].
7. **Anulowanie poprzednich prośb** (0x4A35AA) oraz szybka próba `Bounded` (0x4A24E1) [W]:
   - prostokąt wokół startu i celu, z marginesem (odległość / 20) + min(liczba zawieszonych prośb, 10) + 4;
   - wykonanie synchroniczne;
   - przy sukcesie jednostka +0x33E = 1 i koniec.
8. **A* po polach.**
   - Maszyna z puli dostaje: limit na wywołanie (vtable +0x30) – 0xF, bo bajt 14 = 0; limit całkowity (vtable +0x24)
     – budżet 18 albo wyliczony w 0x4A0E2F; start (vtable +0x38), cel (vtable +0x2C), jednostkę (cel 0x41D67E) i ruch
     po przekątnej (+0x1C = 1).
     *[Etap 24 – uściślone]* +0x1C to reguła narożników: przekątna wymaga wolnego pola prostego. Przy 0 przekątne
     byłyby bez warunku. Po porażce `Bounded` pełne A* startuje z punktu końcowego `Bounded`. Limit `Bounded` to m
     iteracji w kwadracie start ± (m + 1) (`astar_wyniki.md` § 6).
   - Uruchomienie vtable +0x20.
   - Zawieszona (+0x1D = 1) → kolejka +0x5C.
   - Skończona → 0x4A327E:
     - sukces → trasa jako wektor punktów (3 × float, 12 B) przekazana jednostce (0x5EE4E6);
     - porażka → 0x4A2B29, m.in. dziennik +0x48 [W].

     *[Etap 24 – zastąpione]* Dla maszyny pól flaga +0x96 (cel +0x2A) jest zawsze 0, więc wynik zawsze idzie przez
     0x4A2B29. To wspólne przekazanie z łączeniem z obecną trasą jednostki, a nie obsługa porażki. 0x4A32C0 dotyczy
     tylko `Bounded`, gdy próba nie doszła do celu. Trasa trafia do kolejki jednostki +0x7C (elementy 20 B)
     (`astar_wyniki.md` § 5).

**Gdzie leży stan niedokończonego wyszukiwania.** W samej maszynie: lista otwarta i zamknięta w storage, liczniki
+0x10 / +0x14 / +0x18, flaga +0x1D (pola) albo +0x24 (graf). Węzeł kolejki wskazuje maszynę. Wznowienie to ponowne
wywołanie „uruchom”, które przy ustawionej fladze pomija inicjalizację (0x4A4FE1, 0x4A505E) [W].

**Potwierdzone instrukcjami a rekonstruowane z nazw.** Kroki 1–8 wynikają z przeczytanego kodu. Z RTTI pochodzą tylko
nazwy klas. Interpretacja „sektor = komórka siatki, podsektor = spójny fragment sektora” opiera się na konstruktorach
(0x42434F, 0x41E990) i licznościach w pamięci [W]. Sposobu wydzielania podsektorów nie badano [N].

## 6. Budżety

### 6.1 Iteracja i liczniki maszyny (0x4A5428 pola, 0x4A5807 graf)

| Pole maszyny (pola / graf) | Znaczenie |
|---|---|
| +0x10 | iteracje od początku wyszukiwania (zerowane w „uruchom” przy nowym wyszukiwaniu) |
| +0x14 | liczba wywołań pętli |
| +0x18 | iteracje w bieżącym wywołaniu |
| cel +0x20 (pola: maszyna +0x8C; graf: +0x84) | limit na wywołanie; −1 = bez limitu |
| cel +0x24 (pola: +0x90; graf: +0x88) | limit całkowity; −1 = bez limitu |

Po każdym rozwinięciu węzła pętla sprawdza limity:
- +0x18 ≥ limit na wywołanie → zawieszenie (flaga = 1);
- +0x10 ≥ limit całkowity → koniec bez węzła docelowego.

Zakończenie rozpoznaje test celu (pola 0x41CCA8, graf 0x41E3C0) albo pusta lista otwarta. Flaga = 0, a cel
dostaje wywołanie „koniec” (vtable +8 albo +0x18). Pole +0x94 maszyny decyduje o zwróceniu wyniku częściowego (0x4A5D16)
[W; znaczenie N]. *[Etap 24 – rozpoznane]* +0x94 = cel +0x28, czyli „koniec = najbliższy dostępny węzeł”. Ustawiana
przy pustej otwartej, przy niedostępnym celu i po osiągnięciu limitu (`astar_wyniki.md` § 2–3). [W: kod; P: liczniki zachowane w maszynach z puli]

### 6.2 Wartości

| Gdzie | Limit na wywołanie | Limit całkowity | Pewność |
|---|---|---|---|
| graf, prośba grupowa i etap grafu jednostki | 0xF (bajt 2C = 0) | 0x4A0CE8: d · m, d = odległość euklidesowa pól (0x489D4C), m = 250 (d ≤ 15), 75 (d ≤ 80), 90 (d ≤ 160), 110 (dalej); m ≤ 40, gdy rodzaj podsektora celu nie jest dozwolony dla maszyny; m = 3, gdy ta sama jednostka nie znalazła drogi do tego pola w ciągu 4 s | [W] |
| pola, prośba jednostki | 0xF (bajt 14 = 0) albo −1 | budżet 18 > 0 → ta wartość (0xF przy świeżym rozkazie); inaczej 0x4A0E2F: d · m, m = 375 (d ≤ 15), 140 (d ≤ 80), 145 (dalej); m ≤ 40, gdy obszar jednostki ≠ obszar celu, chyba że typ ma obie flagi +0x5D6 i +0x5D7 | [W] |
| `Bounded` | synchronicznie | margines z § 5 krok 7 (vtable +0x24) | [W] |

**Znaczenie parametrów z etapu 22.** „0xF / −1” przekazywane przez „PrepareToMove” to budżet 18, czyli limit
całkowity A* po polach.
- 0xF: pierwsza próba po świeżym rozkazie, przerwana po 15 iteracjach.
- −1: limit proporcjonalny do odległości.

Ta sama liczba 0xF występuje osobno jako limit na wywołanie (cel +0x20). Obie wartości wynikają z kodu, nie z samych
liczb [W]. Czy krótka pierwsza próba kończy się trasą częściową, zależy od +0x94 [N].

## 7. Odraczanie i wznawianie

| Element | EE | AoC | Opis | Pewność |
|---|---|---|---|---|
| takt menedżera | 0x4A396B ← `EEPhysics` vtable +0x20 (0x546D56) | 0x4A8DB8 | graf (+0x80) → pola (+0x6C) → przebudowa (+0xD8) | [W] |
| kolejka grafu | 0x4A399B | 0x4A8DE8 | patrz niżej | [W] |
| kolejka pól | 0x4A3F1A | 0x4A9367 | patrz niżej; co 10 s porządki +0x48, co 30 s 0x4A3E19 | [W] |
| wynik zawieszonego grafu | 0x4A2A4C | 0x4A7E6C | 0x4A26E3, potem prośba po polach do punktu | [W] |
| przebudowa sektorów | 0x4A3641 → 0x4278C3 | 0x4A8A8E → (0x4245A5) | tylko gdy kolejka grafu pusta i minął czas +0xD4; niedokończona → ponowna próba za 100 ms | [W] |
| zlecenie przebudowy | 0x4288A7 → 0x4A36F3 | → 0x4A8B40 | zmiana obiektu na mapie; +0xD4 = teraz + 1 ms albo + opóźnienie z 0x9183C0 | [W]; +0xD4 ustawione w pomiarze [P] |

Obie kolejki obsługiwane są tak samo:
1. Węzeł z przodu: maszyna kontynuuje (vtable +0x18 graf, +0x20 pola), węzeł +0x30 rośnie o 1.
2. Iteracje wywołania (+0x18) dodają się do licznika taktu.
3. Skończona → zakończenie, zwrot maszyny do puli, zwolnienie węzła.
4. Zawieszona → limit na wywołanie + 1 (do 32), węzeł na koniec kolejki.
5. Pętla działa, dopóki licznik taktu < 32 i kolejka niepusta. Warunek sprawdzany jest przed uruchomieniem, więc takt
   może przekroczyć 32.

**Pomiar [P].** Maszyna pól z puli po rozkazie A miała cel (170, 131), +0x10 = 226 iteracji i +0x14 = 12 wywołań.
Prośba jednostki rozłożyła się więc na kilka taktów, mimo że gra pokazywała ruch od razu. Sumy iteracji nie dało się
dokładnie uzgodnić z regułą „+1 na wywołanie”, bo nie wiadomo, ile prośb obsłużono wcześniej w tej samej maszynie [N].

**Czy wynik zależy od podziału na takty.** Stan wyszukiwania jest zachowany w całości, a zawieszenie przerywa pętlę
między iteracjami. Przy niezmienionej mapie kolejność rozwijania węzłów nie zależy od podziału [W].
Zależność może wprowadzić:
- zmiana mapy między taktami. Koszt pola czytany na bieżąco – [H];
- przebudowa sektorów uruchamiana dopiero przy pustej kolejce grafu. Wzajemne wykluczenie z wyszukiwaniem po polach nie
  jest zapewnione [W];
- dziennik nieudanych prób (mnożnik 3 w ciągu 4 s), zależny od czasu gry [W];
- licznik zawieszonych prośb w marginesie `Bounded`, zależny od obciążenia [W].

## 8. EE ↔ AoC

| Funkcja | EE | AoC | Porównanie znormalizowane |
|---|---|---|---|
| uruchomienie maszyny | 0x4A1681 | 0x4A69E2 | identyczne [P] |
| wybór maszyny grafu | 0x4A1351 | 0x4A6687 | identyczne [P] |
| zakończenie | 0x4A26E3 | 0x4A7B03 | identyczne [P] |
| zakończenie prośby po polach | 0x4A327E | 0x4A86CB | identyczne [P] |
| budżet grafu | 0x4A0CE8 | 0x4A6010 | identyczne poza polami jednostki (+0x9B4 / +0x9A4, +0x347 / +0x353) [P] |
| budżet pól | 0x4A0E2F | 0x4A6157 | AoC sprawdza środowisko przez 0x634AD8 zamiast flag +0x5D6 / +0x5D7 [P] |
| pula maszyn pól | 0x4A13EE | 0x4A6724 | AoC: klucz 0x10 z `EEAIPathGoalModifierSpace` [P] |
| prośba jednostki | 0x4A1AFF | 0x4A6E88 | AoC: klucz 1 / 2 / 0x10, nowy argument (pomija `Bounded` przy +0x8C ≥ 7), `ret 0x20` [P] |
| takt, kolejki, przebudowa | 0x4A396B, 0x4A399B, 0x4A3F1A, 0x4A3641, 0x4A36F3 | 0x4A8DB8, 0x4A8DE8, 0x4A9367, 0x4A8A8E, 0x4A8B40 | identyczne [P] |
| wynik zawieszonego grafu | 0x4A2A4C | 0x4A7E6C | AoC przekazuje dodatkowy argument 0 [P] |
| pętla A* po polach | 0x4A5428 | 0x4AA98D | identyczna [P] |

Pomiar wykonano tylko w EE. Dla AoC opis opiera się na identyczności kodu [W].

## 9. Weryfikacja (zadania MCP 456–463, EE)

Gwardia 0x100018B, scenariusz „Wojna trojańska”, mapa 280 × 280, tylko odczyt pamięci w pauzie (F3).

| Zadanie | Przypadek | Wynik |
|---|---|---|
| 456 | stan po wczytaniu | `EEPathManager`: pule 2 (pola) i 1 (graf), kolejki puste, +0xD0 = 3. `EEAIContinentManager`: 44 obszary, 226 sektorów, 1858 podsektorów, siatka 19 / 15 × 15, siatka podsektorów +0xF8 pusta [P] |
| 457–459 | A: krótka trasa (ok. 8 pól) | +0xD0 3 → 5 (prośby grupowe), jednostka +0x2D4 = 2 prośby. Cel: +0x34 = 4, +0x1D = 1, +0x18 = 2, bez punktów +0x32. Maszyna grafu: cel w komórce (8, 6), 7 iteracji. Maszyna pól: cel (170, 131), 226 iteracji w 12 wywołaniach. Kolejki puste przy każdym odczycie [P] |
| 460–461 | B / C: dłuższa trasa z obejściem (ok. 25 pól, cel z etapu 22) | +0xD0 → 6, +0x2D4 → 4. Maszyna pól z celem (150, 115): 34 iteracje w 3 wywołaniach. Maszyna grafu: komórka (7, 6), 2 iteracje, bez punktów +0x32 [P] |
| 462 | po przebudowie | podsektory 1858 → 1859, w puli nowa maszyna grafu z +0x58 = 1860 [P] |
| 463 | zamknięcie gry | – |

**Ograniczenia.**
- Przypadki B i C połączono: cel z etapu 22 wymaga obejścia, a osobnego celu bez przeszkody na dłuższym dystansie nie
  wyznaczono. W przebiegu ma to znaczenie: graf przeszedł tylko 2 podsektory.
- Kolejki zawieszonych prośb są puste przy każdej pauzie, więc stan zawieszenia widać tylko pośrednio (licznik wywołań).
- Odczyty maszyn z puli pokazują ostatnią obsłużoną prośbę. Przypisanie do badanej jednostki opiera się na polu celu.
- Inne jednostki (AI) używają tych samych maszyn – maszyna `Bounded` zmieniała się między odczytami.
- AoC niezmierzone.

## 10. Nierozpoznane zależności

1. Sposób wydzielania podsektorów, znaczenie rodzaju +0x54 i tablicy maszyny grafu +0xC0 [N] – granica: budowa
   sektorów.
2. Wynik częściowy przy wyczerpaniu limitu (+0x94, 0x4A5D16) i dalsze losy pierwszej próby z limitem 15 [N].
   *[Etap 24]* Wynik częściowy rozpoznany (`astar_wyniki.md`); pierwsza próba z limitem 15 nadal niezmierzona.
3. Obsługa porażki 0x4A2B29 (dziennik +0x48, „CannotPathToTarget”) [N].
   *[Etap 24 – zastąpione]* 0x4A2B29 to zwykłe przekazanie trasy z łączeniem. Dziennik i „CannotPathToTarget”
   nadal [N].
4. Przechowywanie trasy po polach w jednostce (0x5EE4E6) i jej zużywanie przez ruch [N].
   *[Etap 24]* Kolejka +0x7C jednostki, elementy 20 B [P]; zużywanie przez ruch – poza zakresem.
5. Funkcja 0x4A3E19 (co 30 s, pole +0x44) i porządki 0x4A3A54 [N].
6. Rola kontynentów, wzniesień i przewężeń poza budową danych (AI) [N].
7. Dane morskie i kosmiczne: istnienie potwierdzone (modyfikatory, klucze), szczegółów nie badano.

## 11. Błędy oryginału

Bez nowego wpisu.

Do obserwacji, nie jako błąd:
- Tablica mnożników budżetu grafu nie rośnie monotonicznie (250 / 75 / 90 / 110).
- Pętla taktu sprawdza limit 32 przed uruchomieniem maszyny, więc może go przekroczyć.

Oba zachowania wyglądają na zamierzone albo nieszkodliwe [H]. BO-1–BO-4 bez zmian.

## 12. Konsekwencje dla OpenEE (bez zmian w kodzie)

- Dane mapy:
  - siatka sektorów o boku zależnym od rozmiaru mapy;
  - podsektory jako węzły grafu z punktami reprezentatywnymi;
  - osobny podział na obszary do testów „ten sam obszar”.
- Prośba jednostki:
  - graf podsektorów → punkty +0x32;
  - szybka próba w prostokącie;
  - A* po polach do pierwszego punktu.
- Budżety:
  - liczone w iteracjach, osobno na wywołanie i łącznie;
  - globalnie ok. 32 iteracji na takt;
  - limit na wywołanie rośnie przy zawieszeniu.
- Przebudowa danych po zmianie mapy z opóźnieniem, tylko przy pustej kolejce grafu.

## Etap 40 – graf podsektorów: odczyt z gry, A* grafu i punkty pośrednie

**Struktury** [W: kod; P: odczyt Riverlands_MCP `podsektory`, e35_a – 1858 podsektorów, siatka 19 / 15 × 15,
mapa 280 × 280, graf bez zmian po rozkazach]:

| Obiekt | Pole | Znaczenie |
|---|---|---|
| `EEAIContinentManager` 0x917BC8 (vtable 0x8261FC) | +0x5C (początek +0x60, koniec +0x64) | wektor `EEAIPathSubSector*` |
| | +0xE0 / +0xE8 / +0xEC | rozmiar komórki sektora, liczba komórek w poziomie i pionie |
| `EEAIPathSubSector` (0x60 B, vtable 0x82647C, konstruktor 0x42E757) | +0x10 | `U2DSparseArrayPointContainer` – pola podsektora |
| | +0x2C (początek +0x30, koniec +0x34) | sąsiedzi (wskaźniki) |
| | +0x3C / +0x40 | punkt reprezentatywny – pole (int) |
| | +0x44 | sektor (`EEAIPathSector`: +0x40/+0x44 komórka siatki, +0x48 id) |
| | +0x50 / +0x54 | id (u16) / rodzaj (w e35_a 1 i 4) |
| `U2DSparseArrayPointContainer` (Low-Level Engine.dll) | +0x08…+0x0C, +0x14, +0x18 | kubełki kolumn (x = +0x14 + indeks), lista przedziałów {y_min, y_max, …, +0xC następny}; liczba pól |

Pole → podsektor: 0x42609F → 0x42602D (sektor pola 0x425FD4, lista podsektorów sektora +0x08, `Contains`).
Podsektor nie musi być spójny w obrębie sektora (np. 253: kolumny y 114–117 i 129–131) [P odczyt]. Algorytm
wydzielania (0x42434F/0x41E990) i wybór punktu reprezentatywnego – [N].

**A* grafu 0x4A5807** [W: kod]: węzeł = podsektor, pozycja węzła = komórka sektora. Koszt krawędzi 0x41E584: ten sam
sektor 1, sektor sąsiedni w osi 10, po przekątnej 14. H = 10·(|Δi| + |Δj|) komórek sektorów (0x4A6077). Sąsiedzi
rozwijani od końca listy (0x4A5859), filtr rodzaju 0x41E5B6 (tablica celu +0x5C; rodzaj 0xE – dodatkowy warunek).
Test celu 0x41E3C0: węzeł = cel albo sektor węzła w odległości ≤ 1 od sektora celu i cel na liście sąsiadów węzła.

**Wynik 0x4A26E3** [P: 624]: lista od celu do startu; dla i = 0 … n − 3 punkt reprezentatywny + 0,5 jako
EEUGLocation +0x32 na czoło kolejki. W e35_a: gwardia 0x1000858 z pola (162,118) (podsektor 523, rodzaj 4) do pola
(163,105)/(164,105) (podsektor 472, punkt (163,103)) – ścieżka 472 ← 469 ← 523 (523 nie jest sąsiadem 472) → jeden
punkt (163,5; 103,5). Gwardia 0x1000856 z (164,118) (podsektor 469, sąsiad 472) – ścieżka 2 podsektorów, bez punktu.
