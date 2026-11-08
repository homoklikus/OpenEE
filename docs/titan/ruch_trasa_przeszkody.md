# Wykonywanie trasy, przeszkody, przejścia Shift i model ruchu w Titan (EE / AoC)

Etap 25 OpenEE. Uzupełnienie `ruch_jednostki.md` (stany, takt, wzory). Ten dokument opisuje:
- zużywanie kolejki trasy +0x7C;
- zmiany trasy w trakcie ruchu;
- reakcję na przeszkody;
- przejścia między celami Shift;
- usuwanie punktów pośrednich +0x32;
- eksperymenty EE / AoC;
- niezależny model obliczeniowy.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Kolejka trasy +0x7C

Kolejka dwustronna (`astar_wyniki.md` § 4) [P]:
- elementy po 20 B: x, y, z, długość narastająca, poprzednia długość narastająca;
- +0x88 = indeks początku, +0x8C = liczba punktów;
- punkty to środki pól, a ostatni punkt to dokładny cel albo środek najbliższego dostępnego pola.

Kolejka celów +0x90 to osobna struktura (`kolejka_rozkazow.md`).

| Operacja | Funkcja EE / AoC | Kiedy | Pewność |
|---|---|---|---|
| odczyt punktu z przodu | 0x5EC69D / 0x5FA229 | co takt w trybie 0; przy pustej kolejce zwraca 7 i tryb 0 kończy się bez ruchu | [W], [P]: 1 takt bez ruchu po ostatnim punkcie |
| pozostała długość | 0x5EC655 / 0x5FA1E1 | decyzja o hamowaniu, gdy +0x8C > 1: R = narastająca(ostatni) − poprzednia narastająca(przód) | [W] |
| zdjęcie punktu z przodu | 0x5EDCF4 / 0x5FBDD1 | tylko wejście w 9000 GetNextMoveWaypoint; zeruje też +0x248 | [W], [P]: +0x248 = 0 po każdym zdjęciu (EE 509) |
| wyczyszczenie | 0x5E9770 | wejście w 5000 Idle, 8000 PrepareToMove, 9002 RepathAroundObstacle | [W] |
| dociągnięcie trasy | 0x5EB119 / 0x5F8C2D | zdarzenia 9005 / 9006, gdy zostały ≤ 2 punkty | [W] |

**Punkt po punkcie, bez wybierania punktu dalej** [W, P]
- Titan wykonuje trasę punkt po punkcie. Kierunek liczy się zawsze do punktu z przodu kolejki.
- Nie ma mechanizmu wybierania dalszego punktu ani wygładzania.
- „Ścinanie” zakrętów wynika tylko z promienia zaliczenia, czyli rozmiaru kolizji 0,5 / 0,55 na polu punktu
  (`ruch_jednostki.md` § 8), oraz z bezwładności obrotu.
- Pomiar EE 500: punkt znika przy d ≈ 0,42–0,46. Przy przekątnej jednostka mija środek pola w odległości do ok. 0,3.

**Nowa trasa w trakcie ruchu** [P: EE 509]
- Liczba punktów rosła w trakcie jazdy, np. 32 → 35, a raz po krótkim stanie 8000 wzrosła z 6 do 50. Prędkość
  pozostała 0,6.
- Wymiana albo sklejenie trasy nie zatrzymuje jednostki.
- Wejście w 8000 czyści trasę, ale tryb ruchu pozostaje 0. W taktach bez punktu tryb 0 nie przesuwa jednostki, a po
  przyjściu nowej trasy jedzie dalej z tą samą prędkością [W].

**Anulowanie (nowy zwykły rozkaz)** [W]
- Nowy cel trafia przez obsługę grupy do stanu 8000: wyczyszczenie trasy i nowa prośba.
- Prędkość i ω są zachowane. Jednostka rusza z bieżącą prędkością w nowym kierunku i zwalnia na zakręcie > 45°.

## 2. Długości narastające

Służą wyłącznie do R w decyzji o hamowaniu [W].
- R jest liczone od poprzedniego punktu, nie od jednostki. Przy +0x8C > 1 zawiera więc odcinek już przejechany.
- W praktyce R ≤ S (≈ 0,10 pola dla 0,6) zachodzi dopiero przy jednym punkcie. Wtedy R = d, a hamowanie jest dokładne.

## 3. Przejścia Shift

Pomiar EE 501 (Aleksander, A → B, cele w kolejce +0x90), kolejność obiektów stanu w każdym takcie [P]:
1. Ostatni punkt trasy do A zaliczony przy pełnej prędkości 0,8, bez hamowania przed punktem. Brak hamowania – [N],
   zob. niżej.
