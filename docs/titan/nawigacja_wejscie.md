# Wejście do nawigacji: od celu `EEUGLocation` do punktów pośrednich – Empire Earth / The Art of Conquest

Wpis atlasu Titan, etap 22. Opisuje, kto i kiedy prosi o trasę po nadaniu celu ruchu, jakie dane trafiają do
podsystemu tras i jak jego wynik staje się celami `EEUGLocation` z flagą +0x32 = 1 w kolejce jednostki
(`kolejka_rozkazow.md`). Algorytmu wyszukiwania (A*), kosztów terenu i ruchu w taktach tu nie rekonstruujemy, a jedynie
wyznaczamy ich granice.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## Wynik w skrócie

1. **Dwa poziomy tras** [W: kod; P: pomiar skutków].
   - **Trasa grupowa** zaczyna się od obsługi stanu grupy 8000. Na jej końcu grupa (vtable +0x44 albo +0x40) prosi
     menedżera tras `EEPathManager` (obiekt globalny EE 0x917D00, AoC 0x92FCB8) o trasę z pola startowego do pola
     celu. Robi to osobno dla każdej podgrupy jednostek.
   - Wynik to lista **pól mapy (całkowite x, y)**. `EEGroup::ZastosujTrase` (vtable +0x38) zamienia go na punkty
     środków pól, przesunięte szykiem. Następnie 0x5EDF6B tworzy z nich cele `EEUGLocation` z +0x32 = 1 i wstawia je
     **na początek** kolejki jednostki.
   - **Trasa jednostki** powstaje przy wejściu jednostki w stan 8000 („PrepareToMove”, EE 0x6222A8). Jednostka prosi
     menedżera o trasę z własnego pola (+0x1C, +0x20) do pola celu (0x4A1AFF). Ta trasa **nie trafia** do kolejki celów
     [W].
2. **Natychmiast albo w kolejnych taktach.** Menedżer wykonuje wyszukiwanie od razu w wywołaniu prośby.
   - Gdy maszyna wyszukiwania skończy (+0x24 = 0), wynik jest gotowy: +0x4C = 1 i grupa stosuje go od razu.
   - Gdy nie skończy, prośba trafia do kolejki menedżera (+0x70). Grupa zapamiętuje ją w swojej mapie oczekujących
     (+0x08…+0x14) i sprawdza w każdej aktualizacji (vtable +0x34 → +0x3C).

   [W: kod]. W pomiarach mapa oczekujących grupy była zawsze pusta [P].
3. **Brak punktów pośrednich na otwartym terenie i przy krótkich trasach** [P].
   - Po zwykłym rozkazie kolejka miała tylko cel gracza, a +0x34 tego celu = 4, czyli „trasa grupowa zastosowana bez
     punktów”. Tak było nawet przy długim obejściu przeszkody (EE 444, 445; AoC 454).
   - Obejście wykonywała wtedy trasa jednostki.
4. **Punkty pośrednie pojawiły się** w EE i AoC tylko przy przejściu do następnego celu z kolejki Shift. W chwili
   zdjęcia celu A przed celem B pojawiły się **dwa** cele +0x32 naraz, na środkach pól: (179,5; 118,5) i (178,5; 123,5)
   [P: EE 448, 451, AoC 454, wcześniej EE 431]. Kto w tym momencie zleca trasę grupową – [N].
5. **Kolejność i zastąpienie.**
   - Punkty wstawiane są od ostatniego do pierwszego, każdy na początek, więc w kolejce stoją we właściwej kolejności
     przed celem gracza [W: kod; P: pomiar].
   - Cel gracza pozostaje osobnym elementem; +0x1EC wskazuje na niego.
   - Gdy na początku kolejki stoi już punkt +0x32, nowe punkty nie są dodawane [W].
   - Zwykły rozkaz usuwa wszystkie punkty razem z kolejką [P: EE 435, AoC 454].

## Funkcje i adresy

