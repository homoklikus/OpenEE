# A* po polach mapy – wyszukiwanie i koszty (Empire Earth / The Art of Conquest)

Wpis atlasu Titan, etap 24. Opisuje wnętrze maszyny `EEAIAStarMachine<EEAIAStarStorage, EEAIAStarPathfindingGoal,
EEMap>`:
- listy węzłów;
- pętlę;
- koszty, heurystykę i porównania;
- sąsiadów i dostępność pól;
- remisy i limity.

Wybór końca trasy, przekazanie trasy jednostce, wynik częściowy, porażkę i szybką próbę `Bounded` opisuje
**`astar_wyniki.md`**. Miejsce maszyny w podsystemie tras opisuje `architektura_nawigacji.md`.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem (trasy z pamięci gry zgodne z niezależnym modelem);
- **[W]** wniosek z przeczytanego kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Adresy: EE `Empire Earth.exe` (e352d7ae…), AoC `EE-AOC.exe` (db8fc5ce…).

## 1. Wynik w skrócie

1. **Koszty i heurystyka są całkowite** [P].
   - Krok poziomy lub pionowy kosztuje 10, krok po przekątnej 14.
   - Heurystyka H = 10 · (|dx| + |dy|): odległość Manhattan razy 10, liczona do pola celu.
   - F = G + H, bez wag i bez liczb zmiennoprzecinkowych.
   - Heurystyka przecenia drogę po przekątnej (14 < 20), więc A* nie jest dopuszczalny. Trasa zaczyna się od kroków
     po przekątnej, a kończy krokami prostymi.
2. **Na koszt nie wpływają teren, wysokość ani nachylenie** [W: kod]. Teren decyduje tylko o dostępności pola.
   Do kosztu dochodzą jedynie:
   - kary za jednostki stojące na polu docelowym kroku (+50 albo +150);
   - podwojenie kosztu dla dużych jednostek (rozmiar kolizji ≥ 1,0) przy przeszkodach w sąsiedztwie.
3. **8 sąsiadów w stałej kolejności** [P]. Najpierw (x, y−1), (x−1, y), (x+1, y), (x, y+1), potem przekątne (x−1, y−1),
   (x+1, y−1), (x+1, y+1), (x−1, y+1).
   - Przekątna jest dozwolona, gdy przynajmniej jedno z dwóch sąsiednich pól prostych jest dostępne. Można więc ścinać
     narożnik pojedynczej przeszkody, ale nie przejść między dwiema stykającymi się po przekątnej.
4. **Lista otwarta ma dwa poziomy** [W: kod; P: zgodność tras].
   - Posortowana lista dwukierunkowa przechowuje węzły o F nie większym niż F ostatniego elementu.
   - Pozostałe węzły trafiają do tablicy mieszającej o 53 kubełkach.
   - Gdy lista się opróżni, z tablicy wybieranych jest do 15 węzłów o najmniejszym F i wstawianych do listy.
   - Przy równym F nowy węzeł staje **przed** starszymi, więc remisy rozstrzyga kolejność LIFO.
5. **Lista zamknięta** to tablica mieszająca o 53 kubełkach z wstawianiem na początek. Węzeł zamknięty z gorszym G
   można ponownie otworzyć [W].
6. **Limity** liczy się w iteracjach, czyli zdjęciach węzła z listy (szczegóły w `architektura_nawigacji.md` § 6).
   Zmierzone liczby iteracji i wywołań zgadzają się z modelem co do jednej iteracji [P].
7. **EE i AoC.** Pętla, listy, sąsiedzi, heurystyka i odtwarzanie trasy są identyczne [P: kod; pomiar AoC].
   AoC sprawdza dostępność terenu metodą typu jednostki zamiast tablicy bajtów i ma przesunięte pola typu.

## 2. Funkcje

