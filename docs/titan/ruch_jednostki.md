# Ruch jednostki lądowej w Titan – stany, takt, prędkość, obrót (EE / AoC)

Etap 25 OpenEE. Dokument opisuje wykonanie trasy przez zwykłą jednostkę lądową w jednym takcie symulacji:
- kod maszyny stanów;
- model fizyki `EEPMLand`;
- pola jednostki i parametry ruchu;
- wzory prędkości i obrotu;
- zdejmowanie punktów;
- warunki zatrzymania.

Co tu nie wchodzi i gdzie to jest:
- trasa w kolejce +0x7C, przeszkody, przejścia Shift, usuwanie punktów +0x32, eksperymenty i model obliczeniowy –
  `ruch_trasa_przeszkody.md`;
- skąd biorą się punkty trasy – `astar_wyniki.md`, `nawigacja_wejscie.md`;
- jak ustawiany jest cel jednostki – `kolejka_rozkazow.md`, `cele_jednostek.md`.

Kompilacje: EE `Empire Earth.exe` e352d7ae…, AoC `EE-AOC.exe` db8fc5ce… (`README.md`).

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

Pomiary to zadania MCP 490–509 (EE) i 504–506 (AoC). Odczyt pamięci w każdym takcie lub co dwa takty, bez
modyfikacji pamięci.

## 1. Architektura: trzy warstwy

1. **Maszyna stanów** (`EEUnitAction`, +0x1E8) decyduje, *co* jednostka robi.
   - Przejścia między stanami sprawdza się co takt.
   - Wejście w stan wykonuje jedną akcję: zdjęcie punktu, wyczyszczenie trasy, ustawienie trybu ruchu.
2. **Tryb ruchu** (+0x264, AoC +0x268) wybiera procedurę fizyki: 0 jazda, 3 spoczynek, 4 stop, 5 obrót w miejscu.
3. **Model fizyki `EEPMLand`** (vtable EE 0x82CFB0, obiekt typ+0x40C) liczy co takt kurs, prędkość i pozycję.

Kod stanów nie liczy ruchu; robi to fizyka według trybu [W]. Tak samo w AoC, z innymi slotami vtable [W].

**[Etap 25 – korekty wcześniejszych założeń]**
- +0x244 to nie prędkość, tylko promień kolizji egzemplarza.
- Bieżąca prędkość jest w **+0x238** [P].
- 0x61AD41 to wspólny dispatcher wejścia we wszystkie stany (typ vt+0x74), nie „wejście w Idle” [W].

## 2. Funkcje

| Rola | EE | AoC |
|---|---|---|
| Takt `EEPhysics` → pętla jednostek (od końca listy) | 0x546C63 → 0x547AAD | 0x553082 → 0x55401E |
| Krok jednej jednostki: maszyna stanów, potem aktualizacja typu | 0x547E0E | 0x5540DC |
| Krok maszyny stanów (najwyżej jedno przejście) | 0x5F0F7E | 0x5FF2E8 |
| Ocena przejścia (lista zdarzeń, AND / OR) | 0x618CCB | 0x62B9A0 |
| Dispatcher wejścia w stan (typ vt+0x74) | 0x61AD41 | 0x62DB0F |
| Dispatcher zdarzeń (typ vt+0x9C; AoC vt+0xA0) | 0x61B677 | 0x62E47A |
| Aktualizacja jednostki lądowej (vt+0xB4; AoC vt+0xB8) | 0x605347 | 0x613ABF |
| Switch trybu ruchu | 0x549F82 | 0x556897 |
| Tryb 0 – jazda po trasie | 0x54D7AE | 0x55A0DB |
| Tryb 4 – hamowanie | 0x54DE35 | 0x55A791 |
| Tryb 5 – obrót w miejscu | 0x54E0F1 | 0x55AA64 |
| Tryb 3 – spoczynek | 0x5488D1 | vt+0x38 [H] |
| Kurs i decyzja skrętu / rdzeń obrotu | 0x5484D9 / 0x548266 | 0x554A25 / 0x554738 |
| Nowa prędkość / decyzja liniowa | 0x54858E / 0x548645 | 0x554BDE / 0x554CB2 |
| Getter vmax / przyspieszenia (z grupą) | 0x46123F / 0x54A4CA | 0x45E407 / 0x554C95 |
| Kolizje i odpychanie (po trybie) | 0x549E61 → 0x5498C4, 0x549A08 | 0x556710 / 0x556213 |
| Bieżący punkt trasy / pozostała długość / zdjęcie punktu | 0x5EC69D / 0x5EC655 / 0x5EDCF4 | 0x5FA229 / 0x5FA1E1 / 0x5FBDD1 |
| Test osiągnięcia punktu (typ vt+0x88) | 0x6213D8 | 0x6353BB |
| Wejście w GetNextMoveWaypoint / PrepareToMove / RepathAroundObstacle | 0x620C31 / 0x6222A8 / 0x6225E7 | 0x634BE6 / 0x63674B / 0x636B69 |
| Zapis transformacji i pola mapy | 0x5F043B | 0x5FE7A8 |

