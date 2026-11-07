# Droga rozkazu ruchu gracza (klik → EEPhysics) – Empire Earth / The Art of Conquest

Etap 16 OpenEE, trzeci wpis atlasu funkcji silnika Titan (`docs/titan/README.md`). Opisuje jeden typ rozkazu: zwykły
ruch zaznaczonych jednostek do punktu na mapie (prawy przycisk na terenie). Zegar i przydział taktów, na których rozkaz
jest wykonywany, opisują `zegar_symulacji.md` i `przydzial_taktow.md`.

**Oznaczenia:**
- **[P]** potwierdzone kodem w obu grach i pomiarem albo kodem jednoznacznym w obu plikach;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pliki: EE `Empire Earth.exe` (`e352d7ae…a2b5`), AoC `EE-AOC.exe` (`db8fc5ce…7f52`), biblioteki `Low-Level Engine.dll`
obu gier (`docs/titan/przydzial_taktow.md`, tabela plików). Metoda: analiza statyczna (pefile + capstone, RTTI, nazwy
eksportów DLL), porównanie EE ↔ AoC instrukcja po instrukcji po normalizacji adresów, minimalne pomiary (tylko odczyt).

## Wynik w skrócie

1. Kliknięcie na mapie obsługuje akcja interfejsu **`EEAMouseClick`** (vtable +0x0C). Na terenie, przy zaznaczonych
   jednostkach, tworzy ona komunikat **`EEMPathTo`** („Path To”, typ **0x4D**). Komunikat trafia do akcji, a akcja do
   menedżera akcji [P: kod].
2. Komunikat **nie zawiera identyfikatorów jednostek**. Odnosi się do *zaznaczonej grupy gracza w symulacji*, którą
   ustawiają osobne komunikaty zaznaczenia, wysyłane tą samą drogą. Komunikat zawiera:
   - współrzędne celu (f32 x, y);
   - wartość f32 (kąt lub kierunek, [W]);
   - cztery bajty flag;
   - **numer wersji zaznaczenia** [P].
3. W pętli głównej menedżer wykonuje akcję (vtable +4). Akcja oddaje komunikat do serwera lockstep:
   `EEServer` → `NESynchronousServer::ProcessLocalUserInput`. Dalej `EEServer` vtable +0x60 stempluje komunikat wersją
   zaznaczenia. `NERecordPlayback::Process` (w zwykłym trybie przekazuje bez zapisu) prowadzi do `ProcessLocalUserInput2`,
   a ta wstawia komunikat do **kolejki serwera +0x84** [P: kod].
4. Najbliższy `SendCommunicationsTick`, wywoływany co 350 ms, dołącza oczekujące polecenia do `NEMCommunicationsTick`
   (do 0x240 B) [P].
5. Obsługa komunikatu 0x26 w `EEServer` wstawia do kolejki `EEPhysics` najpierw `NEMPhysicsTick`, a potem polecenia.
   `EEPhysics`, przyjmując `NEMPhysicsTick` (+0x0C = liczba poleceń), **natychmiast wykonuje dołączone polecenia, przed
   pierwszym z nowo przydzielonych taktów** [P: kod].
6. `EEMPathTo::Execute` sprawdza pole celu i dla zaznaczonej grupy gracza tworzy grupy ruchu z celem. W EE robi to w
   4, w AoC w 5 przebiegach, co odpowiada podziałowi na rodzaje jednostek [H]. Dalej zaczyna się podsystem ruchu i
   wyszukiwania tras, czyli granica tego dokumentu. [Etap 17: przebiegi to grupy środowiska ruchu –
   powietrze, ląd, nawodne, podwodne, w AoC kosmos; `docs/titan/grupy_ruchu.md`.]
7. **Opóźnienie:** rozkaz wykonuje się na granicy taktu komunikacji. Od kliknięcia do pierwszej zmiany kierunku
   jednostki zmierzono 0,10–0,30 s, w granicach algorytmu: do 350 ms plus klatka i takt [P: pomiar EE i AoC zgodny
   z kodem].
8. **EE ↔ AoC:** logika identyczna. Różnice:
   - przesunięcia pól obiektu gracza, np. zaznaczona grupa: EE +0x9BC, AoC +0x9AC;
   - liczba przebiegów w `Execute`: 4 w EE, 5 w AoC;
   - w AoC rozbudowana funkcja kliknięcia (więcej rodzajów celów).

   Komunikat `EEMPathTo` i jego serializacja są identyczne [P].

## Struktury

### `EEMPathTo` (pochodna `EEMessage` : `NEMessage`), typ 0x4D, w pamięci 0x20 B, po serializacji 21 B