2. 9000 zdejmuje punkt (+0x8C = 0), potem 9006 TurnToUnitFacing.
   - Zdarzenie 9014 UnitFacingNotRequired jest prawdziwe, gdy w poziomie celów jest więcej niż 1 cel [W].
   - Obrót jest więc pominięty, a w tym czasie tryb 5 / 3 hamuje z jazdą naprzód.
3. Idle (wejście zdejmuje cel A i aktywuje B), potem 8000. Trasa do B (6 punktów) jest w kolejce od razu, jeszcze w
   takcie 8000.
4. 2015, potem Advance.
   - Kąt do pierwszego punktu B wynosił ok. 100°, więc |diff| > π/4 i dalsze hamowanie do 0,255.
   - Potem przyspieszanie ze skrętem (ω do 3,33 rad/s, czyli ωmax z zaokrągleniem kroków), pełne 0,8 po 13 taktach.
5. Najmniejsza prędkość wyniosła 0,255. Nie było pełnego zatrzymania: przejście jest płynne, ale z hamowaniem.

Zależność od kąta [W, P]:
- Hamowanie trwa, dopóki błąd kursu przekracza 45° (reguła X) albo dopóki trwa przejście przez stany końca A.
- Przy kontynuacji prosto spadek ogranicza się do kroków w stanach 9006 / Idle / 8000, czyli ok. 3 · a·dt.
- Wartości pośrednie zależą od szybkości przyjścia trasy B. Gdy menedżer ścieżek potrzebuje kilku taktów, jednostka
  hamuje dłużej [H].

Na końcu B: hamowanie do zera, obrót do kursu celu (5 → 39,9°), potem cykl stanów spoczynku bohatera [P].

**Brak hamowania przed A** [N]
- Według kodu przy +0x8C = 1 decyzja R = d ≤ S powinna włączyć hamowanie od d ≈ 0,17.
- Hipotezy:
  - test zaliczenia dla celu z następnym celem traktuje punkt jak pośredni (0x6213D8: „specjalne cele typu 1/10”);
  - koniec trasy A nie był ostatnim punktem z +0x8C = 1 w chwili decyzji.

## 4. Przeszkody

**Wykrywanie** [W] – zdarzenie 9000 ObstacleDetected (0x61B677):
- Prawdziwe natychmiast, gdy +0x20C ≠ 0 (kto ustawia – [N]).
- Albo gdy +0x248 > T.
  - T = los[0,75; 1,25] · 4000 ms.
  - ×0,5, gdy typ+0x61A, v > 0 i cel ma typ 2.
  - ×1,5 dla kategorii typu 6 / 0x16, gdy v > 0 i cel ma typ 4.
  - Po spełnieniu +0x248 = 0.
- +0x248 to **f32 w ms** [P: EE 509; wartości 34,09 · n].
  - Rośnie o ms taktu w każdym takcie, w którym odpychanie (0x549A08) rzeczywiście przesuwa jednostkę.
  - Zeruje się przy braku pchania i przy każdym zdjęciu punktu.

**Pomiar EE 509** (gwardia przez bramę i wzdłuż murów) [P]:
- +0x248 osiągało 34–1023 ms przy ścianach i bramie (178,117), (162,117), (148,149) i zerowało się przy zdjęciu
  punktu.
- T (3–5 s) nie zostało przekroczone, więc nie było „ObstacleDetected” ani objazdu.
- Wniosek: zwykłe otarcie o ściany i jednostki nie wywołuje ponownego wyznaczania trasy. Potrzeba ok. 3–5 s ciągłego
  pchania bez postępu.

**Rozdzielanie kolizji** (po każdym trybie oprócz 2) [W]:
- Wektor odpychania (+0x230 / +0x234) od innych jednostek jest przycinany do max(vmax, 0,005/dt) i całkowany
  z kontrolą pól.
- Działa także w spoczynku, więc jednostka stojąca u celu może zostać odepchnięta.

**RepathAroundObstacle 9002** (0x6225E7 / AoC 0x636B69) [W]:
- czyści trasę;
- sprawdza 4 sąsiednie pola *[Etap 26 – tylko w pościgu; ogólnie A* w oknie ±50 pól – `kolizje_objazdy.md` § 6]*;
- dopisuje punkty objazdu (0x5E8BAC) albo zleca nowe szukanie (0x4A1E11, 0x4A2034);
- dokładna logika – [N].

