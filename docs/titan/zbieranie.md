# Zbieranie surowców przez obywatela (etap 51)

Pierwszy cykl EEUGGather zmierzony w Empire Earth (GOG + NeoEE, e352d7ae…) i odtworzony w OpenEE Core.
Oznaczenia: [P] pomiar, [W] kod, [H] hipoteza, [N] nieznane.

## 1. Pomiar [P: 673 – `e42_e51_zbieranie`]

Obywatel 32 (143,5; 110,5), drzewo 339 (0x1A4C, pole (139, 110), HP 1, +0x40 = 400), Centrum Miasta 35 (146, 110)
2×2. Rozkaz: PPM na pniu drzewa (`ppm_na_obiekt` – kliknięcie w koronę dało EEUGLocation, 670).

1. Próbka po kliknięciu: **MoveToResource 8008**, tryb 0; następnie 8000 (trasa do punktu (140,15; 111,15) – narożnik
   obwodu drzewa odsunięty o r = 0,15), 2015, 10003, …, 9000 → **GatherResource 4004** (tryb 6, v = ω = 0, kurs od razu
   na środek drzewa, licznik +0x2B8 = 4366 = 4400 − 34).
2. Cykl co 4400 ms (= ulepszenie obywatela +0x110, „Wood gather rate”): **pierwszy cykl ścina drzewo** (HP 1 → 0, bez
   drewna), każdy następny: **obywatel +0x40 += 1, drzewo +0x40 −= 1**.
3. Przy +0x40 = 15 (udźwig, ulepszenie +0x14C): NotifyWaitingCitizen 4024 → FindNewStorage 4007 (pierwszy kurs) /
   FindStorage 4021 (kolejne) → **MoveToStorage 8009** → trasa 5 punktów przez środki pól do (145,85; 111,15) → 9000 →
   **AddResourceToStorage 4005: drewno gracza +15, obywatel 0** (w próbce wejścia) → CheckPreviousResource 4016 →
   MoveToWaitingArea 4023 → MoveToResource 8008 → powrót do (140,15; 111,15) → 4004 (drewno od pierwszego cyklu).
4. Dwa pełne cykle w nagraniu (drewno 1222 → 1237 → 1252 po zakończeniu rejestracji).

Kolejność stanów zgadza się w każdym takcie z Gather.tai (przejście na takt).

## 2. Kod Titan [W]

| Element | Adres | Treść |
|---|---|---|
| EEUGGather vtable | 0x831B80 | rejestrator: „? vtable 0x831b80” |
| zdarzenia (vt+0x64) | 0x611420 | 4003 ResourceCapacityFilled (+0x40 ≥ ulepszenie +0x14C), 4005 ResourceCapacityEmpty (+0x40 = 0), 4006 NewResourceFound (cel +0x38), 4008 ResourceDepleted (źródło +0x40 = 0), 4009 ResourceInRange (0x6111BE), 4010 StorageInRange (0x61137E), 4011 StorageFound (cel +0x3C), 4020 StorageDestroyed, 4026 ResourceAccessible, 4028 ResourceTargetIsTree (źródło +0x38 = 3), 5007 GoalIsResource (cel +0x40), 5008 GoalIsStorage (!+0x40 && !+0x41) |
| cykl zbierania (vt[29]) | 0x611801 | źródło żywe → TakeDamage(atak budującego); inaczej źródło −1 (0x61724D), obywatel +1 (0x61624B); okres +0x2B8 = ulepszenie +0x110 + 4·indeks (0x636C96) × współczynnik globalny (poza rodzajem 4) |
| ubytek źródła | 0x61724D | +0x40 −= p; przy 0 i obiekcie Świata – usunięcie z mapy |
| stany (rejestracja 0x618E11) | – | GatherResource 4004, AddResourceToStorage 4005, FindNewResource 4006, FindNewStorage 4007, CheckResourceCapacity 4010, CheckPreviousResource 4016, CheckStorageAccessibility 4020, FindStorage 4021, CheckResourceAccessibility 4022, MoveToWaitingArea 4023, NotifyWaitingCitizen 4024, CheckForOpenPosition 4025, HasResourceGoal 4027, FindFarm 4029, MoveToResource 8008, MoveToStorage 8009 |

