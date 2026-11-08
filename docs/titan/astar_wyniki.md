# A* po polach – trasa wynikowa, wynik częściowy, `Bounded` (Empire Earth / The Art of Conquest)

Wpis atlasu Titan, etap 24, druga część. Opisuje:
- koniec wyszukiwania i wybór węzła końcowego;
- odtwarzanie trasy;
- przekazanie trasy jednostce;
- szybką próbę `Bounded`;
- weryfikację.

Pętlę i koszty opisuje `astar_pola.md`.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Wynik w skrócie

1. **Koniec wyszukiwania** ustawia flagę celu +0x28 (maszyna +0x94) „szukaj najbliższego”, gdy [W: kod]:
   - lista otwarta jest pusta (brak drogi);
   - węzeł końcowy stoi przy niedostępnym celu;
   - liczba iteracji osiągnęła limit całkowity.

   Wtedy końcem trasy jest **najbliższy dostępny węzeł** według |dx| + |dy| do celu (0x4A5D16 → 0x4A6339). W
   przeciwnym razie końcem jest węzeł, który spełnił test celu.
2. **Trasa** to łańcuch poprzedników od końca do startu.
   - Każde pole zamienia się na punkt (x + 0,5; y + 0,5; 0).
   - Bez usuwania punktów, upraszczania odcinków, wygładzania i testów widoczności [P: punkty co jedno pole, zgodne z
     modelem].
3. **Jednostka dostaje punkty od startu do celu**, bez pola startowego, gdy jednostka na nim stoi.
   - Punkty trafiają do kolejki dwustronnej jednostki +0x7C (liczba +0x8C), elementy po 20 B: x, y, z, długość
     narastająca, długość poprzednia [P].
   - Ostatni punkt zastępuje dokładne położenie celu z rozkazu, z wysokością terenu (np. (180,72; 123,88; 1,63)) [P].
4. **`Bounded`** to krótkie A* w kwadracie wokół startu, z limitem kilkunastu iteracji.
   - Gdy dojdzie do celu, pełne A* się nie odbywa.
   - Gdy nie dojdzie, jednostka od razu dostaje trasę do najbliższego punktu, a pełne A* startuje z tego punktu [P: E].
5. **„Brak drogi” i „brak ukończonego wyniku” kończą się tak samo.** Trasa prowadzi do najbliższego dostępnego węzła.
   Różnią się tylko przyczyną ustawienia flagi +0x28. Kod nie zgłasza tu osobnego zdarzenia [W]. Związku z
   „CannotPathToTarget” nie ustalono [N].

## 2. Koniec wyszukiwania (cel vtable +8 = EE 0x41CC0F)

| Sytuacja | +0x28 | Pewność |
|---|---|---|
| węzeł bieżący pusty i cała lista otwarta pusta | 1 – „brak drogi” | [W] |
| węzeł bieżący przy celu (\|dx\|, \|dy\| ≤ 1), cel niedostępny | 1; przy okazji +0x2D := +0x2A | [W] |
| w pozostałych przypadkach | iteracje ≥ limit całkowity (porównanie ze znakiem) | [W] |

Przy limicie −1 („bez limitu”) porównanie iteracje ≥ −1 jest zawsze prawdziwe, więc wybór najbliższego węzła działa
zawsze. Prośby jednostek zawsze mają dodatni limit, więc nie ma to skutku (BO-5, obserwacja) [W].

## 3. Wybór końca trasy (EE 0x4A5D16, AoC 0x4AB407)

1. Węzeł bieżący, jeśli istnieje, trafia do listy zamkniętej.
2. **Najbliższy węzeł (0x4A6339):**
   - w otwartej (0x41FE7E) i w zamkniętej (0x41FD53) wyszukuje węzeł o najmniejszym |dx| + |dy| do celu, a przy remisie
     pierwszy w kolejności przeglądania: lista, potem kubełki od 52 do 0;
   - z tych dwóch wybiera ten o mniejszym F. Przy równym F wygrywa węzeł z otwartej;
   - przegrany wraca na swoją listę.
3. Cel z +0x2A = 0 (maszyna pól): wybrany węzeł musi być dostępny. Węzeł niedostępny jest usuwany i wybór się
   powtarza. Przy braku węzłów końcem jest nowy węzeł startowy (G = 0, F = H = 1) – trasa długości 1.
