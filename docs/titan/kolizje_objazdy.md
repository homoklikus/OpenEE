# Kolizje, odpychanie, blokada i objazdy w Titan (EE / AoC)

Etap 26 OpenEE. Dokument opisuje, co dzieje się, gdy jednostka lądowa napotka inną jednostkę albo przeszkodę:
- lista kontaktów;
- odpychanie;
- licznik blokady +0x248;
- zdarzenie ObstacleDetected i jego losowy próg;
- stan RepathAroundObstacle;
- parametry ruchu w szyku;
- weryfikacja BO-6 i BO-7.

Gdzie indziej:
- test pojedynczego kroku i teren – `fizyka_terenu.md`;
- przejścia stanów – `skrypty_stanow.md`.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Gdzie w takcie

Po każdym trybie ruchu oprócz 2 EEPMLand woła krok końcowy (vt+0x48: EE 0x54CABF → 0x549E61; AoC 0x55BE0E → 0x556710)
[W]:
```
brak kontaktów i +0x248 == 0: koniec
jeśli v ≠ 0 albo ω ≠ 0 albo |push| ≥ 0,001 (przy typ+0x430 > 0) albo (typ+0x61A i rozkaz typu 2):
    kolizje (0x5498C4) → zastosuj odpychanie (0x549A08)
inaczej: +0x248 = 0
```
- Jednostka stojąca bierze udział w kolizjach tylko wtedy, gdy ktoś dał jej niezerowy wektor push. Jest to „budzik”
  (0,001; 0,001), który nadaje druga jednostka [W].
- Kolejność jednostek w takcie: pętla 0x547AAD od końca listy (bufor 0x918DDC). Push trafia do pól innej jednostki,
  która mogła już być przetworzona w tym takcie, więc wynik zależy od kolejności listy [W].

## 2. Lista kontaktów

+0xC4 to głowa listy, +0xC8 liczba kontaktów [W]. Budowana przez 0x5E8F0E (AoC 0x5F6817) tylko przy zmianie komórki
mapy:
- okno ±R wokół jednostki, gdzie R = rozmiar typu, przy rozmiarze < 1 co najmniej 0,5;
- warunki: jednostki tej samej klasy kolizyjnej, z flagą +0x2D8, żywe, te same flagi środowiska;
- **lista jest symetryczna:** każdy kontakt wpisywany jest do obu jednostek;
- kontakt znika, gdy któraś jednostka zmieni komórkę (0x5E960D).

Pomiar EE 518: liczba kontaktów 18e = 1, 18d = 2–3 [P].

## 3. Odpychanie

**Jednostki o rozmiarze < 1** (zwykła piechota) – 0x549179 (AoC 0x555984), wołana dla każdego kontaktu o [W]:
```
dx, dy = u − o;  S = (ru + ro)/2;  kolizja, gdy dx² + dy² ≤ S²          // połowa sumy promieni
m = (S² − d²) · (ru/ro);  px = ∓m·dx²/d²;  py = ∓m·dy²/d²              // kierunek u→o, wagi kwadratowe
jeśli u ma 1 punkt trasy i cel u leży w promieniu ro/2 od o: v_u = 0, u+0x330 = 8   // „cel zajęty”
jeśli ro ≤ ru i o może się ruszać:   o.push += (px, py)                // większa lub równa pcha mniejszą
inaczej:                              budzik o (0,001; 0,001)
jeśli o stoi i (ro > ru albo o nieruchoma):  u.push −= 2·(px, py)      // odbicie od większej / stojącej
```
- Odpychanie jest **jednostronne**: u zmienia wektor push o. Symetrię daje to, że o przetwarza u przez własną listę.
  Wynik zależy od kolejności jednostek [W].
- Wariant AoC różni się kolejnością sumowania w iloczynie skalarnym [W].
- Jednostki o rozmiarze ≥ 1 przechodzą przez 0x548A3C (linie kursów, przecięcia, ustępowanie). Geometrię opisano
  tylko na poziomie [H] i nie jest potrzebna dla piechoty.