**Porzucenie celu** [W]:
- Wejście w 8000, gdy licznik prób cel+0x18 > limitu (cel→vt+0x2C), przechodzi do Idle bez ruchu.
- „RepathCompleted” 9003 i „CannotPathToTarget” 8011 są dla celu-lokacji zawsze fałszywe. Kod nie zgłasza tego
  zdarzenia dla jednostki lądowej z celem-położeniem.

**Lokalne omijanie** w sensie sterowania nie istnieje [W]. Jednostki rozdziela odpychanie, a omijanie przeszkód
stałych daje trasa A*. Nieudany krok (0x54E275, test przejezdności po ruchu) – szczegóły [N]. *[Etap 26 – rozpoznane: ślizg po osiach albo cofnięcie, zatrzymanie na komórce ze środkiem innej jednostki – `fizyka_terenu.md` § 4, `kolizje_objazdy.md` § 3.]*

## 5. Cel nieosiągalny (eksperyment I, BO-6)

Pomiar EE 509–510: gwardia, rozkaz na wodę (156,5; 143,5) z (178,6; 125,2) [P].
- Trasa obeszła jezioro w trzech odcinkach.
  - Liczby punktów 42 → … → 6, potem 8000 i 50 punktów, potem dalej.
  - Wydłużenia przyszły bez zatrzymania.
- Jednostka stanęła w (155,5; 151,5), czyli w środku najbliższego dostępnego pola, 8 pól od kliknięcia.
  - Zaliczenie przy v = 0,327, potem 9006 i 5000.
  - Ostatni punkt to węzeł wybrany przez A* (+0x94, `astar_wyniki.md` § 1), nie kliknięcie.
- Inaczej niż w przypadku BO-6 (etap 24, start (150,7; 115,7)), jednostka nie zatrzymała się przy brzegu i nie
  straciła celu przed jego osiągnięciem.
- *[Etap 26 – rozstrzygnięte: jednostka z etapu 24 zginęła (stan 6002), powtórki też kończą się śmiercią w tym rejonie – `kolizje_objazdy.md` § 10.]* BO-6 nie zostało tu powtórzone. Możliwy mechanizm z kodu: niedostępne pole → ciągłe odpychanie / test 0x54E275 →
  9000 po 3–5 s → objazd / wyczerpanie prób → Idle [H] (adnotacja w `BLEDY_ORYGINALU.md`).

## 6. Usuwanie punktów pośrednich +0x32 „ok. 15 pól wcześniej”

Zdarzenie 9016 ShouldMoveToNextAutoWaypoint (0x5F0844, AoC 0x5FEB61) [W].

Jest prawdziwe, gdy jednocześnie:
- cel jest `EEUGLocation` z +0x32 ≠ 0;
- w poziomie celów 0 jest więcej niż 1 cel;
- menedżer ścieżek uznaje trasę jednostki za kompletną (0x4A151C prawda, 0x4A14CE fałsz);
- i do tego **+0x8C ≤ N** albo (+0x8C ≤ 2N lub ⌈(+0x2DC/5)·N⌉ przy typ+0x5D4 & 4) i region końca trasy jest „bliski”
  (0x409914 < 2).

Wartość N = [0x917DC8] zależy od rozmiaru mapy (0x4243AC):

| Rozmiar mapy | ≤ 42 | ≤ 58 | ≤ 75 | ≤ 105 | ≤ 160 | ≤ 220 | powyżej |
|---|---|---|---|---|---|---|---|
| N | 8 | 10 | 12 | 14 | 16 | 18 | 14 |

AoC: zapis do 0x92FD80 w 0x420BA5, te same progi.

Według skryptu [H] dalej następuje przejście do 8021 GetNextAutoWaypoint. Jego wejście zdejmuje cel +0x32 (0x5EAE25)
i aktywuje następny cel, więc 8000 i nowa trasa.

Wniosek:
- Punkt +0x32 jest porzucany, gdy do jego osiągnięcia zostało ≤ N punktów trasy.
- Trasa ma jeden punkt na pole, więc to ok. N pól (14–16 na mapach testowych).
- To zgadza się z obserwacją z etapu 22 („zdjęty ok. 15 pól przed punktem”, EE 451).

To **zamierzone przełączanie celu z wyprzedzeniem**, nie błąd: jednostka płynnie kieruje się do kolejnego celu grupy
zamiast dojeżdżać do węzła pośredniego [W]. Pomiar N dla mapy 280 × 280 (próg „powyżej 220” = 14) – [P/W]: zgodne
z ok. 15 polami, dokładna liczba punktów w chwili zdjęcia nie była rejestrowana.