| Funkcja | EE | AoC | Pewność |
|---|---|---|---|
| uruchom (inicjalizacja albo wznowienie) | 0x4A4FE1 (vtable +0x20) | 0x4AA4E5 | [P] kod |
| węzeł startowy | 0x4A53B0 | 0x4AA915 | [P] kod |
| pętla | 0x4A5428 | 0x4AA98D | [P] kod, identyczne |
| dodanie lub poprawa sąsiada | 0x4A5E13 | 0x4AB504 | [P] kod, identyczne |
| dostępność pola z pamięcią podręczną | 0x4A5EF5 | 0x4AB5E6 | [P] |
| dostępność pola (cel → mapa) | 0x41D4A0 → 0x412F15 → 0x41D36A | 0x4199FA → … → 0x41990C | [W]; AoC: test terenu przez metodę typu |
| koszt kroku | 0x41CFFF (cel vtable przez 0x4A64B5) | 0x40EE51 | [W]; AoC: inne przesunięcia pól |
| heurystyka węzła startowego | 0x4A648D | 0x4AB2BD | [P] |
| test celu | 0x41CCA8 | 0x4191D1 | [P] kod |
| koniec wyszukiwania (cel vtable +8) | 0x41CC0F | 0x40EA7B | [W] |
| lista otwarta: wstaw, zdejmij najlepszy, przestaw | 0x41F876, 0x420030, 0x41FC4E | 0x41BAAE, 0x41C268, 0x41BE86 | [P] kod, identyczne |
| wstawienie do listy przy uzupełnianiu | 0x420385 | 0x41C5BD | [P] |
| lista zamknięta: dodaj, usuń | 0x41F80B, 0x4201E8 | 0x41BA43, – | [W] |
| szukaj w otwartej / zamkniętej | 0x41F981 / 0x41F92C | – | [W] |
| nowy węzeł (wspólna pula wolnych węzłów 0x8CF564), zwolnienie | 0x41FA30, 0x41F863 | (inny adres puli) | [W] |
| przygotowanie pamięci (siatka znaczników, czyszczenie prostokąta) | 0x41FBEF, 0x420259 | – | [W] |

## 3. Struktury

### Węzeł (0x20 B, pula wolnych węzłów pod EE 0x8CF564)

| Pole | Znaczenie |
|---|---|
| +0x00 | poprzednik (węzeł, z którego przyszło najlepsze G) |
| +0x04 / +0x08 | następny / poprzedni na liście (otwartej, zamkniętej albo w kubełku) |
| +0x0C | F = G + H (uint32) |
| +0x10 | G (uint32) |
| +0x14 | H (uint32) |
| +0x18 / +0x1C | x / y pola |

### Pamięć wyszukiwania `EEAIAStarStorage` (maszyna +0x20)

| Pole | Znaczenie |
|---|---|
| +0x04…+0x10 | prostokąt pól dotkniętych w wyszukiwaniu (ymax, xmin, xmax, ymin), czyszczony przy następnym starcie (z marginesem 2) |
| +0x14 | kubełki listy zamkniętej (53) |
| +0x18 | kubełki części mieszanej listy otwartej (53) |
| +0x24 / +0x28 | początek i koniec posortowanej części listy otwartej |
| +0x2C | węzeł końcowy, od którego odtwarza się trasę (maszyna +0x4C) |
| +0x34 | węzeł bieżący (maszyna +0x54) |
| +0x38, +0x3C | siatka bajtów W × H, indeks x·W + y. Bity: 1 – pole dostępne, 2 – niedostępne (pamięć podręczna), 4 – w otwartej, 8 – w zamkniętej |
| +0x44 | liczba kubełków = 53 (stała z konstruktora 0x41F77F) |

Kubełek węzła to ((x << 4) + y) mod 53, liczone z dzieleniem ze znakiem. Gałąź dla h ≥ 2^28 traci młodsze bity (fragment
haszu ELF), ale przy mapach do 280 pól nigdy się nie wykonuje [W].

### Maszyna pól (0x11C B) – pola używane przez pętlę

| Pole | Znaczenie |
|---|---|
| +0x04 / +0x08 | pole celu. Po wyniku częściowym nadpisywane polem końca trasy |
| +0x0C | klucz (1 ląd, 2 morze, AoC 0x10 kosmos) |
| +0x10 / +0x14 / +0x18 | iteracje łącznie / liczba wywołań pętli / iteracje w bieżącym wywołaniu |
| +0x1C | reguła narożników (1 = przekątna wymaga wolnego pola prostego). Prośba jednostki zawsze ustawia 1 |
| +0x1D | zawieszona |
| +0x4C / +0x54 | węzeł końcowy / bieżący |
| +0x6C | cel `EEAIAStarPathfindingGoal`: +0x0C/+0x10 pole celu, +0x20 limit na wywołanie, +0x24 limit całkowity, +0x28 flaga „szukaj najbliższego”, +0x2A, +0x2D (§ `astar_wyniki.md`), +0x8C jednostka, +0x90 modyfikator (morze), +0x98/+0x9C przesunięcie punktu (0,5; 0,5), +0xA0 obszar jednostki |
| +0x110 | `EEMap` |
| +0x114 / +0x118 | szerokość i wysokość mapy (kopia z `EEMap`+0x1816FC) |

## 4. Pętla (pseudokod)

Pseudokod opisuje kod EE 0x4A4FE1, 0x4A53B0, 0x4A5428 i 0x4A5E13 własnymi słowami.