Wszystkie są [W]. Zgodność EE/AoC: logika i stałe identyczne, różnią się przesunięcia pól i sloty (§ 9).

## 3. Pola jednostki i parametry ruchu

**Pola jednostki** (EE; AoC = to samo, chyba że podano inaczej)

| Pole | Typ | Znaczenie | Pewność |
|---|---|---|---|
| +0x1C / +0x20 | int | pole mapy, zmieniane przy zmianie floor(x) / floor(y) | [W] |
| +0x2C / +0x34 | ptr | typ jednostki / obiekt parametrów ruchu (`EEUnitClassUpgrade`) | [P] |
| +0x7C…+0x8C | deque | trasa; +0x88 indeks początku, +0x8C liczba punktów | [P] |
| +0x118 / +0x11C | f32 | pozycja w chwili rozkazu | [P] pomiar |
| +0x130…+0x15C | macierz | orientacja; pozycja x, y, z w +0x13C / +0x14C / +0x15C | [P] |
| kurs | – | atan2(−m[+0x134], m[+0x144]); kurs 0 = +y, dodatni w lewo; ruch dx = −sin(h)·s, dy = cos(h)·s | [P] |
| **+0x17C** | f32 | prędkość kątowa ω [rad/s] (+0x180, +0x184 zerowane) | [P] |
| +0x1C8 | ptr | grupa (parametry szyku zamiast parametrów jednostki, gdy grupa+0xB6 ≠ 0) | [W] |
| +0x1E8 | ptr | obiekt stanu; numer w obiekcie +0x24 | [P] |
| +0x214 | f32 | kurs docelowy; −10000 = brak | [P] pomiar |
| +0x21C | f32 | max(v′, par+0xBC), zapisywane tylko w trybie 0 (tempo animacji [H]) | [W]; pomiar: 0,4 przed pierwszym rozkazem |
| +0x230 / +0x234 | f32 | wektor odpychania [pola/s], całkowany i zerowany co takt | [W] |
| **+0x238** | f32 | bieżąca prędkość liniowa [pola/s czasu gry] | [P] |
| +0x240 / +0x244 | f32 | skala / promień kolizji = typ+0x474·min(skala, 1), co najmniej 0,05 | [P]: 0,5 gwardia, 0,55 Aleksander |
| +0x248 | int | ms ciągłego odpychania (podstawa „ObstacleDetected”) | [W] |
| +0x254 (AoC +0x258) | int | czas następnej oceny stanu w Idle (co 350 ms gry) [Etap 26 – zastąpione: warunek odwrócony, Idle oceniany co takt – `skrypty_stanow.md` § 3, BO-8] | [W] |
| +0x264 (AoC +0x268) | int | tryb ruchu: 0 / 3 / 4 / 5 | [P]: 3 w spoczynku |
| +0x33F (AoC +0x34B) | u8 | „osiągnięto bieżący punkt” (wynik testu z taktu fizyki) | [W] |

**Parametry ruchu** (obiekt +0x34)

| Offset | Rola | Gwardia (typ 422) | Aleksander (typ 173) |
|---|---|---|---|
| +0xA8 | przyspieszenie a, także hamowanie | 2,0 | 2,0 |
| +0xAC | prędkość maksymalna vmax | 0,6 | 0,8 |
| +0xB0 | przyspieszenie kątowe α [rad/s²] | 12,2173 (700°/s²) | 6,9813 (400°/s²) |
| +0xB4 | maksymalna prędkość kątowa ωmax | 13,9626 (800°/s) | 6,9813 |
| +0xBC | dolny próg +0x21C | 0,6 | 0,8 |
| +0xC4 | 1/a | 0,5 | 0,5 |
| +0xC8 | 1/α | 0,08185 | 0,14324 |
| +0xCC | 1/ωmax | 0,07162 | 0,14324 |