| Funkcja | EE | AoC | Pewność |
|---|---|---|---|
| Koniec obsługi stanu grupy 8000 → prośba o trasy (vtable +0x44 / +0x40) | 0x5DCDDF / 0x5DCE0A | (ta sama logika) | [P] kod |
| `EEActiveGroup` vtable +0x44 = +0x40(wszystkie jednostki grupy +0x20) | 0x5DB4AE | 0x5EBDF2 | [P] kod |
| `EEActiveGroup` vtable +0x40 – podział na podgrupy (0x5F70A3, argument 10), prośba dla każdej | 0x5DB4B8 | 0x5EBDFC | [W] |
| Prośba grupy: identyfikatory jednostek, `EEPathManager` 0x4A15E7, `EEGroupPathRequest`, zastosowanie od razu albo zapamiętanie | 0x5F670A | 0x606581 | [P] kod (identyczne) |
| `EEPathManager` – prośba o trasę (tworzy `EEAutoPathRequest`, 0x50 B) | 0x4A15E7 | 0x4A6948 | [P] kod (identyczne) |
| `EEPathManager` – uruchomienie maszyny, kolejka +0x70 albo zakończenie | 0x4A1681 | – | [W] |
| Zakończenie prośby: lista pól, długość +0x48, gotowość +0x4C = 1 | 0x4A26E3 | – | [W] |
| `EEGroupPathRequest` – konstruktor (0x34 B) | 0x5F60E9 | 0x605F60 | [P] kod |
| `EEActiveGroup` vtable +0x34 – aktualizacja: usunięcie martwych, sprawdzenie oczekujących, rozwiązanie pustej grupy | 0x5DF36C | 0x5EFCD7 | [W] |
| `EEActiveGroup` vtable +0x3C – sprawdzenie oczekujących próśb (+0x4C) i zastosowanie | 0x5F7699 | 0x60754E | [W] |
| `EEGroup` vtable +0x38 – zastosowanie trasy: pola → punkty, szyk, punkty na jednostkę | 0x5F6809 | 0x606680 | [W] |
| Punkty jednostki → cele `EEUGLocation` (+0x32 = 1) na początku kolejki | 0x5EDF6B | 0x5FC0A8 | [P] kod (prawie identyczne), pomiar |
| `EEUnitClass` – wejście w „PrepareToMove” (stan 8000) | 0x6222A8 (vtable +0xD0) | 0x63674B (vtable +0xD4) | [P] kod |
| `EEPathManager` – prośba o trasę jednostki | 0x4A1AFF | 0x4A6E88 | [P] kod; AoC jeden argument więcej |
| `EEPathManager` – anulowanie próśb jednostki | 0x4A35AA | 0x4A896B | [W] |
| Maszyny wyszukiwania (RTTI): `EEAIAStarMachine<…PathSector…>`, `<…PathArea…>`, `<…Bounded…>`, `<…Storage, PathfindingGoal…>`, `EEAIAStarGraphMachine` | – | – | nazwy klas [P]; działanie poza zakresem |

## Dane wejściowe i wyjściowe

### Prośba grupy (0x5F670A → 0x4A15E7)

| Dane | Źródło | Pewność |
|---|---|---|
| pole startowe (2 × int) | pierwsza jednostka podgrupy: +0x1C / +0x20 obiektu z listy podgrupy | [W] |
| pole celu (2 × int) | cel grupy (+0x68, vtable +0x28), obcięte do pola | [P] kod |
| jednostki | identyfikatory (+0x24) podgrupy → `EEGroupPathRequest`+0x04 | [P] kod |
| dane gracza / typów | gracz +0x45C, 17 B z listy jednostek (+0x10 …) → prośba +0x1C | [N] znaczenie |
| parametry stałe | 1, −1, 0, 0 | [N] znaczenie |

### `EEAutoPathRequest` (0x50 B)

| Pole | Znaczenie | Pewność |
|---|---|---|
| +0x04 | licznik odwołań | [W] |
| +0x08 (+0x0C…+0x10) | wynik: wektor węzłów po 8 B (x, y – pole mapy) | [W] kod (0x5F69C4, 0x4A26E3) |
| +0x30 / +0x34, +0x38 / +0x3C | pole startowe, pole celu | [P] kod |
| +0x44 | identyfikator prośby (licznik menedżera +0xD0) | [P] kod |
| +0x48 | długość trasy (suma |Δx| + |Δy| między węzłami) | [W] |
| +0x4C | gotowość (1 = wynik dostępny) | [P] kod |