```
uruchom():
  jeśli nie zawieszona:
     iteracje = 0; wywołania = 0
     pamięć.przygotuj(W, H); cel.przygotuj()
     dostępne(start)                         # tylko wpis do pamięci podręcznej
     cel_pola = (+0x78, +0x7C)
     n0 = węzeł(start); n0.G = 0; n0.H = 10·manhattan(start, cel_pola); n0.F = n0.H
     otwarta.wstaw(n0)
  pętla()

pętla():
  w_wywołaniu = 0; wywołania += 1; iteracje += 1
  bieżący = otwarta.zdejmij_najlepszy()      # None, gdy pusta
  powtarzaj:
     jeśli test_celu(bieżący): zakończ(); wróć
     (x, y) = bieżący; (px, py) = poprzednik albo (0, 0)
     N = dostępne(x, y−1); Wd = dostępne(x−1, y); E = dostępne(x+1, y); S = dostępne(x, y+1)
     dla (warunek, pole) w [(N,(x,y−1)), (Wd,(x−1,y)), (E,(x+1,y)), (S,(x,y+1))]:
        jeśli warunek i pole ≠ (px, py): dodaj(bieżący, pole)
     jeśli reguła_narożników:
        przekątne = [(Wd or N,(x−1,y−1)), (N or E,(x+1,y−1)), (E or S,(x+1,y+1)), (S or Wd,(x−1,y+1))]
     inaczej:
        przekątne = te same pola bez warunku            # w prośbach jednostek nie występuje
     dla (warunek, pole) w przekątne:
        jeśli warunek i pole ≠ (px, py) i dostępne(pole): dodaj(bieżący, pole)
     zamknięta.dodaj(bieżący)
     jeśli limit_wywołania ≠ −1 i w_wywołaniu ≥ limit_wywołania: zawieszona = 1; bieżący = None; wróć
     jeśli limit_całkowity ≠ −1 i iteracje ≥ limit_całkowity: bieżący = None; zawieszona = 0; zakończ(); wróć
     w_wywołaniu += 1; iteracje += 1
     bieżący = otwarta.zdejmij_najlepszy()

dodaj(p, (x, y)):
  g = p.G + koszt(p, (x, y))
  o = otwarta.szukaj(x, y); z = zamknięta.szukaj(x, y)
  jeśli o i o.G ≤ g: wróć                    # porównania bez znaku
  jeśli z:
     jeśli z.G ≤ g: wróć
     zamknięta.usuń(z); zwolnij(z)           # ponowne otwarcie
  jeśli o = None:
     n = węzeł(x, y); n.poprzednik = p; n.G = g
     n.H = 10·(|x − cel.x| + |y − cel.y|); n.F = n.G + n.H; otwarta.wstaw(n)
  inaczej:
     o.G = g; o.poprzednik = p
     jeśli o.F ≠ g + o.H: o.F = g + o.H; otwarta.przestaw(o)
```

- **Licznik iteracji.** Rośnie przy każdym zdjęciu węzła, także pierwszym w wywołaniu i także wtedy, gdy zdjęty węzeł
  spełnia test celu. Zawieszenie następuje po rozwinięciu węzła, więc wywołanie z limitem L rozwija L + 1 węzłów.
- **Kolejność zamykania.** Węzeł bieżący trafia do zamkniętej **po** rozwinięciu sąsiadów. W czasie rozwijania nie
  jest ani w otwartej, ani w zamkniętej. Pomijanie poprzednika chroni tylko przed powrotem o jeden krok [W].
- **Wznowienie.** Zawieszona maszyna przy następnym „uruchom” pomija inicjalizację i zaczyna od nowego zdjęcia węzła.
  Stan list jest nietknięty, więc kolejność rozwijania nie zależy od podziału na wywołania [W; P: zgodne liczby
  wywołań].

## 5. Lista otwarta i remisy

**Wstawianie (0x41F876).**
- Gdy posortowana lista nie jest pusta i F węzła ≤ F ostatniego elementu, węzeł trafia do listy przed pierwszy
  element o F ≥ F węzła.
- W przeciwnym razie (F większe od ostatniego albo lista pusta) trafia na początek kubełku ((x << 4) + y) mod 53.

**Zdjęcie (0x420030).**
1. Jeśli posortowana lista jest pusta, przegląda kubełki od 52 do 0, w każdym od początku łańcucha:
   - pierwszych 15 węzłów trafia do tablicy roboczej. Indeks „najgorszego” przesuwa się na nowy węzeł, gdy jego F ≥ F
     dotychczasowego najgorszego;
   - każdy dalszy węzeł o F < F najgorszego zastępuje najgorszego. Nowy najgorszy to pierwszy indeks z największym F.
   - Wybrane węzły (do 15) wstawia od ostatniego indeksu do pierwszego regułą „przed pierwszy element o F ≥” (0x420385).