Ulepszenie obywatela [P: 665]: +0x110 drewno 4400, +0x114 kamień 8926 (dbobjects 10500 – premia gracza [H]), +0x118
złoto 6000, +0x11C żelazo 6000, +0x120 polowanie 3500, +0x124 zbieractwo 5200, +0x128 farma 4600, +0x14C udźwig 15.

## 3. Core

`dodaj_zrodlo`, `ustaw_magazyn`, `rozkaz_zbierania`; stany i Gather.tai (własny zapis) w skrypcie obywatela;
`krok_zbierania` (0x611801), `zdarzenie_zbierania` (0x611420). Punkty pracy: rozkaz – punkt kliknięcia rzucony na
obwód [H; w odtworzeniu z nagrania]; kolejne – **rzut poprzedniego punktu pracy na obwód drugiego obiektu** (odsunięty
o r) [H: zgodne z 3 punktami 673]. ResourceInRange/StorageInRange – odległość od obwodu ≤ 0,1 [H]. Wybór magazynu –
najbliższy własny budynek z flagą magazynu (Centrum Miasta, dbobjects „Resource type” 1) [H].

Zgodność [P]: odtworzenie 673 od t = 80000 (`opis_zbierania … 80000`, `--od-startu=0`): obywatel 5069/5069 próbek,
Centrum Miasta 5069/5069, drewno gracza, niesione, ilość i HP drzewa – 5069/5069 (`por_zb.py`). Od początku nagrania
pierwsza różnica t = 46534 – zatrzymanie po zwykłym ruchu do punktu w polu drzewa (gra: pozycja zamrożona w 9006/5001
przy v = 0,295, Core hamuje) – ruch, nie zbieranie.

## 4. Niewiadome

Wybór źródła i miejsca przy wielu obywatelach (WaitingArea, OpenPosition), inne surowce (współczynnik globalny tempa,
indeks 0x636C96), farmy, zwierzęta (TakeDamage zamiast ścinania), wyczerpanie źródła i szukanie nowego (FindNewResource),
zniszczenie magazynu – nie mierzono.

## 5. Etap 53 – walidacja w AoC

Pomiar: zadanie 708, AoC (proces c636a2ab…), scenariusz `e42_e51_zbieranie`, nagranie `e53_708_zb` (7286 próbek) [P].
Pierwsze kliknięcie trafiło w teren (zwykły rozkaz ruchu, t = 40431), rozkaz zbierania przyjęty w t = 94638.

| Wielkość | AoC 708 | EE 673 |
|---|---|---|
| klasa celu | vtable 0x8475A8 | vtable 0x831B80 (EEUGGather) |
| stany | 8008 → 8000 → 2015 → 10003 → 9000 → 4004 → 4024 → 4007 → 8009 → … → 4005 → 4016 → 4023 → 8008 | to samo |
| drzewo | HP 1 → 0 po 4398 ms pracy; ilość 400 → 395 → 390 → 385 | to samo |
| rytm | +5 drewna co 22 059 ms (pierwsze po 26 457 ms od wejścia w 4004) | to samo |
| udźwig | 15, potem powrót do Centrum Miasta | to samo |
| oddanie | drewno gracza +15 w próbce wejścia w 4005; ładunek 0 | to samo |
| ponowne podjęcie | 8008 → dojście → 4004 bez nowego rozkazu | to samo |

- Zgodność Core (`--wariant=aoc`, odtworzenie od t = 90000, `--od-startu=0`): obywatel i Centrum Miasta 4783/4783 próbek
  bez rozbieżności; gospodarka (drewno, ładunek, ilość i HP drzewa) 4782/4782 (`porownaj_zbieranie`).
- Odtworzenie od początku nagrania: pierwsza rozbieżność t = 47045 (pozycja 140,5322 / 140,5235, kurs) – koniec
  przypadkowego rozkazu ruchu pod drzewem; ten sam rodzaj co otwarta pozycja EE 673 „zatrzymanie w 9006 przy v ≠ 0”.
  Nie przedstawiam całego nagrania jako zgodnego.