### Zastosowanie (0x5F6809) i zamiana na cele (0x5EDF6B)

1. Węzły trasy od drugiego do przedostatniego (pierwszy to pole startowe, ostatni – pole celu) → środki pól
   (x + 0,5; y + 0,5) [W].
2. Dla każdego punktu układ szyku grupy daje punkt każdej jednostki. Gdy punkt szyku leży w innym obszarze mapy niż
   punkt trasy, jednostka dostaje punkt trasy [W].
3. 0x5EDF6B dla jednostki:
   - wymaga: jednostka żywa (+0x3C > 0), +0x33B = 0, +0x14 ≠ 0;
   - cel bieżący `EEUGLocation` dostaje +0x34 = 3; bez celu wymagany jest stan 5000;
   - gdy na początku kolejki stoi już punkt +0x32 – koniec;
   - pomija do 3 pierwszych punktów leżących przy obszarze jednostki;
   - pozostałe punkty, od ostatniego, zamienia na `EEUGLocation`(punkt, +0x31 = 0, kąt 0, +0x32 = 1, +0x34 = 0) i wstawia
     przez 0x5F05BD(cel, 1, 0) **na początek**. Gdy cel bieżący nie jest celem położenia, wstawia za pierwszym elementem
     (0x5F5B65);
   - bez wstawionych punktów cel bieżący dostaje +0x34 = 4 i jednostka wraca do stanu 8000, o ile nie stoi już na polu
     celu.

   [P: kod; pomiar – +0x34 = 4, dwa punkty na środkach pól]

### Prośba jednostki (0x6222A8 → 0x4A1AFF)

- Punkt celu z celu bieżącego (vtable +8). Jednostka, która stoi dokładnie w punkcie celu, tylko anuluje swoje prośby
  [W].
- Licznik prób: cel +0x18 rośnie przy każdej prośbie. Przy wejściu w stan 8000 jednostka przechodzi do „Idle”, gdy
  +0x18 > vtable +0x2C celu. To limit ponowień [W].
- Gdy cel +0x34 = 1 (świeży zwykły rozkaz), +0x34 := 2 i parametr 0xF, w przeciwnym razie −1 [P: kod; znaczenie N].
- Z pola jednostki (+0x1C, +0x20) do pola celu. Wynik zostaje w danych ruchu jednostki, nie w kolejce celów. Stany
  „GetNextMoveWaypoint”, „RepathAroundObstacle”, zdarzenia „CannotPathToTarget”, „RepathCompleted” – poza zakresem
  [W: nazwy z tablic EXE].

## Przeliczanie, przeszkody, cel nieosiągalny

| Sytuacja | Zachowanie | Pewność |
|---|---|---|
| droga bezpośrednia / krótka | trasa grupowa bez węzłów pośrednich albo pominięte (do 3 punktów przy jednostce) → brak celów +0x32, +0x34 = 4 | [P] pomiar, [W] kod |
| przeszkoda | trasa grupowa z węzłami → cele +0x32 na początku kolejki; obejście lokalne – trasa jednostki | [P] pomiar wstawienia, [W] podział |
| ponowna trasa grupowa przy istniejących punktach | 0x5EDF6B nie dodaje nowych, gdy na początku stoi punkt +0x32 | [W] |
| zmiana rozkazu | zwykły PPM czyści kolejkę razem z punktami; nowa prośba grupowa natychmiast (+0x34 = 4 przy pierwszym odczycie) | [P] |
| za wiele prób (cel +0x18 > limit) | jednostka przechodzi do „Idle” | [W] |
| cel nieosiągalny | zdarzenie „CannotPathToTarget” (8011) istnieje; warunek nieustalony | [N] |

## Obserwacje (zadania MCP 443–454)

Gwardia 0x100018B, scenariusz „Wojna trojańska”, tylko odczyt pamięci. Odczyty: jednostka, poziom 0 kolejki, cele
+0x1F0 i +0x1EC, obiekt stanu, grupa (+0x08…+0x14, +0x68, +0x6C, +0xB5, +0xB6).