| Pole | Typ | Znaczenie | Pewność |
|---|---|---|---|
| +0x04 | u32 | licznik referencji (`UReferenceCounter`) | [P] |
| +0x08 | u8 | typ = 0x4D | [P] |
| +0x09 | u8 | adresat: 0xFF = wszyscy (ustawiane w `ProcessLocalUserInput`) | [P] |
| +0x0A | u8 | nadawca: 0xFE = lokalny gracz serwera. Obiekt gracza o polu +0x464 = 0xFE; w pomiarze ludzki gracz 1 ma +0x464 = 254 | [P] |
| +0x0B | u8 | 0 (argument konstruktora `NEMessage`) | [P] |
| +0x0C | u8 | **wersja zaznaczenia** – stempel z `EEServer`+0x349 | [P] |
| +0x0D | u8 | 0; poza serializacją | [P] |
| +0x10 | f32 | wartość przekazywana do obiektu celu ruchu. W ścieżce minimapy jest to wynik `atan2` wektora od środka widoku, czyli kąt lub kierunek | [W] |
| +0x14 / +0x18 | f32 | **x, y celu** (jednostki pól mapy) | [P] |
| +0x1C | u8 | 1, gdy w flagach kliknięcia bit 1 = 0. Prawdopodobnie „zastąp rozkaz” (bez Shift); przekazywane do celu ruchu | [W] [Etap 17 – zastąpione: przy Shift+PPM pole pozostaje 1, więc to nie flaga Shift; znaczenie [N] – `grupy_ruchu.md`] |
| +0x1D | u8 | argument kliknięcia, przekazywany do celu ruchu | [N] znaczenie |
| +0x1E | u8 | bajt flag kliknięcia (w minimapie: bit 0 flag), przekazywany do ustawienia celu grupy | [N] znaczenie [Etap 17: **Shift** – grupa +0xB5 = 1 przy Shift+PPM, pomiar AoC; [P]] |
| +0x1F | u8 | przepisywany do obiektu celu ruchu (+0x33) | [N] znaczenie |

Serializacja (`ExportMessage` / `ImportMessage`):
- nagłówek `NEMessage`;
- potem kolejno: +0x0C (1 B), +0x10, +0x14, +0x18 (po 4 B), +0x1C…+0x1F (po 1 B);
- `ExportSize` = 0x15 [P].

### Inne

- `NEMPhysicsTick` +0x0C = liczba poleceń graczy dołączonych do taktu komunikacji (`przydzial_taktow.md`) [P].
- `EEServer`:
  - +0x349 – licznik wersji zaznaczenia (u8);
  - +0x34A – flaga „trwa lokalne stosowanie zaznaczenia”;
  - +0x34B – blokada zaznaczania;
  - +0x338 + indeks gracza – wersja zaznaczenia ostatnio wykonana w symulacji, dla każdego gracza.

  Po stronie klienta (`EEClient`): +0xF3 i +0xE2. [P: kod; pomiar +0x349 i +0x338[1] 0 → 1 po zaznaczeniu]
- Obiekt gracza (EE / AoC):
  - +0x9BC / +0x9AC – zaznaczona grupa w symulacji, używana przez `Execute`;
  - +0x9C0 / +0x9B0 – zaznaczenie interfejsu, zmieniane od razu (zgodne z pomiarem 106 z etapu 12);
  - +0x45C – indeks gracza;
  - +0x464 – numer gniazda sieci.

  [P dla EE +0x9BC/+0x45C/+0x464 – kod i pomiar; AoC – kod]

## Funkcje