## 7. Zatrzymanie przed celem – przyczyny

Pomiary z etapu 25 nie pokazują jednej przyczyny dla wszystkich przypadków.

| Przyczyna | Kiedy | Odległość | Pewność |
|---|---|---|---|
| koniec trasy w najbliższym dostępnym węźle A* | cel niedostępny (woda, budynek, krawędź) | dowolna, zwykle ≥ 1 pole; punkt końca w środku pola | [P] EE 509–510 |
| pozycja szyku | rozkaz grupowy – każda jednostka ma własny cel przesunięty szykiem | ok. 1–2 pola od kliknięcia | [P] etapy 17–20 |
| odepchnięcie po dojściu | inne jednostki u celu; rozdzielanie działa także w spoczynku | ułamek pola do ok. 1 pola | [W] |
| porzucenie celu (limit prób, BO-6) | trasa przez pola niedostępne / blokada | dowolna | [H] *[Etap 26: BO-6 to śmierć jednostki]* |
| *[Etap 26]* stojąca jednostka na komórce na drodze | test kroku cofa krok, rozkaz kończy się (9000 → 9006 → 5001 → 5000) | ok. 1–2 pola | [P] EE 518, AoC 525 |
| *[Etap 26]* wykładniczy dojazd BO-7 | dojście przy v < vmax z d < v | jednostka dochodzi, ale 1–2 s dłużej | [P] EE 517, AoC 525 |
| przełączenie celu +0x32 z wyprzedzeniem | punkty pośrednie trasy grupowej | ≤ N pól przed węzłem pośrednim, nie przed celem końcowym | [W] |

Przy zwykłym rozkazie na dostępne miejsce jednostka staje w punkcie kliknięcia z dokładnością < 0,05
(próg 0x825508). Hamowanie jest dokładne, bo S jest sumą dyskretnych kroków [P: EE 500, AoC 505].

## 8. Eksperymenty EE / AoC (zadania 490–510)

Odczyt pamięci bez modyfikacji, próbki w każdym takcie (34,09 ms gry) albo co 2 takty.

Ograniczenie: zapis kroku MCP trwa ok. 1 takt, więc część próbek ma odstęp 2 taktów. Kroki fizyki nie są dzielone,
więc 1 takt to najmniejszy możliwy interwał.

| Eksperyment | Zadania | Wynik |
|---|---|---|
| A – prosto | EE 492, 500; AoC 505 | 0,0682 / takt, krok v·dt, vmax 0,6 / 0,8 [P] |
| B – po przekątnej | EE 500 (pierwsze odcinki), 509 | ten sam krok, bez wzmocnienia √2 [P] |
| C – zakręt | EE 500 | profil ω trapezowy (0,416 · n), hamowanie 1–2 · a·dt przy > 45° [P] |
| D – hamowanie | EE 500, AoC 505 | start przy R ≤ S, stop w celu < 0,05, potem 9006 → 5001 → 5000 [P] |
| E – dwie prędkości | gwardia 0,6 / Aleksander 0,8 | te same a; α 12,217 / 6,981; ωmax 13,96 / 6,98 (EE 508) [P] |
| F – przeszkoda | EE 509 (mury, brama) | +0x248 do 1023 ms, bez 9000 / objazdu [P]; pełna reakcja [W] |
| G – Shift | EE 501 | 2 cele: płynne przejście z hamowaniem do 0,255 przy zakręcie ok. 100° [P]; trzeci rozkaz nie trafił (cel niewidoczny) |
| H – szyk: przeciągnięcie a klik | EE 502–503 | pojedyncza jednostka po przeciągnięciu: v ≈ 0,395–0,464 zamiast 0,6, hamowanie stopniowe; mechanizm: parametry z grupy (+0xB6 = 1 → grupa+0x70 / +0x7C) [W], wartości [N] |
| I – cel nieosiągalny | EE 509–510 | stop w najbliższym dostępnym polu, bez BO-6 [P] |
| J – EE a AoC | 500 / 505 | te same stałe; model z parametrami EE odtwarza AoC [P] |

## 9. Niezależny model obliczeniowy

Pliki (poza repozytorium) w `Testy_MCP/e25/`:
- `model_ruchu2.py` – model;
- `porownaj2.py`, `odcinki.py` – porównania;
- dane: `serie.json`.

