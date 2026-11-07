# OpenEE – raport etapu 23: architektura wyszukiwania tras w silniku Titan

Dziesiąty etap rekonstrukcji kodu silnika Titan. Odtwarza budowę podsystemu tras: obiekty i ich relacje, wybór maszyny
A*, przepływ prośby jednostki lądowej, budżety i odraczanie obliczeń. Pętla A*, heurystyka i koszty pól pozostają poza
zakresem. Szczegóły: **`docs/titan/architektura_nawigacji.md`**.

**Oznaczenia:**
- **[P]** potwierdzone;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Stan wyjściowy: commit `33a5be3`, testy Godota 324/324.

## 1. Wynik (warunek zakończenia)

1. **Warstwy systemu** [W: kod; P: liczności w pamięci].
   - `EEPathManager` (EE 0x917D00, AoC 0x92FCB8) przyjmuje prośby. Trzyma pule maszyn, dwie kolejki odroczeń i dziennik
     nieudanych prób.
   - `EEAIContinentManager` (EE 0x917BC8) trzyma dane mapy.
   - Takt obsługi woła `EEPhysics` (vtable +0x20 → 0x4A396B).
2. **Sektory, podsektory, obszary: osobne warstwy danych, nie jedna hierarchia** [W; P: liczby].
   - **Sektor** to komórka stałej siatki. Na mapie 280 × 280: komórki po 19 pól, 15 × 15 komórek, 226 obiektów
     w wektorze.
   - **Podsektor** to węzeł grafu. Ma identyfikator (+0x50), punkt reprezentatywny (+0x3C, +0x40), sektor nadrzędny
     (+0x44) i wektor sąsiadów (+0x2C). Na badanej mapie 1858, po przebudowie 1859.
   - **Obszar** to osobny podział mapy (44 obszary, siatka pól +0xF4). Służy tylko do testu „ten sam obszar” w budżecie.
3. **Wybór maszyny** [W: kod].
   - Prośba grupowa → `EEAIAStarGraphMachine` (graf podsektorów).
   - Prośba jednostki → opcjonalnie graf. Włącza się dla celu położenia bez +0x32, z +0x1D = 0.
   - Następnie szybka próba `EEAIAStarMachine<Bounded…>` w prostokącie wokół startu i celu.
   - Na koniec `EEAIAStarMachine<Storage, PathfindingGoal, EEMap>` po polach.
   - Klucz maszyny pól: ląd 1, morze 2 (modyfikator `Sea`). AoC dodaje kosmos 0x10 (modyfikator `Space`).
   - Maszyny `PathSector`, `PathArea`, `Continent`, `Hill` i `ChokePoint` służą do budowy i przebudowy danych mapy,
     nie do próśb.
4. **Przepływ prośby** [W: kod; P: pomiar maszyn].
   - Na etapie grafu maszyna dostaje komórkę sektora i identyfikator podsektora startu i celu.
   - Wynik zamienia się:
     - dla grupy – na punkty reprezentatywne w `EEAutoPathRequest`+0x08;
     - dla jednostki – na cele `EEUGLocation` +0x32, z pominięciem ostatniego podsektora.
   - A* po polach prowadzi do pierwszego punktu. Gotowa trasa po polach (wektor punktów 12 B) trafia do jednostki
     przez 0x5EE4E6.
5. **Budżety** [W: kod; P: liczniki w maszynach].
   - Liczone są **iteracje A*** (zdjęcie węzła i rozwinięcie sąsiadów). Każda maszyna ma limit na wywołanie
     (cel +0x20, po nim zawieszenie) i limit całkowity (cel +0x24, po nim koniec bez wyniku). −1 oznacza brak limitu.
   - **0xF / −1 z etapu 22** to limit całkowity A* po polach: 15 iteracji przy świeżym rozkazie albo wartość wyliczona
     z odległości (×375 / ×140 / ×145, z ograniczeniami).
   - Osobno 0xF jest domyślnym limitem na wywołanie.
6. **Odraczanie** [W: kod; P: pomiar].
   - Zawieszona maszyna trafia do kolejki +0x5C (pola) albo +0x70 (graf).
   - W każdym takcie kolejki dostają łącznie ok. 32 iteracji. Limit na wywołanie zawieszonej maszyny rośnie o 1 (do 32).
   - Wznowienie to ponowne „uruchom” bez inicjalizacji. Stan zostaje w maszynie.
   - Przy stałej mapie podział na takty nie zmienia kolejności rozwijania węzłów [W].
   - Pomiar: prośba po polach do celu rozkazu A rozłożyła się na 12 wywołań (226 iteracji).
7. **Przebudowa po zmianie mapy** [W; P: ślad w pamięci].
   - Postawienie albo usunięcie obiektu planuje przebudowę (0x4288A7 → 0x4A36F3).
   - Takt wykonuje ją tylko przy pustej kolejce grafu.
   - Zmiana liczby podsektorów unieważnia maszyny grafu z puli. Pomiar: 1858 → 1859 podsektorów, nowa maszyna z +0x58 = 1860.
