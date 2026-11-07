# Przydział celów jednostkom (stan grupy 8000) – Empire Earth / The Art of Conquest

Etap 18 OpenEE, piąty wpis atlasu funkcji silnika Titan (`docs/titan/README.md`). Kontynuacja `grupy_ruchu.md`: jak
obsługa stanu 8000 zamienia wspólny cel grupy `EEUGLocation` na cele poszczególnych jednostek.

Zakres to najprostsza ścieżka: kilka zwykłych jednostek lądowych, PPM na terenie, bez Shift. Shift, kolejki, samoloty,
okręty, cele inne niż lokacja i wyszukiwanie tras są poza zakresem.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## Wynik w skrócie

1. **Pozycje docelowe wyznacza szyk grupy**, czyli obiekt `EEFormation` wskazywany przez grupę (+0x34). Domyślnie jest
   to **`EEFShortLine`** [P: RTTI w pamięci EE i AoC]:
   - kolumny szyku liczone są przemiennie od środka (środek, lewo, prawo, …), po 5 w rzędzie;
   - rzędy leżą za punktem celu, przeciwnie do kierunku ruchu;
   - odstęp to największe „Size in formation” jednostek grupy;
   - całość jest obrócona o kąt rozkazu i przesunięta do punktu celu [P: kod; pomiar – zgodność do 10⁻⁴ pola].
2. **Przydział jednostek do pozycji (ścieżka „daleka”).** Używany, gdy cel leży poza prostokątem otaczającym jednostki
   i dalej od niego niż dłuższy bok tego prostokąta. Pozycje i jednostki są sortowane według tego samego klucza
   (przesunięcie boczne + 0,1 · przesunięcie wzdłuż kierunku), a potem łączone w pary według kolejności. Jednostki
   zachowują więc swoje ustawienie poprzeczne względem kierunku ruchu [P: kod; pomiar 3 jednostek w EE i AoC – zgodne].
3. **Klucz liczony jest z bezwzględnych współrzędnych świata z wartością bezwzględną.** Zbiory pozycji przecinające
   prostą przez początek układu mapy mogą mieć zaburzone uporządkowanie. Wpisane jako podejrzenie BO-2 [W: kod;
   H: skutek, niemierzony].
4. **Cel jednostki** to nowy `EEUGLocation` z pozycją szyku i kątem szyku. Jednostka dostaje go jako bieżący cel
   (+0x1F0) i stan 8000. Pola jednostki:
   - +0x298 (AoC +0x29C) = numer pozycji;
   - +0x2DC (AoC +0x2E0) = obcięcie(4 · numer / liczba pozycji).

   [P: kod i pomiar]
5. **Ścieżka „bliska”**, gdy cel jest w pobliżu grupy, przydziela jednostki inaczej. Nie analizowano jej [N]. Pozycje
   szyku są w niej te same [P: pomiar 6 jednostek].
6. **EE ↔ AoC:**
   - układ szyku (`EEFLine`) i jego wyliczanie są identyczne;
   - rdzeń przydziału jest zgodny;
   - różnice: przesunięcia pól typu i jednostki, `Unit type` 34 (myśliwiec kosmiczny) traktowany w AoC jak samolot,
     dodatkowe warunki AoC przy nadawaniu celu (flaga typu +0x326, ID 0x41).

   [P: porównanie instrukcji]

## Funkcje