| Funkcja | EE | AoC | Zgodność |
|---|---|---|---|
| `EEAMouseClick` vtable | 0x824DEC | 0x838DC8 | – |
| `EEAMouseClick` +0x0C – obsługa kliknięcia, tworzy `EEMPathTo` (ścieżki teren / obiekt) | 0x403CF1 (`EEMPathTo`: 0x404871, 0x4048B2, 0x404916) | 0x403350 | logika `EEMPathTo` zgodna; funkcja AoC dłuższa (1202 / 1123 instr.) |
| `EEAMouseClick` +4 – wykonanie akcji: statystyka + `ProcessLocalUserInput(komunikat, 0xFF)` | 0x403AA1 | 0x403009 | identyczne |
| `EEAMiniMap` +4 – rozkaz z minimapy (`EEMPathTo`, kąt z `atan2`) | 0x40352C → 0x403542 | 0x402A94 | zgodne co do `EEMPathTo` |
| Menedżer akcji: dodanie akcji / pętla wykonania (kolejka +4 → vtable +4 → lista „cofnij” +0x18) | 0x66192F / 0x6608D7 (wywołanie z pętli głównej 0x661903) | – | [W] dla AoC (nie porównywano) |
| `EEMPathTo` vtable | 0x824D84 | 0x838D5C | – |
| `EEMPathTo::ExportMessage` / `ImportMessage` / `ExportSize` | 0x4BA0A0 / 0x4BA199 / 0x4BA18F | 0x4C2B41 / 0x4C2C36 / 0x4C36FC | identyczne (różni się tylko numer wiersza w asercji) |
| `EEMPathTo::Execute` | 0x4B9D7B | 0x4C281C | identyczne poza przesunięciami pól gracza i liczbą przebiegów (5 / 6 w warunku pętli) |
| Fabryka `EEMessage` z bajtów (typ 0x4D) | 0x4B25A8 | – | – |
| `EEServer` +0x60 – stempel wersji zaznaczenia / lokalne zastosowanie zaznaczenia | 0x4C3D90 | 0x4CC1F9 | identyczne |
| `EEServer` +0x5C – filtr komunikatów przed kolejką | 0x4C3B92 | 0x4CBFD0 | identyczne |
| DLL `NESynchronousServer::ProcessLocalUserInput` | 0x10054578 | 0x1004855D | identyczne |
| DLL `NERecordPlayback::Process` | 0x10051D2D | 0x10045850 | identyczne (numery wierszy w asercjach) |
| DLL `NESynchronousServer::RecordPlaybackCallback` | 0x100548C1 | 0x100488A6 | jw. |
| DLL `NESynchronousServer::ProcessLocalUserInput2` – kolejka +0x84 | 0x100545D1 | 0x100485B6 | identyczne |
| DLL `SendCommunicationsTick` – dołączenie poleceń (`AddPlayerInput`) | 0x10054AB8 | 0x10048A9D | identyczne |
| EXE `EEServer` +0x6C – komunikat 0x26 → `NEMPhysicsTick` + polecenia do kolejki `EEPhysics` | 0x4C3839 | 0x4CBC77 | identyczne |
| `EEPhysics` – obsługa komunikatu 0x28 i wykonanie dołączonych poleceń | 0x5470B0 (pętla poleceń 0x547263) | 0x55355C | identyczne |
| Wykonanie rozkazu z kontrolą wersji zaznaczenia | 0x4B1A29 | 0x4B8E86 | identyczne poza przesunięciami pól gracza |
| Wykonanie komunikatu zaznaczenia (zapis wersji) | 0x4B18C5 | 0x4B8CF7 | logika zgodna, inna alokacja rejestrów i przesunięcia |
| Gracz o numerze gniazda (+0x464) | 0x52E6EF | – | – |

## Algorytm

### 1. Kliknięcie → akcja

`EEAMouseClick` +0x0C dostaje między innymi punkt mapy (f32 x, y) i flagi kliknięcia. Sprawdza obiekt pod kursorem;
jeżeli to teren, a gracz ma zaznaczone jednostki, tworzy `EEMPathTo` (typ 0x4D, adresat i nadawca 0xFF, +0x0B = 0) z
polami jak w tabeli. Dla celu będącego obiektem, np. budynku, punkt bierze z obiektu.

Komunikat zostaje zapisany w akcji (+0x0C), a akcja dodana do menedżera akcji (globalny wskaźnik EE 0x91977C) [P].
Przy okazji uruchamiane są efekty lokalne, np. znacznik celu i dźwięk; to nie są komunikaty [W].

### 2. Akcja → serwer lockstep

Pętla główna (EE 0x661903 → 0x6608D7) zdejmuje akcje z kolejki menedżera i woła ich vtable +4. `EEAMouseClick` +4:
- dopisuje statystykę gracza (licznik 0x15);
- woła `EEServer` vtable +0x18, czyli `NESynchronousServer::ProcessLocalUserInput(komunikat, 0xFF)`;
- zeruje swoje pole komunikatu.

Akcja trafia potem na listę „cofnij” (do 100 pozycji) [P: kod].

### 3. `ProcessLocalUserInput` → kolejka serwera

1. W sesji wieloosobowej, w pauzie, komunikat musi mieć `GetCanSendWhilePaused`. Zawsze musi mieć wynik 1 z vtable +4
   (dostępny do wysłania). Inaczej zostaje odrzucony [P].