4. Cel z +0x2A = 1 (`Bounded`): wybrany węzeł bez testu dostępności.
5. Pole celu maszyny (+4, +8) zostaje nadpisane polem końca. Prośba jednostki przekazuje je dalej (§ 5).

Przy zwykłym dojściu do dostępnego celu najbliższym węzłem jest sam węzeł celu (odległość 0). Przy celu niedostępnym
wybierany jest węzeł sąsiedni o najmniejszym |dx| + |dy|, czyli prosty sąsiad celu, jeśli został odkryty. Może to być
inny węzeł niż ten, który spełnił test celu [W].

## 4. Odtworzenie trasy (cel 0x41CE5F, AoC 0x419388)

- Kursor zaczyna od węzła końcowego (pamięć +0x2C, maszyna +0x4C) i idzie po poprzednikach do węzła startowego
  włącznie.
- Każde pole dopisywane jest do wektora jako (x + cel+0x98, y + cel+0x9C, 0,0). Przesunięcia to 0,5 (0x41D67E).
- Kolejność w wektorze: od końca do startu. Przy końcu równym startowi wektor ma jeden punkt.

Wariant 0x41CF00 dopisuje też wszystkie węzły otwarte i zamknięte (narzędzie diagnostyczne?) [N].

## 5. Przekazanie jednostce

| Krok | EE | AoC | Opis | Pewność |
|---|---|---|---|---|
| koniec prośby | 0x4A327E | 0x4A86CB | maszyna pól (+0x96 = cel+0x2A = 0) → zawsze 0x4A2B29; `Bounded`: +0xAA = 1, więc przy +0xAD = 0 → 0x4A32C0, inaczej 0x4A2B29 | [W] |
| przekazanie bezpośrednie | 0x4A32C0 | 0x4A870D | wektor → 0x5EE4E6(jednostka, wektor, 0); jednostka +0x33E = 1; wyczyszczenie +0x194; 0x5EE3D2 | [W] |
| przekazanie z łączeniem | 0x4A2B29 | 0x4A7F4A | patrz niżej | [W] |
| łączenie | 0x4A239F | 0x4A777F | jeśli 0x4A2214 nie odrzuci: dopisuje do wektora (od strony startu) punkty obecnej trasy jednostki od przedostatniego do pierwszego, czyści trasę jednostki (0x5E9770) | [W] |
| zapis | 0x5EE4E6 | 0x5FC61B | patrz niżej | [P] |
| dopisanie punktu | 0x5E8BAC | 0x5F625B | element 20 B na końcu kolejki +0x7C; m.in. test brzegu rombu (0x1816EC/F0) | [W] |

**0x4A2B29.** Pobiera wektor, ustawia jednostce +0x33E = 1 i czyści +0x194.
- Gdy jednostka ma już trasę (+0x8C ≥ 1) dłuższą od nowej, próbuje:
  - sklejenia (0x4A2214, 0x4A37A7);
  - poprawy początku maszyną `Bounded` w kwadracie ±26 pól wokół jednostki, z limitem 50 iteracji (0x4A3757).
- W pozostałych przypadkach: 0x4A239F, potem 0x5EE4E6(…, 1).
- Na końcu: 0x5EE3D2 i cel bieżący vtable +0x48.

**0x5EE4E6.**
- Gdy ostatni element wektora (pole startu) jest polem jednostki (+0x1C, +0x20), pomija go.
- Wywołuje typ jednostki vtable +0xC; w `EEUnitClass` to pusta funkcja, czyli brak wygładzania [W].
- Dodaje punkty od startu do celu przez 0x5E8BAC.

**Kolejka trasy jednostki** (+0x7C):
- mapa bloków +0x80, liczba bloków +0x84, indeks początku +0x88, liczba +0x8C;
- blok mieści 204 elementy po 20 B: x, y, z (float), długość narastająca (float), długość do poprzedniego punktu
  (float);
- punkty zużyte przez ruch przesuwają indeks początku.

[P: odczyty 469–488]

**Ostatni punkt.** W każdym pomiarze ostatni element miał dokładne współrzędne celu z rozkazu i wysokość z ≠ 0:
- (180,5; 118,5; 1,84) dla celu w bramie;
- (180,72; 123,88; 1,63);
- (150,21; 115,79; 0,82).