| Funkcja | EE | AoC | Zgodność |
|---|---|---|---|
| Obsługa stanu 8000 (rozdział celu grupy) | 0x5DB641 | 0x5EBF85 | rdzeń zgodny po normalizacji adresów i ramki stosu; różnice opisane niżej |
| `EEFormation` vtable +4 – kopiuje jednostki grupy i woła układ szyku (vtable +8) | 0x4D7E0B | 0x4DDDD5 | identyczne |
| `EEFLine` vtable +8 – układ szyku liniowego (`EEFLine`, `EEFShortLine`, `EEFLongLine`, `EEFLooseLine`, `EEFStaggeredLine`) | 0x4D79D9 | 0x4DD9A3 | identyczne poza polem rozmiaru typu (+0x470 / +0x174) |
| konstruktor bazowy szyku liniowego (przesunięcia kolumn) | 0x4D78E8 | – | – |
| konstruktor `EEFShortLine` (rodzaj 0, odstępy 1,0 / 0,0, 5 kolumn, 5 rzędów) | 0x4D7EE6 | – | – |
| inne układy: koło (`EEFCircle` i odmiany) / klin (`EEFWedge` i odmiany) | 0x4D7235 / 0x4D8079 | – | poza zakresem |
| `GETransformation::SetOrientationYPR`, `Apply` (DLL) | import 0xB30474 / 0xB2F7B4 | – | macierz obrotu, mnożenie M·v |
| sortowanie par (indeks, klucz) – `std::sort` | 0x5DFC79 (wstawianie 0x5E023C) | – | rosnąco po kluczu |
| prostokąt otaczający / punkt prostokąta najbliższy celowi / odległość² / zawieranie | 0x453BAF / 0x5DFAFC / 0x5E045C / 0x5DF4BD | – | – |
| konstruktor celu `EEUGLocation` | 0x614D47 | 0x627742 | identyczne |
| przypisanie celu jednostce (zwykła jednostka lądowa, bez Shift) | 0x5EAE25, 0x5E9664, 0x5F05BD, stan 0x5EFCF0(8000) | – | – |

## Struktury

### Szyk `EEFormation` (grupa +0x34, w EE i AoC domyślnie `EEFShortLine`)

| Pole | Znaczenie | Pewność |
|---|---|---|
| +0x08…+0x44 | macierz obrotu 4×4 (wiersze po 0x10 B): z `SetOrientationYPR(θ, 0, 0)`, wiersz 0 = (cos θ, −sin θ, 0), wiersz 1 = (sin θ, cos θ, 0) | [P] – kod i pamięć (θ = 0,5283 → 0,8637 / 0,5040) |
| +0x48 | punkt celu grupy (x, y, z) | [P] |
| +0x54 | kąt θ (z celu grupy +0x2C) | [P] |
| +0x60 | tablica przesunięć kolumn (w jednostkach odstępu) | [P] |
| +0x64 | odstęp rzędów (`EEFShortLine`: 1,0) | [P] |
| +0x68 | dodatkowe przesunięcie boczne co drugiego rzędu (`EEFShortLine`: 0) | [P] |
| +0x6C | liczba kolumn (5) | [P] – pamięć |
| +0x70 | argument rzędów + 1 (6): co tyle rzędów zostaje pusty rząd | [P] – kod; pamięć 6 |

Przesunięcia kolumn (konstruktor 0x4D78E8):
- dla nieparzystej liczby kolumn: 0, −1, +1, −2, +2, …;
- dla parzystej: ±0,5, ±1,5, …, zawsze najpierw strona ujemna.

Dla 5 kolumn: [0, −1, 1, −2, 2] [P].

### Pozycja szyku (element wektora, 20 B)

| Pole | Znaczenie |
|---|---|
| +0x00 / +0x04 / +0x08 | x, y, z w świecie |
| +0x0C | jednostka: najpierw w kolejności grupy, potem nadpisywana przy przydziale |
| +0x10 | kąt (θ szyku) |

[P – kod układu i przydziału]

### Pola jednostki i typu

| Pole EE / AoC | Znaczenie | Pewność |
|---|---|---|
| jednostka +0x13C / +0x14C | pozycja x / y | [P] |
| jednostka +0x1C8 | grupa | [P] |
| jednostka +0x1F0 | bieżący cel (tu: indywidualny `EEUGLocation`) | [P] – pomiar |
| jednostka +0x298 / +0x29C | numer pozycji w szyku | [P] – pomiar: 0, 1, 2 (3 jednostki), 0–5 (6 jednostek) |
| jednostka +0x2DC / +0x2E0 | obcięcie(4 · numer / liczba pozycji) | [P] – pomiar: 6 jednostek → 0, 0, 1, 2, 2, 3 |
| typ +0x470 / +0x174 | „Size in formation” – odstęp szyku (największy w grupie) | [P] – kod i pomiar: gwardia 0,625, Aleksander 0,77, prorok 0,625 |
| typ +0x474 / +0x178 | druga wielkość typu (maksimum w grupie, warunek ścieżki specjalnej) | [N] znaczenie. [Etap 19: wartości zgodne z „Size of collider”; kryterium sortowania w ścieżce bliskiej – `przydzial_bliski.md`] [Etap 20: maksimum < 1,0 to warunek gałęzi specjalnej – `przydzial_specjalny.md`] |
| typ +0x430 / +0x134 | prędkość typu (wartości zgodne z „Speed”) – kryterium sortowania w ścieżce bliskiej | [Etap 19] odczyt [P], nazwa [W] |