Pewność: odczyt pamięci EE 508 [P]; role z kodu [W]; zgodność kroków a·dt i α·dt z pomiarem ruchu [P].
- Gettery (EE 0x5DD355 / 0x5DD373 / 0x5DD391) przy grupa+0xB6 ≠ 0 zwracają grupa+0x70 (vmax), +0x7C (a) i +0x88
  (ωmax) zamiast parametrów jednostki [W]. W ruchu w szyku obowiązuje więc wspólna prędkość grupy
  (`przydzial_specjalny.md`).
- Prędkość deklarowana w typie nie jest używana bezpośrednio. Fizyka czyta parametry przez gettery, a pole +0x21C
  zawiera 0,4 aż do pierwszego taktu jazdy [P].

**Pola typu**

| Pole EE | Pole AoC | Znaczenie | Gwardia | Aleksander |
|---|---|---|---|---|
| +0x474 | +0x178 | rozmiar kolizji, zarazem próg zaliczenia punktu | 0,5 | 0,55 |
| +0x488 | +0x18C | czułość na nachylenie; reguła działa, gdy < 1 | 0,5 | 0,5 |

## 4. Maszyna stanów

**Mechanizm** [W]
- Takt jednostki zaczyna się od kroku maszyny stanów 0x5F0F7E, a dopiero potem jest fizyka.
- Każdy stan ma listę przejść. Przejście to lista numerów zdarzeń z trybem AND / OR i dwa stany docelowe: gdy warunek
  prawdziwy i gdy fałszywy.
- Zdarzenia ocenia dispatcher 0x61B677; dla celu `EEUGLocation` najpierw cel→vt+0x64.
- Na takt zachodzi najwyżej jedno przejście, a po nim akcja wejścia (0x61AD41).
- W Idle maszyna jest oceniana najwyżej co 350 ms czasu gry. *[Etap 26 – zastąpione: w praktyce co takt, BO-8.]*