2. Zdejmuje pierwszy element listy.

**Wniosek.** Zawsze zdejmowany jest węzeł o globalnie najmniejszym F, bo węzły w kubełkach mają F większe od
każdego elementu listy [W]. Przy równym F decyduje kolejność:
- wśród węzłów dodanych wprost do listy – ostatnio dodany (LIFO), czyli w obrębie jednego rozwinięcia ostatni z
  kolejności sąsiadów;
- wśród węzłów z kubełków – kolejność przeglądania kubełków i reguły tablicy roboczej.

Kryterium G ani H nie jest stosowane.

**Przestawienie (0x41FC4E)** po poprawie G: węzeł wyjmuje się z listy albo kubełka i wstawia ponownie według tych
samych reguł.

**Trasy o równym koszcie.** Heurystyka 10·Manhattan razy krok przekątny 14 sprawia, że F maleje wzdłuż przekątnej.
Wynik:
- trasa wybiera przekątne na początku, proste na końcu (pomiar A, B, E);
- przy przeszkodach wybór jednej z równoważnych dróg zależy od kolejności wstawiania i od tego, czy węzeł trafił do
  listy, czy do kubełka.

Model musi więc odtwarzać obie struktury, a nie tylko „najmniejsze F” [P: zgodność 36-punktowej trasy E z modelem].

## 6. Koszt kroku (0x41CFFF)

Koszt kroku z pola (fx, fy) na pole (tx, ty):
1. Wartość bazowa: 10, gdy fx = tx albo fy = ty, w przeciwnym razie 14.
2. Gdy pole docelowe kroku jest polem celu, wynik to wartość bazowa (koniec).
3. Dla każdego obiektu na liście pola (`EEMap` komórka +8 → węzeł +4 → rekord +0x30 = jednostka) dodawana jest kara,
   pod warunkiem że jednostka:
   - nie jest jednostką szukającą;
   - ma typ z +0x606 ≠ 0;
   - nie jest wyłączona (vtable +0x58);
   - nie jest jednostką tej samej grupy (+0x1C8) o rozmiarze kolizji (+0x244) < 1,0 – mała jednostka własnej grupy
     jest pomijana, duża nie;
   - ma bieżący cel w stanie 5000 albo 2001.

   Wysokość kary:
   - +50, gdy rozmiar kolizji przeszkody (+0x244) < 1,0;
   - +150, gdy rozmiar przeszkody ≥ 1,0, a rozmiar kolizji szukającego (typ +0x474) < 1,0;
   - +50 w pozostałych przypadkach.

   [W: kod]. **Poprawka (eksperyment Fable 2):** pole jednostki +0x244 to rozmiar kolizji, nie prędkość [P: próbki
   surowe – taran 1,0, gwardia 0,5]; wcześniejszy opis mówił o prędkości. Kara +50 jest **zmierzona** w EE i AoC:
   trasa z A\* objeżdża stojącą gwardię, stojący taran i dom o jedno pole (10 + 50 + 10 = 70 wobec 14 + 14 = 28),
   a jednostki w ruchu nie są omijane [P: `EKSPERYMENT_FABLE_DUZE_JEDNOSTKI.md` § 4]. Odpowiednik AoC: 0x419595
   [W: ten sam układ instrukcji i stałych]. Kara +150 i pominięcie własnej grupy – bez pomiaru.
4. **Duże jednostki.** Szukający o rozmiarze kolizji (typ +0x474) ≥ 1,0, z niezerowym polem +0x2DC i typem +0x617 = 0,
   sprawdza 4 pola wokół celu kroku (kierunki 4, 3, 1, 6 z 0x632E7C). Koszt jest podwajany, gdy któreś z tych pól:
   - jest zajęte (komórka +0x14);
   - ma teren niedostępny;
   - leży w innym obszarze (siatka obszarów `EEAIContinentManager`) niż jednostka (cel +0xA0).

   Pole poza mapą nie podwaja kosztu [W].
5. Modyfikator morski albo kosmiczny zastępuje funkcję kosztu i dostępności (cel +0x90, vtable +4 / +8) – poza
   zakresem.

**Czego nie ma** [W: kod]: kosztu rodzaju terenu, wysokości, nachylenia, odległości euklidesowej, zaokrągleń
zmiennoprzecinkowych w G.

## 7. Dostępność pola