## Algorytm (ścieżka podstawowa)

### 1. Pozycje szyku (`EEFLine` vtable +8)

Wejście: jednostki grupy w kolejności grupy, punkt G (cel grupy), kąt θ.

1. S = największe „Size in formation” wśród jednostek grupy.
2. Dla k = 0…n−1:
   - kolumna c = k mod 5, rząd r (od 0);
   - x_lok = S · przesunięcie[c] (+0x68 w co drugim rzędzie; w `EEFShortLine` 0);
   - y_lok = −r · 1,0 · S, z_lok = 0;
   - pozycja = G + M(θ) · (x_lok, y_lok, 0);
   - po każdym pełnym rzędzie r += 1, a co szósty licznik rzędów (+0x70) dodatkowo pomija jeden rząd.

Oś lokalna +y to kierunek ruchu, czyli M(θ)·(0, 1) = (−sin θ, cos θ). Rzędy leżą więc za celem. Kolumna −1 jest po lewej
stronie kierunku ruchu, +1 po prawej [P: kod; pomiar zgodny co do 10⁻⁴ pola w 4 rozkazach].

Kąt θ pochodzi z `EEMPathTo`+0x10 przez cel grupy. W pomiarach θ ≈ −atan2(Δx, Δy) dla wektora od jednostek do celu.
Dokładny punkt odniesienia w obsłudze kliknięcia nie jest ustalony [W].

### 2. Wybór ścieżki przydziału (0x5DB641)

- Środek pozycji szyku: średnia x, y pozycji.
- Środek jednostek: średnia pozycji jednostek. Prostokąt otaczający jednostki, E = dłuższy bok.
- **Ścieżka daleka**, gdy cel leży poza prostokątem i E² < D, gdzie D to kwadrat odległości celu od punktu prostokąta
  wyznaczonego przez 0x5DFAFC (najbliższy punkt – W) [P: kod].
- W przeciwnym razie ścieżka bliska (0x5DC364) [N]. [Etap 19 – zastąpione: algorytm opisany w § „Przydział bliski — etap 19”
  i w `przydzial_bliski.md`.] Jest też gałąź zależna od +0xB6 grupy i parametrów typu (+0x474) [Etap 20 – rozpoznane: przy rozkazie
  przeciągnięciem PPM pomija oba przydziały – `przydzial_specjalny.md`]
  [N, poza ścieżką podstawową].

### 3. Ścieżka daleka – przydział

1. Kierunek: dx = (środek szyku − środek jednostek)_x, dy′ = (środek jednostek − środek szyku)_y.
   Normalizacja **sumą wartości bezwzględnych**: a = dx / (|dx| + |dy′|), b = dy′ / (|dx| + |dy′|).
2. Klucz punktu p (x, y): **k(p) = |a·y + b·x| + |0,1·b·y − 0,1·a·x|**:
   - pierwszy składnik to rzut na oś poprzeczną do ruchu;
   - drugi to 0,1 rzutu na oś ruchu;
   - oba liczone od początku układu mapy, nie od środków.
3. Lista (indeks pozycji, k) i lista (indeks jednostki, k), każda posortowana rosnąco (`std::sort`; do 16 elementów
   sortowanie przez wstawianie, czyli stabilne).
4. i-ta jednostka w kolejności sortowania dostaje i-tą pozycję (pozycja +0x0C = jednostka).

### 4. Cele jednostek (wspólne dla obu ścieżek)

Dla każdej pozycji k (w kolejności szyku), z przypisaną jednostką J:
1. J+0x298 = k; J+0x2DC = obcięcie(k / n · 4,0) [N: przeznaczenie].
2. Nowy `EEUGLocation`:
   - punkt = pozycja k, kąt = θ;
   - +0x1C = cel grupy +0x1C, +0x30 = +0x30, +0x31 = +0x31;
   - ostatni argument konstruktora +0x34 = 1, w pamięci później 3 albo 4 [N].