*[Etap 26: skrypty odnalezione w `data.ssa`; pełna tabela przejść – `skrypty_stanow.md`.]* **Diagram nie jest zapisany w EXE.** Przejścia czyta parser skryptów z katalogu `Unit AI Scripts\` (pliki `.tai`,
0x619B9D). Tablica nazw 0x618E11 to tylko słownik dla tego parsera [W].

Diagram poniżej to zmierzona kolejność obiektów stanu (EE 500, 508) uzupełniona o warunki zdarzeń z kodu.

**Akcje wejścia** (0x61AD41) [W]

| Stan | Akcja wejścia | Pomiar |
|---|---|---|
| 5000 Idle | tryb 3; czyści trasę; zdejmuje cel (0x5EAE25) i aktywuje następny; +0x214 = −10000 | stan spoczynku [P] |
| 5001 ReacquireGoal *[Etap 26]* | akcja 0x61B241 [W] | 1 takt między 9006 a 5000 po obrocie [P] |
| 8000 PrepareToMove | gdy licznik prób celu (cel+0x18) > limitu: przejście do Idle (porzucenie celu); inaczej czyści trasę, zwiększa cel+0x18 i prosi o trasę (0x4A1AFF) | – |
| 9000 GetNextMoveWaypoint | zdejmuje **jeden** punkt z przodu trasy (0x5EDCF4); przy typ+0x5D4 & 2 najpierw test narożnika | 1 takt przy każdym punkcie [P] |
| 9002 RepathAroundObstacle | czyści trasę, sprawdza 4 sąsiednie pola, dopisuje objazd albo prosi o nową trasę *[Etap 26 – uściślone: 4 pola tylko w pościgu; ogólnie synchroniczne A* w oknie ±50 pól – `kolizje_objazdy.md` § 6]* | – |
| 9006 TurnToUnitFacing | tryb 5, chyba że cel ma typ 1 i obrót jest już zakończony | hamowanie i obrót na końcu [P] |
| 10003 Advance | tryb 0; +0x33F = 0 | jazda [P] |
| 10006 Stop | tryb 4 (w AoC brak przypadku) | – |
| 10000–10002, 10004, 10005, 9001, 9003–9005 | brak akcji | 10001 / 10002 nie występują [P] |

**Zdarzenia** (0x61B677) [W]

| Zdarzenie | Warunek |
|---|---|
| 8000 MovePreparationComplete | +0x33E ≠ 0 i +0x8C > 0 |
| 9004 ArrivedAtMoveWaypoint | +0x33F |
| 9005 NextWaypointRetrieved | +0x8C > 0 (przy 0–1 punkcie najpierw dociągnięcie trasy 0x5EB119) |
| 9006 NoMoreWaypoints / 9017 OneWaypointRemaining | +0x8C == 0 / +0x8C == 1, z testami menedżera ścieżek |
| 9000 ObstacleDetected | +0x20C ≠ 0, albo +0x248 > T (`ruch_trasa_przeszkody.md` § 4) |
| 9016 ShouldMoveToNextAutoWaypoint | 0x5F0844 (`ruch_trasa_przeszkody.md` § 6) |
| 9014 UnitFacingNotRequired / 9015 CompletedUnitFacing | cel+0x31 == 0 albo więcej celów w poziomie / obrót ±1° zakończony |
| 8012 CanIMove | vmax > 0,1 |
| 10000–10003, 9001–9003, 9007, 8001, 8011 CannotPathToTarget | dla celu-lokacji zawsze fałsz |

Stany „Accelerate” (10002) i „PrepareToStop” (10001) nie mają dla jednostki lądowej znaczenia. Przyspieszanie i
hamowanie odbywa się wewnątrz trybu 0 [W, P: nie wystąpiły w żadnym pomiarze].

**Diagram rzeczywisty**

Pomiar to kolejność obiektów +0x1E8 w każdym takcie, a numery stanów odczytano z obiektów (+0x24).
```
              rozkaz (cel EEUGLocation, stan 8000 z obsługi grupy)
5000 Idle ───────────────► 8000 PrepareToMove [H: krok nie uchwycony]
                                │ 8000 MovePreparationComplete
                                ▼
                           2015 LookForEnemies ──► 10003 Advance ◄──────────────┐
                                                       │ 9004 Arrived (+0x33F)    │
                                                       ▼                          │
                                          9000 GetNextMoveWaypoint (zdejmuje punkt)│
                                    9005 NextWaypointRetrieved │ 9006 NoMoreWaypoints
                                                       ▼        └──────────┐      │
                                          2015 LookForEnemies ─────────────┼──────┘
                                                                           ▼
                        9006 TurnToUnitFacing (tryb 5: hamowanie, potem obrót w miejscu)
                                                       │ 9015 / 9014
                                                       ▼
                                              5001 (1 takt) ──► 5000 Idle
odgałęzienia z kodu:
  Advance ─9000 ObstacleDetected→ 9002 RepathAroundObstacle → …;
  Advance ─9016→ 8021 GetNextAutoWaypoint (zdejmuje cel) → 8000
```

Pewność diagramu:
- sekwencja 2015 → 10003 → 9000 → 2015 → 10003 przy każdym punkcie oraz 9000 → 9006 → 5001 → 5000 na końcu: [P] (EE
  500; AoC 505 – ta sama liczba taktów);
- odgałęzienia: [H], bo skrypty `.tai` są niedostępne. *[Etap 26 – zastąpione: odgałęzienia odczytane ze skryptów, [W] – `skrypty_stanow.md` § 4.]*

Każdy cykl przy punkcie trwa 3 takty: zdjęcie w 9000, przejście do 2015, powrót do Advance. Kolejny punkt można więc
zaliczyć najwcześniej po 3 taktach [P/W].

## 5. Pseudokod jednego taktu (EE)

Stałe i wielkości:
- dt = EEPhysics+0x8C = 1,5/44 s = 0,0340909 s gry, tps = 1/dt.
- Obliczenia w f32. Tylko sqrt działa w f64 (0x683738).
- Stałe: 0,05 (0x825508), 0,005 (0x82C65C), 1e-4 (0x827AC0), ±π/4 (0x82C5C0 / 0x82B668), 1,9098593 (0x82D008).
```
takt EEPhysics (0x547AAD), jednostki od końca listy:
  jeśli !u+0x33B: krokMaszynyStanów(u)     ; ≤ 1 przejście + akcja wejścia (np. zdjęcie punktu)
  fizyka(u) wg trybu u+0x264