- Wybór źródła i magazynu, inne surowce, kilku zbieraczy – nadal niezmierzone w żadnej grze.

## 6. Etap 54 – kamień, dwóch zbieraczy, punkty pracy

Pomiary: AoC 715 (`e54_715_jeden`, `_dwaj`), EE 716; scenariusz `e42_e54_kamien` – dwóch obywateli, Centrum Miasta
(198, 130) 2 × 2, kopalnia kamienia 38 „Res - Stone Mine” (0x19CE, pole (194, 131), 1 × 1, obiekt Świata kampanii).

### 6.1. Kamień wobec drewna [P]

| Cecha | Drewno (673, 708) | Kamień (715, 716) |
|---|---|---|
| „Resource type” źródła | 3 | 4 |
| stan źródła | HP 1, ilość 400 (drzewo 339) | HP 1, ilość 300 000 |
| pierwszy cykl | zeruje HP (ścięcie), bez surowca | zeruje HP, bez surowca |
| kolejne cykle | źródło −1, obywatel +1 | to samo |
| okres (ulepszenie obywatela +0x110 + 4·i) | i = 0: 4400 ms | i = 1: **EE 8926 ms, AoC 8925 ms** |
| udźwig | 15 | 15 |
| próbka kliknięcia | MoveToResource 8008, bez ruchu | PrepareToMove 8000, już pierwszy krok ruchu |
| wejście w zbieranie | 9000 → 4004 | 9000 → 9006 → 5001 → HasResourceGoal 4027 → 4004 |
| po oddaniu | 4005 → 4016 → 4023 → 8008 → 8000 | 4005 → 4016 → 8008 → 8000 |
| oddanie | zasób gracza +15 w próbce wejścia w 4005 | to samo (kamień: indeks 2) |

- Zdarzenia cyklu w taktach od wejścia w 4004: AoC 262, 524, 787, 1049, 1312, … 3937, 4199; EE 262, 525, 787, 1050,
  1312, … 3937, 4200 – zgodne z licznikiem „−34 ms na takt z przeniesieniem reszty” dla okresu 8925 (AoC) i 8926 (EE).
- Okres odczytany z pamięci ulepszenia obywatela: EE +0x114 = 8926 (716), AoC +0x114 = 8925 (717). Pozostałe pola
  jednakowe: 4400, 6000, 6000, 3500, 5200, 4600; udźwig 15. dbobjects ma 10500 – mnożnik 0,85 gracza [H].
- Wyjście po 15 jednostkach: 4024 → 4007 (pierwszy kurs) / 4021 (kolejne) → 8009, jak przy drewnie.
- Wyczerpanie złoża: nieosiągalne (300 000) – niezmierzone.

### 6.2. Dwóch zbieraczy [P]

- Drugi obywatel dostał rozkaz na tę samą kopalnię, gdy pierwszy wracał z magazynu.
- Każdy pracuje we własnym miejscu: pierwszy (195,15; 131,15), drugi (195,15; 132,15) – różne pola obwodu kopalni.
- Nie wystąpiło oczekiwanie (WaitForOpenPosition) ani MoveToWaitingArea; cykle biegną niezależnie, każdy 15 jednostek
  na kurs.
- Każdy oddaje w swoim miejscu przy Centrum Miasta: (197,85; 131,15) i (197,85; 132,15).
- Kamień gracza: 1333 → 1348 → 1363 → 1378 (trzy dostawy w nagraniu); złoże 300 000 → 299 953.
- Dwóch zbieraczy w **tym samym** polu obwodu (zajęte miejsce) – nie wystąpiło [N].

### 6.3. Punkt pracy i punkt oddania [H: 9 punktów z pomiaru]

Punkt przy obiekcie = pierwsze miejsce (wzór miejsc pola, `produkcja.md` § 6.2 pkt 5) w polu obwodu obiektu
najbliższym polu punktu odniesienia – ta sama reguła co miejsce powstania jednostki z punktem zbiórki.