3. Bez Shift: +0x1D celu = 1.
4. Zwykła jednostka lądowa (nie lotnisko 0x42, nie typ ruchu +0x4CC = 15):
   - wyczyszczenie kolejki (0x5EAE25, 0x5E9664 z poziomem 0);
   - ustawienie celu (0x5F05BD) – w pomiarze to cel +0x1F0;
   - stan jednostki 8000 (0x5EFCF0);
   - powiadomienie typu (vtable +0x74).
5. Na końcu, bez Shift, grupa vtable +0x44, czyli przejście stanu grupy [N].

Dalej działa ruch jednostki do własnego celu: trasa, A*, kolizje – poza zakresem.

## Weryfikacja

Zadania MCP, tylko odczyt pamięci; po rozkazie pauza F3, żeby zatrzymać stan do odczytu:
- 384–391 (EE) i 392–397 (AoC), scenariusz „Wojna trojańska”;
- sprzątanie: 391, 394, 397.

Przewidywania liczono skryptem modelu (`model.py` w notatkach sesji; algorytm jak wyżej).

| Rozkaz | Jednostki (pozycje przed rozkazem) | Wynik | Zgodność z modelem |
|---|---|---|---|
| EE, 1 obywatel | (182,5; 109,5) | cel jednostki = cel grupy (190,903; 116,927), numer 0, θ = −0,847 | [P] |
| EE, 3 jednostki (gwardia, Aleksander, prorok), ścieżka daleka | (178,557; 125,241), (178,094; 124,911), (177,679; 123,731) | G = (173,5; 128,5), θ = 0,8532, S = 0,77; Aleksander → 0 (173,5; 128,5), prorok → 1 (172,9936; 127,92), gwardia → 2 (174,0064; 129,08) | **pozycje i przydział dokładnie** [P] |
| AoC, te same 3 jednostki | jw. | θ = 0,8527; te same numery, pozycje (172,9934; 127,9201), (174,0066; 129,0799) | **dokładnie** [P] |
| EE, 6 jednostek, ścieżka bliska (cel w pobliżu części jednostek) | 3 gwardie w miejscu, 3 jednostki tuż przy celu | 6 pozycji, w tym jedna w drugim rzędzie (173,2647; 126,4101): **wszystkie pozycje zgodne z modelem**; przydział inny niż model ścieżki dalekiej | pozycje [P]; przydział w ścieżce bliskiej [N] [Etap 19: zgodny z modelem przydziału bliskiego] |
| AoC, 3 jednostki, ścieżka bliska | – | pozycje (178,0203; 123,9346), (177,8182; 124,6776), (178,2224; 123,1916), θ = −1,3053 – zgodne | pozycje [P] |
| +0x2DC (6 jednostek) | – | 0, 0, 1, 2, 2, 3 dla pozycji 0, 1, 2, 3, 4, 5 | [P] |

**Ograniczenia pomiarów.** Zaznaczanie ramką w Riverlands_MCP zaznacza często tylko część jednostek. Zaznaczenie
w pauzie i kliknięciami z Shift nie działało niezawodnie, więc nie udało się uzyskać czystych przypadków 2 i 5 jednostek
w ścieżce dalekiej. Wykorzystano zestawy, które faktycznie zostały zaznaczone (stan zaznaczenia z pamięci): 1, 3 i 6
jednostek. Nowego narzędzia nie budowano.

## Błędy oryginału

- **BO-2 (podejrzenie):** klucz sortowania z wartością bezwzględną rzutów liczonych od początku układu mapy, a nie od
  środków grup. Szczegóły w `BLEDY_ORYGINALU.md`.
- Normalizacja kierunku sumą wartości bezwzględnych zamiast długości tylko skaluje klucz i nie zmienia kolejności.
  Nie jest błędem [W].

## Nierozpoznane fragmenty

1. Ścieżka bliska (0x5DC364…0x5DC6B5) – przydział, gdy cel jest blisko grupy [N]. [Etap 19 – rozpoznane:
   `przydzial_bliski.md`.]
2. Gałąź specjalna (+0xB6 grupy i największe pole typu +0x474 < 1,0 oraz parametr grupy +0x70 > 0,5) [N]. [Etap 20 –
   rozpoznane: `przydzial_specjalny.md`.]