Pozostałe punkty miały z = 0. Kto zastępuje ostatni punkt (0x5E8BAC, 0x5EE3D2 czy vtable +0x48 celu) [N].

## 6. Szybka próba `Bounded` (EE 0x4A24E1, AoC 0x4A78C1)

| Element | Opis | Pewność |
|---|---|---|
| maszyna | jedna na menedżera (+0xBC), klucz 4, 0x148 B, pętla 0x4A59C4 (AoC 0x4AAF4C) – ta sama co w maszynie pól, bez limitu na wywołanie | [W] |
| koszt, heurystyka, test celu | te same funkcje co w maszynie pól (0x4125DD = 0x41CFFF, test 0x41230D) | [P] kod |
| dostępność | 0x412EB3: test pola + prostokąt (cel +0xA4…+0xB4) | [W] |
| uruchomienie | prośba jednostki z bajtem 14 = 0 (zwykła „PrepareToMove”); AoC dodatkowo pomija przy jednostce +0x8C ≥ 7 i nowym argumencie | [W] |
| limit całkowity m | d = \|dx\| + \|dy\| (start–cel); d > 20 → d / 20; m = d + min(zawieszone prośby + 4, 11) | [W] |
| prostokąt | start ± (m + 1), obcięty do mapy | [W] |
| sukces | +0xAD = 1 (cel+0x2D): koniec przy celu → trasa przez 0x4A2B29, pełne A* pominięte | [W] |
| porażka | +0xAD = 0: koniec = najbliższy węzeł (bez testu dostępności); trasa od razu do jednostki (0x4A32C0), pełne A* startuje **z tego punktu** | [W]; [P: E] |

**Pomiar E.**
- Trasa jednostki: prefiks (179,122)…(175,115), potem (174,115)…(150,115).
- Pełne A* liczone z modelu od pola (180,122) daje 145 iteracji w 8 wywołaniach, dokładnie jak maszyna.
- Ta sama trasa wynika z modelu od (180,123) w całości.

## 7. Eksperymenty (zadania MCP 464–489)

Scenariusz „Wojna trojańska”, mapa 280 × 280. Gwardia 0x100018B / 0x100018C, typ `EEUCLand`: rozmiar kolizji 0,5,
tablica terenu +0x5D6 = 01 00 01 01 01 01 01 01 01 01 00 01 01.

Dane mapy do modelu odczytano z pamięci:
- komórki `EEMap` w oknie x 125–205, y 95–160: teren, lista obiektów;
- 965 list obiektów;
- 940 obiektów;
- 41 typów.

Pamięć była tylko czytana. Gra stała w pauzie przy odczytach.

| Przypadek | Start → cel (pola) | Pomiar | Model | Wynik |
|---|---|---|---|---|
| A / B: obejście, cel w bramie | (177,124) → (180,118), EE 469–471 | trasa (178,123) (179,122) (180,121) (180,120) (180,119) + cel | to samo | [P] |
| B: ten sam cel z (176,125) | EE 475–476 | `Bounded`: cel (180,118), 8 iteracji, 1 wywołanie; trasa 6 kroków | 8 iteracji, identyczna (brama przechodnia) | [P] |
| C: prosto w dół | (180,118) → (180,123), EE 477–478 | `Bounded`: 6 iteracji; trasa (180,119…122) + dokładny cel | identyczna | [P] |
| D: narożniki | w trasie E 4 przekątne z jednym zablokowanym polem prostym | zgodne | zgodne | [P] reguła narożników |
| E: długa trasa, zawieszenia | (180,122) → (150,115), EE 479–480 | maszyna pól: 145 iteracji, 8 wywołań; trasa 36 punktów z zygzakiem (154,117)–(153,116) | 145 / 8, identyczna | [P] zawieszanie, limity na wywołanie 15→16…, remisy |
| F: cel w wodzie | ok. (168,115) → (156,143), EE 481–483 | graf dał punkt pośredni (147,154) za jeziorem; trasa prosta x = 147 przez pola z terenem 10; jednostka zatrzymała się na (149,137) i straciła cel | model: teren 10 niedostępny → obejście x = 145 | rozbieżność – [N] |
| AoC A | (177,124) → (180,118), AoC 485–486 | trasa i długości narastające bit w bit jak EE 469 | – | [P] EE = AoC |
| AoC E | ok. (180,120) → (150,115), AoC 487–488 | trasa (179,117)…(150,115) | zgodna z modelem z mapy EE | [P] |