**Zastosowanie** – 0x549A08 (AoC 0x556213) [W]:
```
(vx, vy) = push · k   (k = ceil(liczba jednostek / 2000), zwykle 1)
|vx| + |vy| < 0,02: brak ruchu
większa składowa przycięta do max(vmax, 0,005/dt), z zachowaniem proporcji
P_nowe = P + dt·(vx, vy);  pole musi być przejezdne (0x62C7C8, przekątne jak w teście kroku)
zapis x, y (0x5F0252: komórka, kontakty);  +0x248 += ms;  dosadzenie do terenu (0x5EE7D7)
push = 0
```
- Odpychanie przesuwa jednostkę także w Idle i może przenieść ją na inne pole [W].
- Nie zmienia v ani kursu. Orientacja zmienia się tylko przez pochylenie modelu przy dosadzaniu [W].

**Pomiar AoC 525** (Aleksander, rozmiar 0,55, w ruchu → stojąca gwardia 18d, rozmiar 0,5) [P]:
- Aleksander wjechał aż na odległość 0,11 od środka gwardii, bo ro ≤ ru, a test kroku przepuścił komórkę.
- Gwardia została zepchnięta o 0,41 pola w ok. 1,3 s gry, płynnie i malejąco (126,114 → 126,526).
- Aleksander stanął (v → 0 w jednym takcie) i zakończył rozkaz w 1,4 pola od celu.

**Pomiar EE 518** (gwardia 18e, rozmiar 0,5, w ruchu → stojąca gwardia 18d, 0,5) [P]:
- 18e zatrzymało się w odległości 0,48 od środka 18d, przy próbie wjazdu na komórkę (177,126), w której leży jej
  środek.
- v spadło z 0,6 do 0 w jednym takcie, po czym nastąpiło 9000 → 9006 → 5001 → 5000.
- Rozkaz zakończył się 1,9 pola przed celem. 18d się nie ruszyło.

Mechanizm z kodu [W/H]:
1. Test kroku na komórce ze środkiem innej jednostki cofa krok, zapamiętuje blokującą (+0x20C) i ustawia +0x330 = 2.
2. ObstacleDetected jest prawdziwe natychmiast przy +0x20C ≠ 0.
3. Następuje objazd (§ 6), a przy wcześniejszym +0x330 = 2 zatrzymanie.

Pełnej sekwencji stanów nie uchwycono, bo próbki szły co 2 takty [H].

**[Etap 27 – zastąpione]** Interpretacja EE 518 i AoC 525 poniżej jest poprawiona w `walidacja_kolizji.md` § 4.
Kliknięcie rozkazu trafiło w model stojącej jednostki, więc cel był jej pozycją, a zatrzymanie wynika z reguły (a)
„cel zajęty”, nie z testu kroku. Pierwotna obserwacja:

**To jedna z głównych przyczyn „zatrzymania przed celem”** [P]: jednostka, która trafia na komórkę ze stojącą jednostką,
kończy rozkaz zamiast ją objechać albo zepchnąć, gdy obie są tego samego rozmiaru.

## 4. Licznik blokady +0x248

+0x248 to f32 w ms; w zrzucie stanu gry (0x8B1E68) ma etykietę „Coll Resolut Cnt” [W, P].

| Rośnie | Zeruje się |
|---|---|
| ślizg w teście kroku | brak kontaktów i pchania (0x549E61) |
| każdy udany krok odpychania | zmiana komórki (kopia do +0x24C, odpychanie przywraca wartość) |
| zatrzymanie przez kolizję dużych jednostek | zdjęcie punktu trasy (0x5EDCF4), wyczyszczenie trasy |
| | spełnienie ObstacleDetected, objazd |

Pomiar [P]:
- wartości rosną skokowo o 34,09 ms, czyli 1 takt;
- przy zdjęciu punktu wracają do 0;
- największe zmierzone wartości:
  - 2863 ms – 18c przy brzegu (154,126), EE 513;
  - 2250 ms – 18e w tym samym miejscu, EE 524;
  - 1023 ms – przy murach bramy, EE 509.