| Sytuacja | Punkt odniesienia | Pole obwodu | Punkt |
|---|---|---|---|
| kamień, 1. obywatel z (196,5; 128,5) | pozycja obywatela | narożnik (1, −1) kopalni | (195,15; 130,85) |
| → magazyn | (195,15; 130,85) → pole (195, 131) | lewa krawędź, dy = 1 | (197,85; 131,15) |
| → powrót | (197,85; 131,15) → pole (198, 131) | prawa krawędź | (195,15; 131,15) |
| kamień, 2. obywatel z (196,5; 133,5) | pozycja obywatela | narożnik (1, 1) | (195,15; 132,15) |
| → magazyn / powrót | – | narożnik (−1, 2) / (1, 1) | (197,85; 132,15) / (195,15; 132,15) |
| drewno 673 | – | narożnik (1, 1) drzewa, lewa krawędź dy = 1 magazynu | (140,15; 111,15) ↔ (145,85; 111,15) |

- Pole odniesienia dla punktu oddania i powrotu = poprzedni punkt celu zaokrąglony do najbliższej liczby całkowitej
  [H]. Rzut prostopadły z etapu 51 dawał dla kamienia (197,85; 130,85) i rozbieżność od t = 183929.
- Funkcja Titan dla celu zbierania nieodczytana [N].

### 6.4. Rozkaz i stany [P + H]

- Rozkaz (przed taktem) ustawia stan początkowy MoveToWaitingArea 4023. Drzewo: w takcie 4023 → MoveToResource 8008
  (przejście Gather.tai `ResourceTargetIsTree`). Inne źródło: wejście w 4023 przechodzi od razu do 8008, a w takcie
  8008 → PrepareToMove 8000 z pierwszym krokiem ruchu. To wyjaśnia obie próbki kliknięcia jednym mechanizmem.
- Ten sam skrót działa po oddaniu: kamień nie pokazuje stanu 4023.
- [H]: natychmiastowe przejście jest akcją stanu w kodzie (wolne miejsce pracy), nie przejściem Gather.tai. Plik
  Gather.tai obu gier ma te same przejścia co zapis w Core.

### 6.5. Core

- Jeden mechanizm dla wszystkich surowców: `dodaj_zrodlo(…, zasob_typ, zasob_indeks, tempo_indeks)`; indeksy z dbobjects
  („Resource type” 3…6 → zasób typ − 2, tempo typ − 3) – `ParametryTypowDB.zrodlo`. Złoto i żelazo: tylko kolejność pól
  ulepszenia [P: odczyt], cykl niezmierzony.
- `rozkaz_zbierania` ustawia 4023; `wejdz_w_stan(4023)` dla źródła innego niż drzewo → 8008.
- `punkt_przy_obiekcie` (reguła § 6.3) zamiast rzutu prostopadłego w 8008 / 8009.
- Okres kamienia jest parametrem obywatela: `parametry_jednostek_ee.json` → `warianty.aoc` (8925); EE 8926.

### 6.6. Zgodność Core z nagraniami

| Nagranie | Obywatel 1 | Obywatel 2 | Gospodarka (kamień gracza, ładunek, ilość i HP złoża) |
|---|---|---|---|
| AoC 715 jeden (od startu scenariusza) | 5317/5317 | 5317/5317 (stoi) | 5316/5316 |
| AoC 715 oba nagrania łącznie (359 s) | 10423/10423 | 10423/10423 | 10422/10422 dla każdego obywatela |
| EE 716 jeden | 5288/5288 | 5288/5288 | 5287/5287 |
| EE 716 oba nagrania łącznie | 10357/10357 | 10357/10357 | 10356/10356 |
| drewno EE 673 od t = 80000 / AoC 708 od t = 90000 | 5069/5069 / 4783/4783 | – | 5069/5069 / 4782/4782 (bez zmian) |

- Próbka = stan, pozycja, kurs co takt. Nagrania łączne: dwa kolejne nagrania tej samej sesji (przerwa 14 taktów)
  odtworzone jednym przebiegiem Core.
- Test syntetyczny CTest `zbieranie_kamien`: stany, takty cyklu dla 8925 i 8926, punkty oddania i powrotu, +15 kamienia.