Model:
- **Wejście:** pozycja, kurs, v, ω, punkty trasy, parametry typu (a, vmax, α, ωmax, rozmiar, 1/a, 1/α), dt, kurs
  końcowy.
- **Wyjście co takt:** pozycja, v, ω, kurs, stan (10003 / 9000 / 2015 / 9006 / 5001), indeks punktu, chwila zatrzymania.
- **Reguły:** wyłącznie z kodu (`ruch_jednostki.md` § 5), także docisk z BO-7 i 3-taktowy cykl stanów przy punkcie.
- **Współczynniki:** odczytane z obiektu parametrów i typu (EE 508), bez dopasowania do wyników.
- **Pominięte:**
  - reguła nachylenia (brak mapy nachyleń w modelu);
  - kolizje i odpychanie;
  - test przejezdności 0x54E275.

**Przebieg ciągły** od startu do zatrzymania (punkty trasy z kolejności zdejmowania, cel z pamięci):

| Scenariusz | Próbek | Pozycja max / śr | v max / śr | Kąt max / śr | Ruch: model / gra | Stop: odchyłka |
|---|---|---|---|---|---|---|
| EE 500, gwardia (21 punktów) | 811 | 0,158 / 0,119 | 0,409 / 0,009 | 31,7° / 1,19° | 1099 / 1106 taktów | 0,012 |
| AoC 505, Aleksander (20 punktów) | 733 | 0,242 / 0,176 | 0,477 / 0,015 | 26,0° / 1,00° | 800 / 808 taktów | 0,005 |

**Odcinkowo** (model startuje ze stanu gry po każdym powrocie do Advance i liczy do zdjęcia następnego punktu, ≤ 40
taktów):

| Scenariusz | Odcinków | Próbek | Pozycja max / śr | v max / śr | Kąt max / śr |
|---|---|---|---|---|---|
| EE 500 | 21 | 617 | 0,061 / 0,004 | 0,136 / 0,005 | 4,9° / 0,10° |
| AoC 505 | 20 | 648 | 0,137 / 0,006 | 0,136 / 0,009 | 2,8° / 0,11° |

**Rozbieżności i ich źródło:**
- Średnia odchyłka ciągła (0,12–0,18 pola) to narastające opóźnienie, bo model nie odtwarza piłokształtnej prędkości
  pod górę.
  - Spadki v w grze to dokładnie 1 albo 2 · a·dt, zgodnie z regułą nachylenia i zakrętów > 45° (EE: 61 + 6 z 75 próbek
    v < vmax; AoC: 46 + 24 z 80; pozostałe to rozpędzanie po starcie).
  - Średnia odchyłka odpowiada przesunięciu w czasie o ok. 6–9 taktów; tyle samo wynosi różnica chwili zatrzymania
    (7–8 taktów, model wcześniej).
- Maksima kąta (26–32°) przypadają na zakręty, przy których model jest przesunięty w czasie o kilka taktów.
  Odcinkowo maksimum wynosi 3–5°.
- Odchyłki maksymalne odcinkowe (0,06 / 0,14) dotyczą odcinków 2–3 (y ≈ 122–124), gdzie gra jedzie pod górę
  z piłokształtną prędkością. Pozostałe odcinki mają ≤ 0,03 pola (EE ≤ 0,02).

## 10. Model etapu 26 (teren) – porównanie z modelem etapu 25

*[Etap 26]* Model v3 (`Testy_MCP/e26/model_ruchu3.py`) dodaje do v2:
- regułę stoku z nachyleniem liczonym jak w kodzie (asin(Δz/1,3), punkty ±0,65, tablicowe UMArcCos);
- siatkę wysokości z pamięci gry;
- pochylanie macierzy dla typów z flagą +0x5F3;
- arytmetykę porównań prędkości w precyzji x87 (53/64 bity).

Zgodność z grą [P]:
- wysokość z jednostki zgadza się z modelem bit w bit;
- nachylenie macierzy Aleksandra zgadza się z modelem.

Kolizji, testu kroku i objazdów model nie zawiera. W porównywanych przebiegach nie było kontaktów ani ślizgów.

Próbki co 1–2 takty, porównywane tylko takty zmierzone, bez interpolacji. „Takty rozbieżne”: |Δpoz| > 0,01 albo |Δv| >
0,001.