## 5. ObstacleDetected i losowy próg

Zdarzenie 9000 w dyspozytorze 0x61B677 (AoC 0x62E47A, identyczne) [W]:
```
jeśli +0x20C ≠ 0: PRAWDA (bez losowania)
u = URandom::Generate(RTSPhysics+0x18)                    // globalny generator symulacji
T = fistp(f32((0,75 + u·0,5) · 4000))                     // ms; stała 4000 w .data 0x8ABC7C
jeśli typ+0x61A i v > 0 i cel typu 2 (atak):  T = fistp(f32(T·0,5))
inaczej, jeśli kategoria typu ∈ {6, 0x16} i v > 0 i cel typu 4 (budowa):  T = fistp(f32(T·1,5))
jeśli +0x248 > T: +0x248 = 0; PRAWDA
```
- **Generator** – `Low-Level Engine.dll` 0x10002117 (AoC 0x1000DDE9) [W]:
  - s = (214013·s + 2531011) mod 2³¹, wynik s/2³¹;
  - jeden obiekt w RTSPhysics ([0x919774]+0x18), ziarno 1 w konstruktorze, odtwarzane z zapisu gry;
    **[Etap 27 – uzupełnione]** przy rozpoczęciu gry ziarno ustawia `EEMStartLoading` (EE 0x4BEE9D) z `TMGetTime`;
    ziarno 1 z konstruktora jest nadpisywane (`specyfikacja_ruchu_godot.md` § 5);
  - wspólny dla wszystkich jednostek i ponad 280 innych miejsc kodu.
- **Losowanie co takt** [W]: zachodzi przy każdej ocenie zdarzenia, czyli w każdym takcie w stanie Advance, w którym
  punkt nie został osiągnięty (ArrivedAtMoveWaypoint jest sprawdzane wcześniej). Próg nie jest losowany raz na
  przeszkodę.
- **Skutek:** jednostka w ruchu zużywa jedną liczbę z globalnego generatora na takt. Liczba i kolejność ruchomych
  jednostek wpływa na wszystkie dalsze losowania w grze. OpenEE musi to odtworzyć dla zgodności lockstep [W].
- **Pomiar:** ObstacleDetected nie wystąpiło w żadnej próbie (EE 509, 513, 524). Licznik nie przekroczył 2,9 s, a T ≥
  3 s. Wejście w 9002 – nieuchwycone [N].

## 6. RepathAroundObstacle (9002)

Wejście EE 0x6225E7 (vt+0xD4), AoC 0x636B69 (vt+0xD8, identyczne poza przesunięciem +0x330 → +0x33C) [W].

**Ścieżka A – boczny unik w pościgu** (cel typu 2, typ+0x61A, v > 0, cel bliżej niż 2·rozmiar):
- 4 punkty kandydujące J ± n, P ± n prostopadle do kierunku na cel;
- test przejezdności i zatłoczenia;
- dopisanie 1–2 punktów;
- licznik prób celu += 8.

To są „4 sąsiednie pola” z etapu 25 [Etap 26 – uściślone: dotyczą tylko pościgu].

**Ścieżka B – ogólna, dla ruchu do miejsca:**
```
D = pierwszy punkt trasy (albo pozycja celu z przesunięciem szyku)
pole(D) == pole(J): punkt uznany za osiągnięty (+0x33F = 1, +0x330 = 8); koniec
zbiór omijanych J+0x194 = pola blokującego (+0x20C) ∪ pola odcinka J→D (bez pola celu G)
G = punkt trasy nr k (k = min(n−1, 7) albo pierwszy odległy o ≥ c)
R = EEPathManager.0x4A1E11(J, pole(J), pole(G), okno ±50 pól, omijane)   // SYNCHRONICZNE A* w oknie
sukces (koniec R na polu G): R + D sklejane z resztą starej trasy (0x4A2034), stara trasa czyszczona,
         dopisane punkty R; +0x330 = 1
porażka:
   +0x330 == 2 (druga porażka): v = 0, tryb 6, stan Idle (zbieracz: 4006), +0x330 = 0
   inaczej: +0x330 = 2, trasa bez zmian (jednostka jedzie dalej starą trasą)
```