3. Znaczenie J+0x2DC, ostatecznych wartości +0x34 celu jednostki, jednostek z typem ruchu +0x4CC = 15 i lotniska [N].
4. Pochodzenie kąta θ w obsłudze kliknięcia [W]. [Etap 20: `EEUICCommandUnits` 0x64138B – θ = atan2(−Δx, Δy) od środka
   zaznaczenia do punktu kliknięcia, a przy przeciągnięciu z wektora przeciągnięcia – [W]; `przydzial_specjalny.md`.]
5. Szyki inne niż `EEFShortLine` (koło, klin, odmiany linii) – konstruktory i układy znane z adresów, nieanalizowane.
6. Różnice AoC przy nadawaniu celu (flaga typu +0x326, ID 0x41, `Unit type` 34) – zakres [P], znaczenie [N].

## Konsekwencje dla OpenEE (bez zmian w kodzie)

- `FormacjaEE` z etapu 9 (siatka 5 kolumn, pierwszy rząd w punkcie celu, odstęp „Size in formation”) zgadza się co do
  idei. Wierne odtworzenie wymaga szczegółów:
  - kolejność kolumn: środek, lewo, prawo, …;
  - rzędy za celem;
  - odstęp = największy rozmiar w grupie;
  - obrót o θ;
  - pusty rząd co 5 rzędów.
- Przydział w ścieżce dalekiej: sortowanie pozycji i jednostek według klucza k(p) i łączenie w pary według kolejności,
  z zachowaniem podejrzenia BO-2.
- Ścieżka bliska wymaga osobnej analizy. [Etap 19 – zastąpione: patrz niżej.]

## Przydział bliski — etap 19

Szczegóły, adresy, weryfikacja i poziomy pewności: **`przydzial_bliski.md`**. W skrócie:
- **Kiedy:** cel G w prostokącie jednostek (z brzegami włącznie) albo E² ≥ D, czyli gdy nie zachodzi warunek ścieżki
  dalekiej [P].
- **Metoda:** jednostki po kolei biorą najbliższą wolną pozycję szyku według kwadratu odległości (`GE3DPoint::
  DistanceToSquared`). Wybrana pozycja wypada z listy, a decyzji nie zmienia się później [P].
- **Kolejność:** prędkość typu rosnąco (EE +0x430, AoC +0x134), potem „Size of collider” malejąco (+0x474 / +0x178),
  potem numer w grupie – rosnąco, gdy co najmniej połowa jednostek (obcięcie n/2) ma kąt ≤ π/2 do osi +y mapy względem
  G, w przeciwnym razie malejąco [P].
- **Remis kosztu:** wygrywa pozycja o wyższym numerze (przegląd od końca, zamiana tylko przy koszcie ściśle mniejszym)
  [W].
- **EE ↔ AoC:** kod identyczny (EE 0x5DC364–0x5DC6B5, AoC 0x5ECCA1–0x5ECFF2) [P].
- **Pomiar:** 7 rozkazów, w tym 2 z etapu 18 (EE i AoC, 3 i 6 jednostek, obie wartości flagi) zgodnych z przewidywaniem co do numeru
  pozycji każdej jednostki [P].
- **Błąd oryginału:** BO-3 (podejrzenie) – flaga kierunku liczona względem stałej osi +y mapy, nie kierunku ruchu.

## Gałąź specjalna — etap 20

Szczegóły: **`przydzial_specjalny.md`**. Przed wyborem ścieżki bliskiej albo dalekiej obsługa stanu 8000 sprawdza
kolejno:
- grupa +0xB6 ≠ 0 – „ruch w szyku”, ustawiane przy rozkazie PPM wydanym przeciągnięciem;
- największe „Size of collider” < 1,0;
- grupa +0x70 (średnia prędkość, ograniczona do 2 · minimum) > 0,5.

Gdy wszystkie są spełnione, skacze wprost do wspólnego nadawania celów. Jednostka k grupy dostaje wtedy pozycję k,
zapisaną już przez układ szyku, bez przydziału bliskiego i dalekiego [P: kod i pomiar EE 419, AoC 423; kontrola
EE 420 z +0x70 = 0,5]. Geometria szyku i nadawanie celów się nie zmieniają. EE i AoC działają tak samo.