| Zadanie | Przypadek | Wynik |
|---|---|---|
| EE 444 | PPM za przeszkodę (A) | 1 cel przez cały ruch (+0x34 = 4), obejście bez celów +0x32 [P] |
| EE 445 | PPM daleko, ok. 20 pól | 1 cel, +0x34 = 4 już 0,3 s po rozkazie [P] |
| EE 448, 451 | PPM A, Shift B; dojście do A | w chwili zdjęcia A: 2 cele +0x32 przed B, indeks 0x1FFE; B ma +0x34 = 0, +0x1D = 1; mapa oczekujących grupy pusta przez cały czas [P] |
| EE 451 | po wstawieniu | pierwszy punkt (179,5; 118,5) zdjęty po ok. 4 s, choć jednostka stała ok. 15 pól od niego; dalej (178,5; 123,5) [P] |
| AoC 453, 454 | to samo | te same dwa punkty w tej samej chwili; po zwykłym PPM tylko nowy cel (+0x34 = 4), nowa grupa (+0xB5 = 0) [P] |
| EE 435 (etap 21) | zwykły PPM przy punktach | punkty usunięte z kolejką [P] |

**Ograniczenia.**
- Stanu przejściowego w obrębie jednego taktu (między prośbą a wstawieniem) nie da się uchwycić odczytem przy pauzie.
  Natychmiastowość wynika z kodu i z +0x34 = 4 przy pierwszym odczycie.
- Nie zaobserwowano punktów +0x32 po zwykłym rozkazie, więc ich wstawienie przy pierwszym celu znane jest tylko z kodu.
- Adres jednostki zmieniał się między uruchomieniami (dwa warianty), co wymusiło dwufazowe zadania. Zadanie 446 czytało
  zły adres i nie zostało wykorzystane.

## Różnice EE ↔ AoC

- Funkcje grupowe (0x5F670A, 0x5F7699, 0x5DF36C) i prośba menedżera (0x4A15E7) są identyczne w porównaniu
  znormalizowanym [P].
- 0x5EDF6B ↔ 0x5FC0A8: inne pole jednostki (+0x33B / +0x347) i drobne różnice kompilacji [P].
- „PrepareToMove”: AoC jest w innym miejscu vtable (+0xD4), testuje inne flagi typu (+0x2D0 & 0xC zamiast +0x5D4 & 4)
  i przekazuje dodatkowy argument do prośby jednostki (0x4A6E88, `ret 0x20`) [P: kod].
- Pomiar: ten sam przebieg i te same punkty w obu grach [P].

## Błędy oryginału

Bez nowego wpisu. Zdjęcie pierwszego punktu trasy daleko przed jego osiągnięciem (EE 451) to obserwacja zachowania,
nie błąd w kodzie. Mechanizm należy do podsystemu ruchu [N]. BO-1–BO-4 bez zmian.

## Nierozpoznane zależności

1. Kto zleca trasę grupową w chwili przejścia do następnego celu Shift. Mapa oczekujących grupy była pusta, a cel B
   zachował +0x34 = 0, więc 0x5EDF6B działał, gdy +0x1F0 nie był celem B [N].
2. Podział na podgrupy 0x5F70A3 (argument 10) i wybór pola startowego podgrupy [N].
3. Maszyny wyszukiwania (sektory, obszary, graf) i znaczenie budżetu (−1, 0xF) – kolejny etap.
4. Gdzie trasa jednostki przechowuje punkty ruchu i kiedy zdejmowane są punkty +0x32 z przodu kolejki [N].
5. Warunek „CannotPathToTarget” i limit prób (cel vtable +0x2C) [N].

## Konsekwencje dla OpenEE (bez zmian w kodzie)

- Dwa poziomy tras:
  - grupowa (pola → cele +0x32 na początku kolejki, z pominięciem do 3 punktów przy jednostce);
  - jednostki (lokalna, poza kolejką celów).
- Prośba o trasę ma działać od razu, z odroczeniem do kolejnych taktów, gdy wyszukiwanie się nie skończy.
- Znaczniki celu +0x34:
  - 1 – świeży rozkaz;
  - 2 – prośba jednostki;
  - 3 – trasa grupowa w trakcie zastosowania;
  - 4 – zastosowana bez punktów.