**Następny takt** (skrypt: RepathAroundObstacle { MovePreparationComplete true(Advance) false(ShouldIReturn…) }):
- MovePreparationComplete = „trasa niepusta”, bo +0x33E jest tylko ustawiane;
- po sukcesie i po pierwszej porażce następuje powrót do Advance;
- przy pustej trasie: ShouldIReturnToInitialContactLocation, a stamtąd Idle.

**Lokalny objazd a pełne planowanie** [W]:
- objazd B to ograniczone, natychmiastowe A* (okno ±50 pól) z omijaniem pól blokujących, sklejane ze starą trasą;
- pełne planowanie przez EEPathManager (0x4A1AFF, asynchroniczne, z budżetem) uruchamia dopiero PrepareToMove
  (`architektura_nawigacji.md`).

**Limity:**
- objazd B nie ma własnego licznika; jego limit to dwie porażki z rzędu (+0x330);
- licznik prób celu (cel+0x18, limit 3 dla Location) rośnie tylko w PrepareToMove i w ścieżce A.

**Zmiana rozkazu w trakcie:** nowy cel ustawia stan przez 0x5EFCF0 i zapisuje +0x248 do +0x24C [H].

```
Advance ─(+0x20C ≠ 0 albo +0x248 > T)→ 9002 ─┬─ B: sukces → nowa trasa (+0x330 = 1) → Advance
                                             ├─ B: 1. porażka → +0x330 = 2, stara trasa → Advance → …
                                             ├─ B: 2. porażka → v = 0, Idle (bezpośrednio)
                                             ├─ D na polu J → +0x33F = 1 → Advance → GetNextMoveWaypoint
                                             └─ A (pościg) → 1–2 punkty boczne → Advance
                         (trasa pusta) → ShouldIReturnToInitialContactLocation → Idle
```

Pewność: kod [W]; przebieg w grze nieuchwycony [N]. Zatrzymanie EE 518 pasuje do gałęzi „+0x20C → 9002 → … → stop”
[H].

## 7. Mury, bramy, budynki

- Mur i budynek blokują pola przez listy obiektów komórek: A* je omija, test kroku ślizga się wzdłuż nich [W].
- W kolizjach jednostek (§ 3) obiekty nieruchome działają jak przeszkoda „większa / nieruchoma”, od której jednostka
  się odbija (2·push), o ile są na liście kontaktów [H].
- Z bramą typu 25 (`EEUCGate`) kolizja jest liczona tylko wtedy, gdy jej akcja to 15001 „Closed”, czyli brama
  zamknięta. Brama otwarta jest przepuszczana [W]. W tej samej pętli (0x5498C4) wynik wcześniejszego testu
  zgodności rozkazów jest nadpisywany wartością „kolizja” przy każdym obiekcie, który nie jest bramą – BO-9.
- Pomiar: ślizg przy murach bramy (178,117) dał +0x248 do 1 s, bez objazdu [P].

## 8. Parametry ruchu w szyku

**Grupa** (`EEActiveGroup`, jednostka+0x1C8). Obliczenie 0x5DCE49 (AoC 0x5ED692, identyczne) [W, P]:
```
dla członków:  Σ, max, min dla vmax (+0x70 / +0x74 / +0x78), a (+0x7C …), ωmax (+0x88 …), α (+0x94 …)
średnia = Σ/n;  wartość = min(średnia, k·min)   (k = zmienna gry 0x31, tablica 0x917BB4)
+0xA0…+0xAC = odwrotności
```
**Gettery** (0x5DD355 vmax, 0x5DD373 a, 0x5DD391 ωmax, 0x5DD3B2 α …) zwracają wartości grupy tylko przy grupa+0xB6 ≠ 0.
- +0xB6 = (cel ma typ 1 i cel+0x33 ≠ 0), czyli rozkaz ruchu w szyku: PPM z przeciągnięciem (`przydzial_specjalny.md`).
- Po wyjściu z grupy obowiązują własne parametry +0x34.