8. **EE ↔ AoC.** Uruchomienie, wybór maszyny grafu, zakończenie, takt, kolejki, przebudowa i pętla A* po polach są
   identyczne w porównaniu znormalizowanym [P].
   - AoC wybiera środowisko przez 0x634AD8 i ma klucz kosmiczny 0x10.
   - AoC ma dodatkowy argument prośby jednostki: pomija próbę `Bounded` przy +0x8C ≥ 7.

## 2. Weryfikacja

Najpierw analiza statyczna EE i AoC, potem zadania MCP 456–463 (tylko EE). Tylko odczyt pamięci w pauzie, gwardia
0x100018B, „Wojna trojańska”.

| Przypadek | Wynik |
|---|---|
| stan po wczytaniu (456) | pule maszyn 2 / 1, kolejki puste; 44 obszary, 226 sektorów, 1858 podsektorów, siatka 19 / 15 × 15; siatka podsektorów +0xF8 pusta [P] |
| A: krótka trasa (457–459) | 2 prośby grupowe, 2 prośby jednostki; graf: komórka celu (8, 6), bez punktów +0x32; pola: cel (170, 131), 226 iteracji w 12 wywołaniach [P] |
| B / C: dłuższa trasa z obejściem (460–461) | graf: komórka (7, 6), 2 iteracje, bez punktów; pola: cel (150, 115), 34 iteracje w 3 wywołaniach [P] |
| przebudowa (462) | 1859 podsektorów, nowa maszyna grafu +0x58 = 1860 [P] |

**Ograniczenia.**
- Przypadki B i C połączono (cel z etapu 22 wymaga obejścia).
- Kolejki zawieszonych próśb były puste przy każdej pauzie, więc zawieszenie widać tylko w licznikach.
- Maszyny z puli pokazują ostatnią obsłużoną prośbę. Przypisanie do badanej jednostki opiera się na polu celu.
- AoC niezmierzone; zgodność wynika z identycznego kodu.

## 3. Korekty wcześniejszych ustaleń

Adnotacje „[Etap 23 – …]” w `docs/titan/nawigacja_wejscie.md`:

1. Wynik `EEAutoPathRequest`+0x08 to punkty reprezentatywne podsektorów z trasy po grafie, nie kolejne pola.
2. Prośba jednostki może sama wstawiać cele +0x32 przez etap grafu.
3. Punkty przy przejściu do następnego celu Shift (etap 22, [N]) najpewniej pochodzą z etapu grafu prośby jednostki,
   nie z trasy grupowej. Zgadza się to ze zmierzonym celem B: +0x34 = 0, +0x1D = 1 [W].
4. Znaczenie parametrów 0xF / −1 i adresy AoC 0x4A69E2 / 0x4A7B03.

## 4. Błędy oryginału

Bez nowego wpisu. Do obserwacji: niemonotoniczne mnożniki budżetu grafu (250 / 75 / 90 / 110) i możliwe przekroczenie
32 iteracji na takt [H – raczej zamierzone]. BO-1–BO-4 bez zmian.

## 5. Przeszkody i nierozpoznane

1. Wydzielanie podsektorów, rodzaj podsektora +0x54, tablica maszyny grafu +0xC0 – granica budowy sektorów [N].
2. Wynik częściowy przy wyczerpaniu limitu (+0x94, 0x4A5D16) i skutek pierwszej próby z limitem 15 [N].
3. Obsługa porażki 0x4A2B29 („CannotPathToTarget”), dziennik +0x48 [N].
4. Przechowywanie i zużywanie trasy po polach w jednostce [N].
5. Riverlands_MCP nie było rozbudowywane. Odczyt maszyn z pul wymagał dwufazowych zadań: najpierw adresy bloków,
   potem maszyny.

## 6. OpenEE (bez zmian w kodzie)

Do wiernego odtworzenia potrzebne są:
- warstwy danych: siatka sektorów, graf podsektorów, obszary;
- prośba jednostki: graf → punkty +0x32 → szybka próba w prostokącie → A* po polach;
- budżety w iteracjach: limit na wywołanie i całkowity;
- kolejki odroczeń z globalnym limitem ok. 32 iteracji na takt;
- przebudowa danych po zmianie mapy.

## 7. Zmiany w repozytorium

| Plik | Zmiana |
|---|---|
| `docs/titan/architektura_nawigacji.md` | nowy wpis atlasu Titan |
| `docs/titan/nawigacja_wejscie.md` | odnośnik, adnotacje „[Etap 23 – …]” |
| `docs/titan/README.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` | atlas, stan wiedzy, etap 23, nowy aktualny raport |
| `RAPORT_ETAP_22.md` → `raporty/archiwum/` | archiwum |
| `dane/launcher/aktualnosci.json` | wpis „Etap 23”, poprzedni raport w archiwum |

Kod gry, silnika i MCP – bez zmian.

## 8. Testy

| Zestaw | Wynik |
|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 324/324 |
| `git diff --check` | czysto |
| Testy „L aktualności” | najnowszy wpis = `RAPORT_ETAP_23.md` |

## 9. Commit

Jeden commit na `main`, lokalnie, bez `git push`.