tryb 0 (Advance i stany przejściowe 9000 / 2015, bo tryb ustawia tylko wejście w Advance):
  jeśli trasa pusta: koniec                ; brak ruchu, v i ω bez zmian
  W = przód trasy;  d = |W − P|;  jeśli d < 0,05: d = 0
  -- obrót (0x548266) --
  diff = norm(atan2(−(Wx−Px), Wy−Py) − kurs) do (−π, π]
  n = |ω|/(α·dt);  S_rot = ½·n·(n+1)·α·dt²                ; dyskretna droga hamowania obrotu
  jeśli S_rot < |diff|: ω += sgn(diff)·α·dt, |ω| ≤ ωmax
  inaczej:             ω → 0 o α·dt, bez zmiany znaku
  krok = ω·dt, przycięty do diff;  kurs' = kurs + krok;  u+0x17C = ω
  -- prędkość (0x548645 decyzja, 0x54858E wartość) --
  k = v/(a·dt);  S = ½·k·(k+1)·a·dt²;  jeśli S < 1e-4: S = 0  ; dyskretna droga hamowania
  jeśli |diff| ≤ π/4: tryb = przyspieszaj
  inaczej: X = |½·min(d, 0,5)·ω·dt|;
           tryb = v·dt ≥ X ? hamuj : ((v + a·dt)·dt ≥ X ? trzymaj : przyspieszaj)
  R = (+0x8C > 1) ? pozostałaDługość : d;  jeśli R ≤ S: tryb = hamuj
  jeśli typ+0x488 < 1:  s = clamp(nachylenie·1,9098593, 0, 1);  jeśli v > vmax·(1 − s·typ+0x488): tryb = hamuj
  przyspieszaj: v' = v + a·dt;  jeśli v' > vmax: v' = vmax
                                inaczej jeśli +0x8C == 1 i v' > d: v' = d   ; BO-7
  hamuj:        v' = v − a·dt;  jeśli v' < 0,005: v' = 0
  trzymaj:      v' = v
  u+0x238 = v';  u+0x21C = max(v', par+0xBC)
  -- ruch --
  P += (−sin kurs', cos kurs')·v'·dt       ; po NOWYM kursie
  test przejezdności (0x54E275 – `fizyka_terenu.md` § 4); z = GetMeshZ (0x4C0201 – `fizyka_terenu.md` § 1, [P]); pochylenie, gdy typ+0x5F3 / +0x5F4
  u+0x33F = osiągnięto(u, d)               ; d sprzed ruchu (0x6213D8)
  zapis transformacji, pola +0x1C / +0x20, list kolizji (0x5F043B)
tryb 4: v' = max(0, v − a·dt), ω hamowane, ruch naprzód o v'·dt po dotychczasowym kursie
tryb 5: jeśli v ≠ 0: jak tryb 4; inaczej obrót (0x548266) do kursu celu (cel+0x2C)
tryb 3: jeśli v ≠ 0 lub ω ≠ 0: jak tryb 4
po każdym trybie oprócz 2: kolizje i odpychanie (0x549E61):
  (vx, vy) = (+0x230, +0x234)·k;  pomijane, gdy |vx| + |vy| < 0,02;  przycięte do max(vmax, 0,005/dt)
  P += dt·(vx, vy) z kontrolą pól;  +0x248 += ms;  +0x230 = +0x234 = 0