**Pomiar EE 519** (gwardia 0,6 + Aleksander 0,8) [P]:

| Rozkaz | grupa+0xB6 | Parametry grupy | Prędkość gwardii |
|---|---|---|---|
| PPM (klik) | 0 | vmax 0,7 / 0,8 / 0,6; a 2,0; ωmax 10,47 / 13,96 / 6,98; α 9,60 / 12,22 / 6,98; 1/vmax 1,429 | 0,6 (własne parametry) |
| PPM z przeciągnięciem | 1 | jak wyżej | **0,7**: średnia grupy, szybciej niż własne 0,6 |

- Po rozkazie PPM grupa przeliczyła się po odłączeniu Aleksandra do 0,6 / 0,6 / 0,6 [P].
- k·min ≥ średnia: k ≥ 0,7/0,6 = 1,17. Dokładna wartość k [N].
  **[Etap 27 – zastąpione]** k = 2,0: `dbworld.dat` WorldID 0x31 (EE i AoC), pomiar grupa+0xB0 = 2,0 [P].
- **W szyku wolniejsza jednostka jedzie szybciej niż jej własna vmax** (0,7 > 0,6), a szybsza wolniej. Przyspieszenie i
  skręcanie też są uśrednione: gwardia w szyku ma α 9,6 zamiast 12,2 [P].
- Obserwacja H z etapu 25 (0,395–0,464) to wpływ stoku, a nie parametru grupy (`fizyka_terenu.md` § 3).

**Pochodzenie parametrów** [W]:
- rekord bazy jednostek: +0x94 v, +0x98 a, +0x9C α, +0xA0 ωmax, +0xA4;
- konstruktor EEUnitClass 0x61C35B kopiuje je do typu (+0x430 … +0x448);
- obiekt +0x34 (`EEUnitClassUpgrade`, 0x627765 / init 0x627942) dostaje a, vmax, α, ωmax i odwrotności, oraz +0xBC =
  min(a, vmax);
- ulepszenie prędkości (SetSpeed 0x628051) skaluje proporcjonalnie a, α i ωmax, a obiekt jest współdzielony przez
  jednostki danego typu i gracza [W/H];
- **[Etap 26 – zastąpione]:** w etapie 25 „loader 0x4D63F1” uznano za źródło parametrów; to w rzeczywistości tablica
  mnożników obrażeń (0x8D200C).

## 9. Ruch jednoczesny i kolejność

- Dwie jednostki w ruchu przetwarzają się nawzajem przez symetryczną listę kontaktów, ale push nakładany jest
  jednostronnie (§ 3).
- Kolejność pętli (od końca listy jednostek) decyduje, która dostanie wektor w tym samym takcie [W].
- Członkowie tej samej grupy nie są w kolizjach rozróżniani. Mają osobne cele (sloty szyku), więc zwykle się nie
  stykają [W].
- Pomiaru dwóch jednostek jadących naprzeciw siebie nie wykonano. Wybór dwóch jednostek do osobnych rozkazów przez
  Riverlands_MCP jest zawodny [N].

## 10. BO-6 i BO-7 – weryfikacja regresyjna

**BO-6** (etap 24: zatrzymanie przy brzegu i utrata celu) [P]:
- Odczyt końcowy zadania 483 z etapu 24 pokazuje stan **6002 „UnitRotting”** (tryb 6), +0x1F0 = 0 i v = 0. Jednostka
  **zginęła**, a utrata celu i trasy to skutek śmierci.
- Powtórki EE 513–514 (18c) i 524 (18e) na ten sam cel: jednostki doszły w rejon jeziora (150–154, 126–131), były
  popychane (+0x230 / +0x234 ≠ 0, +0x248 do 2,9 s) i zginęły (6000 → 6002 → 6003). Pamięć 18c zajęła potem nowa
  jednostka.
