# Przydział bliski (stan grupy 8000, cel przy grupie) – Empire Earth / The Art of Conquest

Wpis atlasu Titan, etap 19. Uzupełnia `cele_jednostek.md` (etap 18): tam opisano szyk `EEFShortLine`, wybór ścieżki
i przydział daleki. Tu opisano drugą ścieżkę, czyli przydział jednostek do pozycji szyku, gdy cel leży przy grupie.

Zakres: zwykłe jednostki lądowe → `EEFShortLine` → rozkaz PPM → bez Shift → przydział bliski. Inne szyki, Shift,
trasy, kolizje i ruch w kolejnych taktach są poza zakresem.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pliki: `Empire Earth.exe` (EE) i `EE-AOC.exe` (AoC) z instalacji GOG; SHA-256 jak w `cele_jednostek.md`.

## Wynik w skrócie

1. **Warunek ścieżki.** Ścieżka bliska obowiązuje, gdy cel grupy G leży w prostokącie otaczającym pozycje jednostek
   (z brzegami włącznie) albo gdy E² ≥ D (E – dłuższy bok prostokąta, D – kwadrat odległości G od prostokąta). To
   dopełnienie warunku ścieżki dalekiej z etapu 18 [P: kod; pomiar – 7 rozkazów rozpoznanych jako bliskie].
2. **Kolejność wyboru.** Jednostki wybierają pozycje po kolei. Kolejność to sortowanie rosnąco według trzech
   kryteriów [P: kod i pomiar]:
   - **prędkość** typu (pole typu EE +0x430, AoC +0x134; wartości zgodne z „Speed” w `dbobjects`) – najwolniejsze
     wybierają pierwsze;
   - przy równej prędkości **malejąco „Size of collider”** (EE +0x474, AoC +0x178);
   - przy równych obu – **numer jednostki w grupie**, rosnąco albo malejąco zależnie od flagi kierunku (pkt 3).
3. **Flaga kierunku.** Liczona jest liczba jednostek, dla których kąt między wektorem (pozycja jednostki − G) a osią
   +y mapy wynosi najwyżej π/2, czyli praktycznie jednostek z y ≥ G.y. Gdy ta liczba ≥ obcięcie(n/2), numery rosną,
   w przeciwnym razie maleją [P: kod i pomiar obu wariantów w EE i AoC]. Oś odniesienia to stała oś +y mapy, a nie
   kierunek rozkazu [P: kod; pomiar 402 i 412 odróżnia oba warianty] – podejrzenie **BO-3** (`BLEDY_ORYGINALU.md`).
4. **Koszt przypisania** to kwadrat odległości 3D między pozycją jednostki a pozycją szyku (`GE3DPoint::
   DistanceToSquared`). Wszystkie pozycje szyku mają tę samą wysokość, więc różnica z decyduje tylko o stałej i nie
   zmienia wyboru [P: kod; pomiar – z pozycji jednakowe].
5. **Metoda.** Każda jednostka w ustalonej kolejności bierze najtańszą z jeszcze wolnych pozycji, a ta pozycja znika
   z listy wolnych. Decyzji nie zmienia się później. Brak przeszukiwania kombinacji i brak poprawek [P: kod
   i pomiar – 7 rozkazów, 5 nowych i 2 z etapu 18, zgodnych co do pozycji i numeru].
6. **Remis kosztu.** Wolne pozycje są przeglądane od końca listy i zamiana następuje tylko przy koszcie ściśle
   mniejszym. Przy równym koszcie wygrywa więc pozycja o wyższym numerze [W: kod; niemierzone].
7. **EE ↔ AoC.** Kod ścieżki bliskiej jest identyczny instrukcja po instrukcji (263 instrukcje, te same mnemoniki),
   różnią się tylko adresy, przesunięcia ramki i pola typu (przesunięcie EE − AoC = 0x2FC) [P: kod; pomiar w obu grach].

## Funkcje