| Scenariusz | Model | Próbek | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec ruchu (model − gra) [takty] | Stany zgodne | Punkt aktywny zgodny | Takty rozbieżne |
|---|---|---|---|---|---|---|---|---|---|
| EE 500 gwardia (etap 25) | v2 | 811 | 0,1185 / 0,1582 | 0,0088 / 0,409 | 1,19° / 31,7° | -7 | 755/811 | 720/811 | 712 |
| EE 500 gwardia (etap 25) | v3 | 815 | 0,0106 / 0,0262 | 0,0010 / 0,136 | 0,29° / 9,7° | +0 | 794/815 | 809/815 | 415 |
| AoC 505 Aleksander (etap 25) | v2 | 733 | 0,1764 / 0,2419 | 0,0152 / 0,477 | 1,00° / 26,0° | -8 | – | 611/733 | 652 |
| AoC 505 Aleksander (etap 25) | v3 | 749 | 0,0055 / 0,0842 | 0,0040 / 0,541 | 0,38° / 15,6° | +15 | – | 734/749 | 44 |
| EE 517 krótki z zawrotem (BO-7) | v2 | 69 | 0,0062 / 0,0131 | 0,0086 / 0,068 | 2,30° / 10,6° | +0 | 69/69 | 69/69 | 66 |
| EE 517 krótki z zawrotem (BO-7) | v3 | 69 | 0,0062 / 0,0131 | 0,0086 / 0,068 | 2,30° / 10,6° | +0 | 69/69 | 69/69 | 66 |
| EE 517 ok. 1,4 pola na stoku | v2 | 60 | 0,0350 / 0,1640 | 0,0667 / 0,370 | 0,00° / 0,0° | -35 | 56/60 | 56/60 | 34 |
| EE 517 ok. 1,4 pola na stoku | v3 | 86 | 0,0000 / 0,0001 | 0,0000 / 0,000 | 0,01° / 0,0° | +0 | 86/86 | 86/86 | 0 |
| AoC 525 krótki (BO-7) | v2 | 81 | 0,0259 / 0,0492 | 0,0317 / 0,069 | 0,02° / 0,9° | -3 | – | 78/81 | 81 |
| AoC 525 krótki (BO-7) | v3 | 81 | 0,0259 / 0,0492 | 0,0317 / 0,069 | 0,02° / 0,9° | -3 | – | 78/81 | 81 |
| AoC 525 ok. 1,9 pola na stoku | v2 | 61 | 0,0022 / 0,0135 | 0,0251 / 0,205 | 0,02° / 0,2° | -3 | – | 60/61 | 17 |
| AoC 525 ok. 1,9 pola na stoku | v3 | 62 | 0,0010 / 0,0148 | 0,0115 / 0,136 | 0,02° / 0,2° | -2 | – | 61/62 | 7 |

Wnioski:
- **EE 500 – cały przebieg:** średni błąd 0,119 → 0,011, maksymalny 0,158 → 0,026, koniec ruchu w tym samym takcie.
  - Do taktu 109 zgodność wynosi 1e-4.
  - Potem rozjazd: drgania ω przy wyrównanym kursie mają w grze inny znak niż w modelu (±α·dt). Znak zależy od błędu
    kursu rzędu 1e-5 rad, czyli od zapisów f32 i UMArcTan2 z DLL (`fizyka_terenu.md` § 6).
- **AoC 505:** średnio 0,006, ale koniec ruchu +15 taktów.
  - Przyczyna: przypadek graniczny decyzji hamowania przy celu. Gra ma d = 0,1739 > S = 0,1736, a model ze względu na
    różnicę pozycji ok. 1e-3 hamuje takt wcześniej, po czym wpada w docisk BO-7.
  - To nie brakujący mechanizm, tylko czułość na precyzję.
- **EE 517 (ok. 1,4 pola na stoku):** model v3 bezbłędny (0 rozbieżnych taktów); v2 bez terenu myli się o 35 taktów.
- **Krótkie rozkazy (BO-7):** model odtwarza wykładniczy dojazd. Pozostały błąd (0,006–0,026) pochodzi z szacowania
  punktu celu z samego przebiegu, bo cel nie jest odczytywany z pamięci (kolejka +0x7C wymaga dwóch dereferencji).
- **Stany i punkt aktywny:** zgodne w 97–100 % próbek. Rozbieżności wynikają tylko z przesunięcia o 1 takt przy
  zdjęciu punktu.

**[Etap 27 – uzupełnione]** Model v4 (UMArcTan2 z tablic DLL, zapisy f32 jak w oryginale, obrót AoC) i pełna tabela
metryk v2/v3/v4: `testy_referencyjne_ruchu.md` § 5. AoC 505 kończy się w tym samym takcie co gra (v3: +15).