- W okolicy są jednostki wroga (scenariusz „Wojna trojańska”).
- **Wniosek:** zatrzymanie i utrata celu nie są błędem ruchu.
- Otwarte zostaje pytanie, czy trasa z etapu 24 prowadziła przez pola niedostępne (teren 10). W powtórce trasa szła
  inaczej (obejście przez (147,5; 145–148)) [N].

**BO-7** (docisk ostatniego kroku) [P]:

| Przypadek | Pomiar |
|---|---|
| krótki rozkaz z miejsca, EE 517 (cel ok. 0,4 pola, z zawrotem) | v rośnie do 0,42, potem v = d co takt: 0,2556 → 0,2469 … (×0,966 = 1 − dt); dojazd ok. 80 taktów zamiast ok. 15; stop przy d < 0,05 |
| krótki rozkaz, AoC 525 (Aleksander, ok. 0,5 pola) | to samo: 0,6818 → 0,6667 → 0,644 … ×0,966 |
| cel bliżej niż krok (cel = pozycja), EE 517 | d < 0,05 od razu: 1 takt Advance z v = 0, potem 9006 → 5001 → 5000, brak ruchu |
| przy vmax | docisk nie działa: v′ = v + a·dt w precyzji x87 jest o 7,5e-9 większe od vmax (także po hamowaniu na stoku), dojazd dokładnym hamowaniem [P: EE 500, 517, AoC 505, 525] |
| z niezerowej prędkości, EE 518 | rozkaz zmieniony przy v = 0,3955: zawrót przy 0,6 (reguła X przy dużym ω), bez docisku |

- Model z dosłownym kodem odtwarza krótkie rozkazy co do taktu (EE 517: koniec 80 / 80) [P].
- Skutek: każde dojście przy v < vmax w zasięgu d < v (do ok. 0,6–0,8 pola) kończy się wykładniczym dojazdem,
  trwającym zwykle 1–2 s gry. Dotyczy to krótkich rozkazów i dojazdu po zakręcie.

## 11. Aktualizacja etapu 27

Pomiary i ponowna analiza: `walidacja_kolizji.md`. Zmiany względem tego dokumentu:
- **Wzór odpychania 0x549179 potwierdzony dokładnie** (EE 535, 4 takty, zgodność do precyzji f32) [P]. Reguła (a)
  „cel zajęty” potwierdzona w EE 528: v = 0, +0x330 = 8 w jednym takcie [P].
- **§ 3:** zatrzymania w EE 518 / AoC 525 wynikają z reguły (a), nie z testu kroku (adnotacja wyżej).
- **§ 5:** ObstacleDetected nadal nieosiągnięte. Max +0x248 to 2693 ms (EE 535). Licznik zeruje się przy zmianie
  komórki i zdjęciu punktu [P]. Wejście w 9000 z pre-testem następnego odcinka (typ+0x5D4 & 2 → +0x20C,
  +0x330 = 2) [W].
- **§ 5, generator:** ziarno z `TMGetTime` przy starcie gry. Co takt co najmniej 2 losowania globalne (0x546CE9,
  0x547C09), Advance – 1 na jednostkę na takt (poza taktem osiągnięcia punktu i przy +0x20C ≠ 0). W pomiarze
  15–40 losowań na takt w całej grze. Determinizm przy powtórzonych startach [P] (`rng_527`).
- **§ 7, BO-9:** nadpisanie dotyczy tylko kategorii 0x19 bez bramy (mury). Nowe podejrzenie BO-9′
  (`BLEDY_ORYGINALU.md`).
- **§ 8:** k = 2,0 [P]. Jednostka opuszcza grupę przy wejściu w Idle (EE 0x55C567), a grupa jest przeliczana. Pomiar
  EE 537: grupa mieszana 0,7, jednorodna 0,6, po dojeździe przeliczenie do 0,6 [P]. Grupy mieszanej w AoC nie uzyskano
  (539–540: za mało próbek) [N].
- **§ 9:** ruchu dwóch jednostek jednocześnie nadal nie zmierzono (`walidacja_kolizji.md` § 5) [N].
- **Odbudowa kontaktów EE ↔ AoC:** różnica w kodzie potwierdzona, bez testu dynamicznego – [W].