| Funkcja | EE | AoC | Uwagi |
|---|---|---|---|
| Ścieżka bliska w obsłudze stanu 8000 | 0x5DC364–0x5DC6B5 | 0x5ECCA1–0x5ECFF2 | koniec: wspólne nadawanie celów (EE 0x5DC6B5, AoC 0x5ECFF2) |
| Rozgałęzienie: G w prostokącie / E² ≥ D | 0x5DBEE9, 0x5DBEFB | 0x5EC84A, 0x5EC85C | prostokąt: 0x5DF4BD (EE), porównania z brzegami włącznie |
| Kąt wektora (pozycja − G) względem osi +y | 0x62D460 | 0x642345 | `GETransformation` domyślna, `GEVector::Normalize`, `UMArcCos` |
| Próg kąta | stała 0x831414 = π/2 (f32) | stała 0x846CF0 = π/2 | – |
| Sortowanie (para numer, jednostka) | 0x5DFBB9 | 0x5F0627 | do 16 elementów przez wstawianie, powyżej – wariant z podziałem i wstawianiem na końcu |
| Porównanie przy sortowaniu | 0x5E0641 | 0x5F109A | prędkość ↑, „Size of collider” ↓, numer ↑/↓ |
| Koszt | import `GE3DPoint::DistanceToSquared` [0xB2FA04] | [0xB53A0C] | `Low-Level Engine.dll` |

## Algorytm

Wejście:
- jednostki grupy w kolejności wektora grupy (+0x24), numery 0…n−1;
- pozycje szyku 0…n−1 (etap 18: kolumny [0, −1, +1, −2, +2]·S, rzędy za celem, obrót o θ);
- G – punkt celu grupy (cel grupy +0x68, vtable +0x28).

Kroki:

1. Lista par (numer, jednostka) dla wszystkich jednostek grupy.
2. Licznik c = 0. Dla każdej jednostki J (pozycja P z vtable +0x5C):
   - v = (P.x − G.x, P.y − G.y, 0), znormalizowany;
   - u = (0, 1, 0) przekształcony domyślną `GETransformation`, też znormalizowany;
   - α = arccos(ogranicz(v·u, −1, 1));
   - gdy α ≤ π/2, c += 1.

   Dalej w funkcji jest zmiana znaku α dla wartości ujemnej, ale arccos nie daje wartości ujemnych, więc ta gałąź
   nigdy nie działa [W].
3. Flaga f = (c ≥ obcięcie(n / 2)).
4. Sortowanie par według porównania „a przed b”:
   - prędkość(a) < prędkość(b), a przy równości:
   - kolizja(a) > kolizja(b), a przy równości:
   - f = 1: numer(a) < numer(b); f = 0: numer(a) > numer(b).

   Klucz jest pełny, bo numery są różne, więc wynik nie zależy od stabilności sortowania [W].
5. Lista wolnych pozycji L = [0, 1, …, n−1].
6. Dla każdej jednostki J w kolejności sortowania:
   - najlepszy koszt = FLT_MAX (0x7F7FFFFF), najlepszy indeks = −1;
   - dla j od |L|−1 do 0: koszt = |P(J) − pozycja L[j]|² (3D); zamiana, gdy koszt < najlepszy albo najlepszy indeks
     = −1;
   - pozycja L[j*] dostaje jednostkę J (pole +0x0C pozycji); L[j*] jest usuwany z listy z zachowaniem kolejności
     pozostałych.
7. Skok do wspólnej części (etap 18 § 4): dla każdej pozycji k jednostka dostaje numer k (EE +0x298, AoC +0x29C),
   własny `EEUGLocation` i stan 8000.

### Struktura kosztu

- Jeden składnik: kwadrat odległości euklidesowej 3D. Bez wag, bez kierunku rozkazu i bez kary za kolejność.
- Pozycje szyku mają z punktu celu (z_lok = 0), a jednostka ma własne z. Składnik (z_J − z_G)² jest stały dla danej
  jednostki, więc nie wpływa na wybór [W: kod; pomiar – wszystkie cele z tą samą wysokością 1,633 albo 1,8371].
- Wysokość mogłaby zmienić tylko remis między różnymi jednostkami, ale jednostki nie konkurują kosztami – kolejność
  ustala sortowanie [W].

### Parametry używane tylko w tej ścieżce

| Parametr | Znaczenie | Pewność |
|---|---|---|
| typ +0x430 (EE) / +0x134 (AoC) | prędkość typu; w pomiarze 0,6 (gwardia), 0,8 (Aleksander), 0,45 (prorok) – jak „Speed” w `dbobjects` EE i AoC | odczyt z pamięci [P]; nazwa pola [W] |
| typ +0x474 / +0x178 | „Size of collider”: 0,5 / 0,55 / 0,5 – jak w `dbobjects` | odczyt [P]; nazwa [W] |
| π/2 (0x831414 / 0x846CF0) | próg kąta przy liczeniu jednostek „na północ” od celu | [P: kod] |
| n/2 (obcięte) | próg flagi kierunku | [P: kod i pomiar] |
| FLT_MAX | wartość początkowa najlepszego kosztu | [P: kod] |

