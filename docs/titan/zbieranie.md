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