```

**Liczby całkowite i czas** [W]
- Krok jest stały: dt to stała EEPhysics i nie jest mierzony czas klatki. Nie ma podkroków.
- Pozycja logiczna to macierz +0x130. Rysowanie korzysta z tej samej macierzy, bez interpolacji (`zegar_symulacji.md`).
- Pole mapy, wysokość i listy kolizji aktualizuje się w tym samym takcie, po ruchu (0x5F043B).

## 6. Prędkość – wzory i pomiar

1. **Przyspieszanie i hamowanie** to stałe a = 2,0 pola/s², czyli 0,0682 na takt. Zmierzone kroki: 0,0682 (EE, AoC)
   [P].
2. **Pierwszy takt jazdy** ma v = a·dt = 0,0682 [P]. Do vmax = 0,6 jednostka dochodzi w 9 taktach (0,307 s gry).
3. **Krok przy vmax** to v·dt: 0,02045 pola dla 0,6, 0,02727 dla 0,8 [P]. Ruch po przekątnej nie jest szybszy: kurs
   jest wektorem jednostkowym [P].
4. **Hamowanie przed końcem trasy** zaczyna się, gdy R ≤ S, gdzie S jest dokładną sumą kroków hamowania co takt. Dla
   0,6 S = 0,1002 pola.
   - Pomiar EE 500: hamowanie od d ≈ 0,08 pola, kroki 0,6 → 0,532 → … → 0,0545 → 0.
   - Jednostka staje w punkcie celu z dokładnością pomiaru (181,3540; 104,6001) [P].
5. **Docisk ostatniego kroku** (+0x8C == 1) porównuje prędkość z odległością. Przy obcięciu do vmax w ogóle nie
   działa (BO-7, obserwacja) [W: 0x54861E–0x548636].
6. **Zakręty powyżej 45°.** Przy |diff| > π/4 próg X jest bardzo mały, więc decyzja daje „hamuj”. Jednostka traci
   1–2 kroki a·dt na każdy zakręt ostrzejszy niż 45° [P: spadki 0,6 → 0,532 przy zmianie punktu].
7. **Nachylenie terenu** daje próg vmax·(1 − 0,5·s). Powyżej progu jednostka hamuje, poniżej przyspiesza, co daje
   piłokształtną prędkość 0,6 / 0,532 / 0,464 pod górę [P: pomiar EE 500, AoC 505; reguła z kodu].
   - 61 z 77 spadków prędkości w EE 500 to dokładnie 1·a·dt, 6 to 2·a·dt.
   - Jednostka zwalnia średnio do ok. 0,56–0,57 pola/s.
   - Funkcja nachylenia (0x51216A) – [N]. *[Etap 26 – rozpoznane: asin(Δz/1,3) z punktów ±0,65 wzdłuż osi jednostki, na macierzy sprzed ruchu; model z tą regułą zgodny z pomiarem – `fizyka_terenu.md` § 2–3.]*
8. **Prędkość nie zależy od pozostałej długości trasy**, poza decyzją o hamowaniu. Nie zależy też od odległości do
   punktu pośredniego, poza zakrętami > 45° [W/P].

## 7. Obrót

- Profil jest trapezowy, ze stałym przyspieszeniem kątowym α [P].
  - Zmierzone kroki ω: 0,4165 = 12,217·dt (gwardia) i 0,238 = 6,981·dt (Aleksander).
  - Hamowanie obrotu zaczyna się, gdy dyskretna droga hamowania S_rot ≥ |błąd|.
- Najkrótszy kierunek: błąd jest normalizowany do (−π, π] [W].
- Krok jest przycinany do kąta docelowego. Przy wyrównaniu ω drga między 0 a ±α·dt, bo każdy nowy błąd rzędu 1e-4
  rad znów przyspiesza obrót [P].
- Obrót i ruch są jednoczesne [P]. Przy błędzie > 45° jednostka zwalnia (§ 6), ale nie staje.
- Obrót w miejscu (tryb 5) następuje na końcu, po zatrzymaniu.
  - Kurs docelowy pochodzi z celu (`EEUGLocation`+0x2C), tolerancja ±1° (0x831E5C).
  - Po spełnieniu kurs jest dosuwany dokładnie do celu.
  - Pomiar EE 500: 5 taktów obrotu o 13,8° po zatrzymaniu [P].
- Kurs jednostki (macierz +0x130) to inna wielkość niż kąt θ szyku grupy (`grupy_ruchu.md`), tak samo kurs celu
  +0x214 [W].

## 8. Punkty trasy i zatrzymanie

- **Sterowanie** odbywa się tylko na punkt z przodu kolejki; Titan nie wybiera punktu dalej [W, P].
- **Zaliczenie punktu pośredniego** (+0x8C > 1) [W, P]:
  - warunki: d ≤ typ+0x474 (0,5 gwardia, 0,55 Aleksander) **i** jednostka stoi na tym samym polu co punkt;
  - d i pole są brane sprzed ruchu w danym takcie;
  - przy jeździe prosto oznacza to wjazd na pole punktu, czyli d ≈ 0,48–0,50 [P];
  - po przekątnej to d ≤ 0,5 wewnątrz pola [P];
  - nie jest potrzebny dojazd do środka;
  - punkt znika w następnym takcie (wejście w 9000), więc w pamięci widać go do d ≈ 0,42–0,46 [P].
- **Zaliczenie ostatniego punktu** wymaga d < 0,05 [W, P].
- **Kilka punktów na takt** jest niemożliwe, bo przejście jest jedno na takt, a cykl trwa 3 takty [W, P].
- **Długości narastające** służą tylko do decyzji o hamowaniu: R = długość narastająca ostatniego punktu − poprzednia
  długość narastająca punktu z przodu [W].
- **Koniec**:
  1. Ostatni punkt zaliczony.
  2. 9000 zdejmuje go; tryb 0 z pustą trasą nie rusza jednostki przez 1 takt.
  3. 9006 (tryb 5) hamuje z jazdą naprzód; resztę drogi pokrywa suma kroków hamowania.
  4. Obrót do kursu celu.
  5. 5001, potem 5000 Idle (wejście czyści trasę i zdejmuje cel).

  Pomiar EE 500: zaliczenie przy v = 0,327 i d = 0,021, potem 4 kroki hamowania i stop dokładnie w celu [P].
- **Dlaczego jednostka czasem staje przed celem** – `ruch_trasa_przeszkody.md` § 7.

## 9. EE ↔ AoC

- Logika, stałe i wzory są identyczne [W]. Pomiar AoC 505 (Aleksander) [P]:
  - przyspieszenie 0,0682 na takt;
  - kroki ω 0,238;
  - zaliczanie punktów i sekwencja stanów jak w EE;
  - model z parametrami EE odtwarza ruch.
- Pola jednostki od ok. +0x250 są w AoC przesunięte o +4, a w okolicy +0x330…+0x347 o +0xC. Pola typu są przesunięte
  o −0x2FC [W].
- Sloty vtable EEPhysicsModel w AoC: dodatkowy slot w +0x20, więc prędkość jest w vt+0x24. W EEUnitClass od +0x9C
  wszystko jest przesunięte o +4 [W].
- Dodatki AoC [W/N]:
  - test pola +0x360 w kolizjach;
  - warunek po +0x248;
  - wywołanie z numerem stanu przy wejściu;
  - warunek przed pochylaniem;
  - brak przypadku 10006 Stop w dispatcherze wejścia.

## 10. Niewiadome

- [N] Treść skryptów `.tai`, czyli pełny diagram, nazwa stanu 5001 i to, kto wchodzi w 8000 przy rozkazie. *[Etap 26 – rozpoznane poza wejściem w 8000 – `skrypty_stanow.md`.]*
- [N] Funkcja nachylenia 0x51216A, test przejezdności 0x54E275, wysokość 0x4C0201, rozdzielanie kolizji 0x5498C4. *[Etap 26 – rozpoznane – `fizyka_terenu.md`, `kolizje_objazdy.md`.]*
- [N] Skąd pochodzą wartości parametrów +0xA8…+0xCC (baza jednostek, ulepszenia, loader 0x4D63F1). *[Etap 26 – rozpoznane: rekord bazy jednostek +0x94…+0xA4, init 0x627942, SetSpeed 0x628051; 0x4D63F1 to tablica obrażeń – `kolizje_objazdy.md` § 8.]*
- [N] Ruch w szyku: wartości grupa+0x7C / +0x88 i to, dlaczego po rozkazie z przeciągnięciem pojedyncza jednostka
  jechała ok. 0,40–0,46 i hamowała stopniowo (`ruch_trasa_przeszkody.md` § 8, eksperyment H). *[Etap 26 – rozpoznane: grupa = min(średnia, k·min), w szyku gwardia 0,7 z Aleksandrem; 0,40–0,46 to stok – `kolizje_objazdy.md` § 8, `fizyka_terenu.md` § 3.]*