Pole +0x474 występuje też w gałęzi specjalnej przed ścieżkami (etap 18, warunek < 1,0). Tej gałęzi nie analizowano.

## Różnice względem przydziału dalekiego

| Cecha | Daleki (etap 18) | Bliski (etap 19) |
|---|---|---|
| Kiedy | G poza prostokątem jednostek i E² < D | w pozostałych przypadkach |
| Zasada | sortowanie pozycji i jednostek według tego samego klucza, łączenie w pary według rang | jednostki po kolei biorą najbliższą wolną pozycję |
| Kolejność jednostek | klucz położenia poprzecznego k(p) | prędkość ↑, „Size of collider” ↓, numer w grupie ↑/↓ |
| Geometria w koszcie | rzuty na osie od początku mapy z wartością bezwzględną (BO-2) | kwadrat odległości jednostka – pozycja |
| Kąt rozkazu θ | wpływa przez kierunek środek jednostek → środek szyku | wpływa tylko na położenie pozycji; flaga kierunku używa stałej osi +y (BO-3) |
| Typ jednostki | nie wpływa | decyduje o kolejności wyboru |

Ścieżka bliska nie korzysta z klucza k(p), więc nie potwierdza ani nie obala BO-2.

## Jednostki przy celu i jednostki już stojące na pozycjach

- Odległość jednostki od G nie zmienia kolejności. Liczy się tylko przy fladze kierunku (strona względem G) [P: kod].
- Jednostka stojąca na pozycji szyku nie ma pierwszeństwa. Jeśli wolniejsza jednostka wybiera wcześniej i ta pozycja
  jest dla niej najtańsza, zabiera ją. Pomiar EE 405: gwardia 18c stała 0,18 pola od pozycji 5 (koszt 0,031), ale
  prorok (prędkość 0,45) wybierał pierwszy i wziął pozycję 5. Gwardia 18c dostała pozycję 0. Gwardia 18e (najwyższy numer przy f = 0) wybierała pierwsza
  spośród gwardii, choć stała od pozycji najdalej, i wzięła pozycję 1 [P].
- Pomiar EE 408: prorok stał najdalej od wszystkich pozycji, ale jako najwolniejszy dostał pozycję 0 (punkt celu).
  Gwardia 18e, dla której pozycja 0 była najbliższa (0,323), dostała pozycję 1 [P].
- Jednostka stojąca dokładnie w G: wektor zerowy przed normalizacją. Wynik normalizacji i flagi nie był badany [N].

## Weryfikacja

Zadania MCP 398–417, tylko odczyt pamięci, scenariusz „Wojna trojańska”, pauza F3 po rozkazie. Odczytano:
- zaznaczenie z pamięci;
- pozycje jednostek przed rozkazem;
- wektor jednostek grupy (+0x24), czyli numery;
- po rozkazie: numer pozycji (+0x298 / +0x29C) i cel `EEUGLocation` (+0x1F0) każdej jednostki.

Przewidywania liczył model (`bliski.py` w notatkach sesji) z kodu i wartości typów z pamięci, bez dopasowywania do
wyniku. G i θ wzięto z celu pozycji 0, a pozycje szyku z modelu etapu 18. Kolumna „zgodne permutacje” podaje, ile z n!
kolejności wyboru dałoby obserwowany wynik – im mniej, tym mocniejszy test.

| Rozkaz | Jednostki (numer w grupie) | Warunek, flaga | Przewidywanie = pomiar | Zgodne permutacje |
|---|---|---|---|---|
| EE 390 (dane etapu 18) | 18b, 18c, 18d, 18e, 55c, 55d (kolejność zakładana) | bliska, f = 1 (3 z 6) | 18d→0, 55c→1, 18e→2, 18c→3, 55d→4, 18b→5 – **tak** | 26 / 720 |
| AoC 396 (dane etapu 18) | 18e, 55c, 55d | bliska, f = 1 | 55c→0, 55d→1, 18e→2 – **tak** | – |
| EE 402 | 18b 0, 18c 1, 18d 2, 18e 3, 55c 4, 55d 5 | G poza prostokątem, E² ≥ D, f = 1 | 18c→0, 18d→1, 55d→2, 55c→3, 18e→4, 18b→5 – **tak**; model daleki daje inny wynik | 8 / 720 |
| EE 405 | jw. | G w prostokącie, **f = 0** (1 z 6) | 18c→0, 18e→1, 18d→2, 18b→3, 55c→4, 55d→5 – **tak**; numery rosnąco dałyby inny wynik | 30 / 720 |
| EE 408 | 18c 0, 18e 1, 55d 2 (3 jednostki) | bliska, f = 0 | 55d→0, 18e→1, 18c→2 – **tak** | 3 / 6 |
| AoC 412 | 18b 0 … 55d 5 | bliska, **f = 1** (5 z 6) | 18c→0, 18d→1, 55d→2, 18e→3, 55c→4, 18b→5 – **tak**; numery malejąco dałyby inny wynik | 10 / 720 |
| AoC 415 | jw. | G w prostokącie, **f = 0** (1 z 6) | 18d→0, 18c→1, 18e→2, 18b→3, 55c→4, 55d→5 – **tak**; numery rosnąco dałyby inny wynik | 3 / 720 |