2. +0x0A = 0xFE, +0x09 = 0xFF.
3. `EEServer` +0x60:
   - dla komunikatów zaznaczenia (typy 0x48–0x4B, 0x4E–0x50, 0x76, 0x82, 0x84, 0x96) zwiększa +0x349, stempluje nim
     komunikat i od razu stosuje zaznaczenie lokalnie (interfejs);
   - dla pozostałych `EEMessage`, w tym `EEMPathTo`, tylko stempluje komunikat bieżącą wartością +0x349 [P].
4. `NERecordPlayback::Process`. W trybie 1 woła wywołanie zwrotne od razu; w trybie 2 najpierw zapisuje komunikat ze
   znacznikiem czasu (nagrywanie) [P].
5. `RecordPlaybackCallback`: przy nadawcy 0xFE `ProcessLocalUserInput2` [P].
6. `ProcessLocalUserInput2`: w pauzie komunikat musi mieć vtable +4. Potem filtr `EEServer` +0x5C i, w sekcji
   krytycznej +0x15C, dopisanie do kolejki +0x84 [P].

### 4. Kolejka → takt komunikacji

`SendCommunicationsTick` (co 350 ms, `przydzial_taktow.md` § 2) dołącza komunikaty z kolejki +0x84 do
`NEMCommunicationsTick`, dopóki łączny rozmiar nie przekroczy 0x240 B. Pozostałe czekają na następny takt [P]. Takt
komunikacji z poleceniami jest wysyłany do wszystkich; w grze jednoosobowej trafia do obsługi `EEServer` +0x6C [W co do
drogi dostarczenia].

### 5. Takt komunikacji → `EEPhysics`

`EEServer` +0x6C (typ 0x26):
1. W sekcji krytycznej `EEPhysics`+0x4C wstawia do kolejki `EEPhysics` `NEMPhysicsTick`. Pole +0x0C to liczba poleceń
   z adresatem 0xFF lub 0xFE.
2. Następnie wstawia te polecenia.

`EEPhysics` (0x5470B0), zdejmując `NEMPhysicsTick`:
1. Ustawia liczbę taktów (+0xB8) i n (etapy 14–15).
2. **W tym samym wywołaniu** zdejmuje +0x0C kolejnych komunikatów i wykonuje każdy z nich:
   - zwiększa licznik 0x919B68 (AoC 0x931CF0) przy adresacie 0xFF;
   - typ 0x2B obsługuje osobno;
   - komunikaty zaznaczenia przekazuje do 0x4B18C5;
   - pozostałe `EEMessage`, w tym `EEMPathTo`, przekazuje do 0x4B1A29;
   - inne obsługuje przez vtable +0x28 (`Execute`) [P].

Polecenia działają więc od pierwszego taktu nowej porcji, a rozkaz wydany w trakcie porcji czeka na następny takt
komunikacji.

0x4B1A29, czyli kontrola wersji zaznaczenia:
- znajduje gracza po +0x0A (gniazdo);
- porównuje +0x0C komunikatu z wersją zaznaczenia ostatnio wykonaną w symulacji dla tego gracza;
- przy zgodności (albo dla typu 0x91) woła `Execute`;
- przy niezgodności rozkazu **nie wykonuje**, tylko woła funkcje gracza i grupy 0x55C618 / 0x5F92FF. Prawdopodobnie
  przywracają one zaznaczenie interfejsu [W].

Chroni to przed wykonaniem rozkazu na innym zaznaczeniu niż to, które gracz widział [W].

### 6. `EEMPathTo::Execute` – granica

1. Gracz według +0x0A. Zaznaczona grupa symulacji: gracz +0x9BC (AoC +0x9AC).
2. Sprawdzenie pola celu w mapie przejść. Przy polu niedostępnym cel jest przenoszony na najbliższe dostępne pole
   (środek pola), a +0x14/+0x18 zostają nadpisane [P: kod].
3. W kolejnych przebiegach (EE: 1–4, AoC: 1–5):
   - utworzenie obiektu grupy (0xB8 B), wypełnionego jednostkami z zaznaczenia według numeru przebiegu [H: rodzaj
     jednostek];
   - rejestracja grupy u gracza (+0x844 / AoC +0x854);
   - utworzenie obiektu celu ruchu (0x38 B) z punktem, +0x10, +0x1C, +0x1D, +0x1F;
   - ustawienie celu grupy z +0x1E;
   - +0x6C grupy = 8000 [N: znaczenie].

Dalsze działanie – podział na miejsca w szyku, wyszukiwanie tras, ruch – należy do podsystemu grup i ruchu. Etapy 9 i
13 znają je z pomiarów (`docs/MECHANIKA_RUCHU_EE.md`). **Granica tego dokumentu** to funkcje 0x5DB37C (konstruktor
grupy), 0x614D47 (cel ruchu) i 0x5DD436 (ustawienie celu) [P co do adresów, znaczenie [W]].