**Przypadek F** pokazuje trasę, która przechodzi przez pola niedostępne według tablicy typu (teren 10). Jednostka nie
weszła na nie i zatrzymała się na brzegu.

Możliwe przyczyny:
- znaczenie wartości komórki +4 inne niż „indeks tablicy typu” dla terenu 10;
- trasa nie z A* (np. odcinek z punktów grafu przy celu nieosiągalnym);
- pozostałości pamięci podręcznej dostępności.

Rozstrzygnięcie wymaga pomiaru siatki maszyny tuż po wyszukiwaniu [N] (BO-6, podejrzenie).

**Ograniczenia.**
- Maszyny z pul są natychmiast używane ponownie przez inne jednostki (AI). Liczniki maszyny dało się powiązać z
  prośbą tylko wtedy, gdy pole celu maszyny (+4, +8) było polem badanego rozkazu (B, C, E).
- Kliknięcie celu trafiało w obiekt na linii wzroku (brama), więc cele odczytywano z pamięci.
- Nie zmierzono kar za stojące jednostki, podwojenia dla dużych jednostek ani pierwszej próby z limitem 15: w pomiarach
  cel miał już +0x34 = 3/4, więc budżet był wyliczany z odległości.

## 8. Niezależny model weryfikacyjny

Skrypt `Testy_MCP/e24/model_astar.py` (poza repozytorium) z danymi mapy w `Testy_MCP/e24/*.json` i budową dostępności
`pas.py`.

Odtwarza:
- kolejność sąsiadów i regułę narożników;
- koszt 10/14 i heurystykę 10·Manhattan;
- listę otwartą (lista + 53 kubełki, uzupełnianie po 15) i zamkniętą;
- test celu;
- limity na wywołanie (15, +1 do 32) i całkowity;
- wybór najbliższego węzła i odtwarzanie trasy.

Nie odtwarza kar za jednostki i podwojenia kosztu.

Parametry nie były dopasowywane do pomiarów. Wszystkie stałe pochodzą z kodu. Jedyna zmiana po pomiarze to
przechodniość bramy (typ 25): wynikała z liczby iteracji `Bounded` (8 zamiast 7) i z obecności punktu w bramie w
trasie.

Model potwierdza algorytm dla przypadków A–E w EE i A, E w AoC. Przypadku F nie potwierdza.

## 9. Nierozpoznane

1. Przypadek F i znaczenie terenu 10 dla trasy (BO-6) [N].
2. Kto ustawia ostatni punkt trasy na dokładny cel z wysokością [N].
3. Pełna logika 0x4A2B29 (sklejanie, 0x4A2214, 0x4A37A7, poprawa `Bounded` z limitem 50) [W/N].
4. Wpis do dziennika nieudanych prób (+0x48) – gdzie dokładnie powstaje [N]. Wpływ dziennika na budżet: mnożnik 3 w
   ciągu 4 s (`architektura_nawigacji.md` § 6) [W].
5. Związek z „CannotPathToTarget” i stanem jednostki po porażce (w F jednostka straciła cel i trasę) [N].
6. Pierwsza próba z limitem 15 – w tej ścieżce jest to wynik częściowy, a ponowienie następuje przez „PrepareToMove”
   z licznikiem prób celu +0x18 [H].

## 10. Aktualizacja etapu 29 – implementacja C++

`cpp/core/src/nawigacja.cpp` (`AStarTitan`) odtwarza model z § 8.
- 18 syntetycznych przypadków (`cpp/tests/dane/astar_referencja.json`) jest zgodnych z modelem w kolejności
  rozwijania węzłów, trasie, liczbie iteracji i wywołań. Obejmują ściany, pułapki, cele nieosiągalne, kary, limit
  całkowity, Bounded i losowe mapy 48×48.
- Na mapie z gry (lokalnie): trasy A i C identyczne z grą, E: 145 iteracji w 8 wywołaniach = gra [P].