Test osi odniesienia flagi: przy osi obróconej o θ (kierunek rozkazu) przewidywanie dla EE 402 i AoC 412 byłoby
niezgodne z pomiarem, a przy stałej osi +y mapy – zgodne. Dla 405 i 415 obie osie dają ten sam wynik [P].

Pozycje szyku z modelu etapu 18 zgadzały się z celami w pamięci co do 2·10⁻⁴ pola we wszystkich nowych rozkazach.
Typy w pamięci EE (389) i AoC (412): gwardia 0,6 / 0,625 / 0,5, Aleksander 0,8 / 0,77 / 0,55, prorok 0,45 / 0,625 /
0,5 (prędkość / „Size in formation” / „Size of collider”).

Dla EE 390 nie odczytano wektora grupy. Przyjęto kolejność gwardii 18b–18e, jak w rozkazach 402–415. Przy
kolejności grupy bez sortowania żaden z rozkazów 402, 405 i 412 nie wychodzi.

**Ograniczenia pomiarów.**
- Zaznaczanie ramką wymagało podania wysokości terenu (z = 1,9). Przy domyślnym z = 0,4 ramka chybiała i zaznaczała
  1–3 jednostki (zadania 399–401; ich rozkazów nie wykorzystano).
- Kliknięcie celu trafiało ok. 0,5–0,8 pola od żądanego punktu. Dlatego G zawsze odczytywano z pamięci, a nie
  z żądania.
- Przypadek 2 jednostek i remis kosztów nie zostały zmierzone. Remis wynika tylko z kodu [W].
- Zaznaczenie zawsze zawierało jednostki dwóch lub trzech typów. Kryterium „Size of collider” przy równej prędkości
  zostało więc potwierdzone tylko kodem [W].

## Błędy oryginału

- **BO-3 (podejrzenie):** flaga kierunku liczona względem stałej osi +y mapy, bo przekształcenie w 0x62D460 jest
  domyślne (tożsamość), a gałąź znaku kąta nie działa. Kierunek numeracji przy remisie typów zależy więc od położenia
  jednostek względem celu na osi północ–południe mapy, a nie od kierunku ruchu. Szczegóły w `BLEDY_ORYGINALU.md`.
- Najwolniejsze jednostki wybierają pierwsze i mogą zabierać pozycje jednostkom, które już na nich stoją, a to
  wydłuża drogi pozostałych. To wygląda na zamierzoną regułę, nie na błąd [H] – bez wpisu.

## Nierozpoznane fragmenty

1. Flaga przy jednostce dokładnie w punkcie G – zachowanie `GEVector::Normalize` dla wektora zerowego [N].
2. Wariant sortowania dla ponad 16 jednostek (EE 0x5E0130) – nie czytano szczegółowo. Wynik nie zależy od niego, bo
   klucz jest pełny [W].
3. Gałąź specjalna przed obiema ścieżkami (+0xB6 grupy, +0x474 typu) – poza zakresem.

## Konsekwencje dla OpenEE (bez zmian w kodzie)

Wierne odtworzenie przydziału bliskiego wymaga:
- warunku ścieżki: G w prostokącie (brzegi włącznie) lub E² ≥ D;
- kolejności wyboru: prędkość rosnąco, „Size of collider” malejąco, numer w grupie rosnąco albo malejąco według
  flagi: liczba jednostek z y ≥ G.y (kąt ≤ π/2 do osi +y mapy) ≥ obcięcie(n/2) – z zachowaniem BO-3;
- wyboru najbliższej wolnej pozycji według kwadratu odległości, z przeglądaniem listy od końca i zamianą tylko przy
  koszcie ściśle mniejszym;
- listy wolnych pozycji, z której usuwa się element z zachowaniem kolejności pozostałych.