## Weryfikacja

Zadania MCP, tylko odczyt pamięci:
- 368 (EE) i 370 (AoC): scenariusz `e13_para`, zaznaczenie jednego obywatela ramką, prawy przycisk na terenie;
- 372 (EE): kontrola tła i rozkaz z Shift;
- sprzątanie: 369, 371, 373.

| Sprawdzenie | Oczekiwanie z kodu | Wynik (EE / AoC) | Status |
|---|---|---|---|
| Gniazdo lokalnego gracza | gracz o +0x464 = 0xFE | lokalny indeks 1, gracz 1 +0x464 = 254 (EE i AoC) | [P] |
| Zaznaczenie ramką | +0x349: 0 → 1; po wykonaniu w symulacji +0x338[1] = 1; licznik poleceń +1 | 0 → 1; [0, 1, 0, …]; 0 → 1 (EE i AoC) | [P] |
| Tło bez działań gracza | licznik poleceń stały | 0, 0, 0 przez 6 s; po zaznaczeniu 1, 1, 1 (EE) | [P] – gracze komputerowi nie dają poleceń w tym oknie |
| Rozkaz ruchu (PPM) | `EEMPathTo` nie zmienia wersji zaznaczenia | +0x349 bez zmian (EE i AoC) | [P] |
| Rozkaz ruchu – liczba poleceń | ≥ 1 (`EEMPathTo`) | +1 w ciągu 0,3 s i **jeszcze +1 w ciągu kolejnych 3 s** (EE i AoC) | `EEMPathTo` [P]; drugie polecenie [N] |
| Rozkaz z Shift | – | +3 od razu, +1 później | [H]: `EEMEnterShiftMode` / `EEMExitShiftMode` + `EEMPathTo`; drugie polecenie jw. |
| Opóźnienie rozkaz → ruch | do ok. 350 ms (granica taktu komunikacji) + klatka/takt | 0,155–0,188 s; 0,100–0,133 s (EE); 0,267–0,300 s (AoC) | zgodne [P] |

Porównanie kodu EE ↔ AoC: tabela funkcji.

## Nierozpoznane zależności i przeszkody

1. **Drugie polecenie po rozkazie ruchu.** Po każdym rozkazie, z Shift lub bez, symulacja wykonuje jeszcze jedno
   polecenie z adresatem 0xFF, 0,3–3,3 s po kliknięciu. Nie zmienia ono wersji zaznaczenia. Jego typu nie ustalono, bo
   odczyt pamięci nie pokazuje typów komunikatów w kolejce.

   Pewne jest tylko to, że nie pochodzi od graczy komputerowych w tle (kontrola: brak zmian bez działań gracza). Kandydat
   [H]: polecenie wysyłane przez interfejs lub akcję po potwierdzeniu rozkazu. Do ustalenia, gdy będzie potrzebne;
   wymaga śledzenia kolejki serwera albo pułapki w kodzie.
2. **Menedżer akcji** (klasa, pełna obsługa cofnij/ponów) – część interfejsu, nie analizowano.
3. **Podsystem grup i ruchu** od `EEMPathTo::Execute` w dół: szyk, trasy, cele grup.
4. **Znaczenie pól** +0x10, +0x1D, +0x1E, +0x1F i bitów flag kliknięcia (który bit to Shift) – [W]/[N].
5. **Droga dostarczenia** taktu komunikacji do `EEServer` +0x6C w grze jednoosobowej – [W] (jak w etapie 15).

## Konsekwencje dla OpenEE (bez zmian w kodzie)

Wierny model rozkazów (do późniejszej implementacji):
- rozkaz ruchu jako komunikat bez listy jednostek, odnoszący się do zaznaczenia gracza w symulacji;
- zaznaczenie jako osobne komunikaty z numerem wersji;
- kolejka poleceń wysyłana porcjami co 350 ms razem z przydziałem taktów;
- wykonanie poleceń w symulacji przed pierwszym taktem porcji, czyli opóźnienie do 350 ms;
- kontrola wersji zaznaczenia.

Obecnie OpenEE robi to inaczej:
- `SterowanieRTS` przekazuje do `Symulacja.rozkaz_grupy` listę identyfikatorów zaznaczonych jednostek;
- rozkaz wykonuje się na początku następnego taktu, czyli po 0,05 s.

Różnice wobec oryginału: brak komunikatu zaznaczenia i wersji, brak porcji co 350 ms, czas reakcji krótszy o do 0,3 s.