**Siatka pamięci podręcznej (0x4A5EF5).**
- Pole spoza 0 ≤ x < W, 0 ≤ y < H (porównanie bez znaku) jest niedostępne.
- Wynik zapamiętuje się w siatce (bit 1 albo 2) do końca wyszukiwania, także między zawieszeniami.
- Zmiana mapy w czasie zawieszenia nie zmienia już ocenionych pól [W].

**Test pola (0x41D36A)** dla komórki `EEMap` ((y·W + x) w tablicy +0x1816D4). Pole jest niedostępne, gdy spełniony
jest którykolwiek z warunków:
1. Pole leży na brzegu rombu mapy: x + y = `EEMap`+0x1816EC albo +0x1816F0 albo |y − x| = +0x1816F4 (pomiar: 139,
   419, 140). Liczy się **tylko równość**. Przejście po przekątnej przez linię brzegu blokuje reguła narożników, bo oba
   pola proste leżą na linii [W].
2. Teren nie jest dozwolony dla typu: bajt typu +0x5D6 + teren komórki (+4) jest równy 0. AoC wywołuje tu metodę typu.
3. Któryś obiekt z listy komórki (+8) w vtable +0x48(jednostka) zwraca fałsz.
   - `EEUnit` (drzewa, złoża): blokuje przy typie +0x600 ≠ 0, chyba że jest martwy, a typ +0x4B4 ≠ 1. Przy typie
     +0x568 = 3 przechodzą jednostki z typem +0x617 ≠ 0.
   - `EEComplexUnit`: blokuje przy +0x600 ≠ 0 i żywym obiekcie. Brama (typ +0x4B4 = 25) ma osobny warunek (stan,
     sojusz) i w pomiarze była przechodnia dla własnej jednostki [P].
   - Inne jednostki (typ +0x600 = 0) nie blokują pola, tylko podnoszą koszt (§ 6).

**Rozmiar jednostki** nie zmienia dostępności, tylko koszt (§ 6 pkt 4).

**Woda i ląd.**
- Jednostka lądowa: woda (teren 1) i teren 10 są niedostępne według tablicy typu `EEUCLand` (pomiar tablicy).
  **[Etap 30 – zastąpione]** Odczyt tablicy +0x5D6 gwardii i Aleksandra (zad. 552): `1,0,1,1,1,1,1,1,1,0,1,1,…` –
  niedostępne są **1 (woda głęboka) i 9 (klif)**; 10 to woda płytka i jest dostępna [P]. Wartości terenu komórek
  (EETile+4) i reguła ich wyprowadzenia z SCN: `import_mapy.md` § 3.
- Jednostka morska używa klucza 2 i modyfikatora morskiego.

**Test celu (0x41CCA8).**
- Brak węzła oznacza pustą otwartą – wynik prawdziwy.
- Węzeł dalej niż 1 pole od celu w którejś osi – fałsz.
- Węzeł na polu celu – prawda.
- Węzeł przy celu:
  - cel dostępny – fałsz (trzeba wejść na cel);
  - cel niedostępny – prawda przy sąsiedztwie prostym; przy sąsiedztwie po przekątnej (z regułą narożników) prawda
    tylko wtedy, gdy oba pola proste między węzłem a celem są dostępne.

## 8. Weryfikacja

Pomiary (zadania MCP 464–488) i porównanie z modelem: `astar_wyniki.md` § 7–8. Najważniejsze:

| Przypadek | Wynik |
|---|---|
| B: (176,125) → (180,118) | trasa 6 kroków identyczna z modelem; 8 iteracji maszyny `Bounded` = model (brama przechodnia) [P] |
| C: (180,118) → (180,123) | 6 iteracji, trasa identyczna [P] |
| E: (180,122) → (150,115), 36 pól | trasa identyczna punkt po punkcie, w tym 4 ścięcia narożnika i zygzak (154,117)–(153,116); **145 iteracji w 8 wywołaniach = model** [P] |
| AoC: A i E | trasa A bit w bit jak w EE; trasa E zgodna z modelem z danych mapy EE [P] |

## 9. Nierozpoznane

1. Lista storage +0x20 i +0x1C, przeglądana przy szukaniu najbliższego węzła – w tej maszynie zawsze pusta? [N]
2. Pełny warunek bramy (stan 15001, sojusz, 0x414BEA) [N].
3. Podwojenie kosztu dla szukającego ≥ 1,0 i kara +150 nie zostały zmierzone [N]. Kara +50 za stojącą jednostkę –
   zmierzona w eksperymencie Fable 2 (§ 6) [P]. [Zastąpione: „kary za jednostki nie zostały zmierzone”.]
4. Kierunki 0x632E7C (numeracja 1, 3, 4, 6) [N].
