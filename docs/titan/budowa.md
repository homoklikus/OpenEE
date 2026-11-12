# Budowa budynku przez obywatela (etap 50)

Atlas cyklu budowy w Titan (Empire Earth, GOG + NeoEE, `Empire Earth.exe` e352d7ae…) i jego odpowiednik w OpenEE Core.
Oznaczenia: [P] pomiar w grze, [W] wywnioskowane z kodu, [H] hipoteza, [N] nieznane.

## 1. Pomiary

| Zadanie | Co | Wynik |
|---|---|---|
| 655 | panel obywatela, formularze UI | przycisk domu w panelu obywatela: piksel okna (1102, 1253) przy 3440×1440 |
| 656 | pierwsza próba budowy | fundament nie powstał – czerwony podgląd (punkt w polu zajętym albo kamera przesunięta po `pokaz_punkt`) |
| 657 | podgląd pod kursorem | stare `klik_w`/`kursor` (ee_api) przeskakują kursorem – zastąpione `ee_ruch.klik` |
| 658 | budowa domu ×2 (`e50_658_ob1/2`, `e50_658_bud1/2`) | pełny cykl w obu przebiegach, identyczne czasy względem rozkazu |
| 659 | budowa + mapa pól (`e50_659_ob`, `e50_659_bud`, `ee_mapa/e50_659_*`) | lista pola, graf przed / w trakcie / po |

Scenariusz: `e42_e50_obywatel.scn` (wariant `e50_obywatel` generatora czystych map: jeden obywatel 32 gracza 1 na
(164,5; 115,5), baza bez zwierząt). Zasoby gracza 1: 1000/1000/1000/500/500, populacja 1/100. Sterowanie: Riverlands_MCP
`budowa_rozkaz` (sterujące – wybór obywatela, przycisk domu, kliknięcie miejsca) i `budowa_odczyt` (obserwacyjne).
Nie zapisywano niczego do pamięci gry.

## 2. Przebieg [P: 658 ×2, 659]

1. Kliknięcie miejsca (164,5; 112,5) tworzy od razu obiekt domu 37 (0x1000856) z kotwicą X = 163, Y = 113: HP 1,
   +0x338 = 1, +0x340 = 0, z = 0. W 659 obiekt jest na liście pola (163, 113) od pierwszego odczytu po rozkazie, graf
   podsektorów bez zmian (+0xD8 = 0, 2 podsektory w oknie 160–168 × 110–118).
2. Obywatel w próbce po rozkazie: stan **8017** (MoveToRepairSite), tryb ruchu 0 (w Idle 3), bez trasy i bez ruchu.
   Kolejne próbki: 8000 (trasa 1 punkt, ruch v = 0,041), 2015, 10003 – jeden stan na takt.
3. Punkt pracy: (164,15; 114,15) – narożnik obwodu fundamentu odsunięty o r = 0,5·rozmiar obywatela (0,3).
4. Dojazd: hamowanie jak przy zwykłym ruchu, w ostatnim odcinku v = min(v + a·dt, d) (docisk ostatniego kroku – reguła
   BO-7 Core), punkt zaliczony przy d < 0,05; pozycja końcowa (164,1687; 114,1957).
5. Stany: 9000 → 9006 → 5001 → **4017** CheckRepairSiteAccessibility → **4012** WaitForBuildSiteToClear →
   **4002** RepairBuilding (każde przejście 1 takt). W próbce wejścia w 4002 kurs = kierunek na środek domu
   (2,7539 → 2,3761, bez obrotu stopniowego), tryb 6.
6. HP domu: +15 co ok. 1000 ms; odstępy w taktach 29, 29, 30, 29, 30, 29, 29, 30, 29, 30, 29, 29, 30, … – pierwszy
   przyrost 29 taktów po wejściu w 4002, 33 przyrosty po 15, ostatni przycięty 496 → 500. Czasy identyczne w trzech
   przebiegach (wejście w 4002 w 54613, ukończenie w 88705 w obu przebiegach 658).
7. Takt po HP = 500: +0x340 = 1, stan **4028** TaskSmartCitizen (cel jeszcze w kolejce), następny takt 5000 (kolejka pusta).
8. Zgłoszenie zmiany mapy przy ukończeniu, nie przy fundamencie: +0xD4 = ukończenie + 15000 ms (658: 88705 + 15000;
   659: 82568 + 15000 = 97568). Po terminie przebudowa jednego sektora: 659 – maks. id podsektora 1604 → 1605,
   w oknie 2 → 3 podsektory.

**HP = postęp budowy.** Nie znaleziono osobnego licznika postępu: pasek budowy to HP obiektu, a ukończenie to flaga
+0x340 ustawiana, gdy HP ≥ HP maks. ulepszenia (+0x144) [P + W: 0x60BD19].

**Losowania** [P: 658 – liczba kroków LCG między próbkami]: poza budową 2 na takt; w ruchu (10003) 3; w takcie
rozkazu 4; w RepairBuilding zwykle 2, a co ok. 1,5 s dodatkowo 2, 4 albo 6 (14 razy w 658_1). Źródło dodatkowych
losowań [N] (prawdopodobnie efekty albo dźwięk pracy – nie wpływają na żadne mierzone pole). Core ich nie wykonuje;
odtworzenie z własnym RNG jest mimo to zgodne we wszystkich polach.

## 3. Kod Titan [W]

| Element | Adres / numer | Uwagi |
|---|---|---|
| EEUGBuildRepair vtable | 0x8319F0 | rejestrator pokazuje cel jako „? vtable 0x8319f0” |
| obsługa zdarzeń celu (vt+0x64) | 0x60D4FD | brak budynku → BuildingDestroyed/BuildingRepaired = prawda |
| 2001 BuildingDestroyed | 0x60D4FD | HP budynku (+0x3C) = 0 |
| 4001 BuildingRepaired | 0x60BD19 | HP ≥ ulepszenie+0x144; przy +0x340 = 0 akcje ukończenia (+0x340 = 1, zgłoszenie mapy) |
| 4014 RepairSiteInRange | 0x60BC54 | nieprzeczytana – w Core koniec trasy [H] |
| 4021 BuildSiteClear | 0x60CED6 | nieprzeczytana – w Core prawda [H] |
| 4022 BuildSiteVisible | 0x60D4FD | LOS² + typ+0x58C ≥ odległość |
| 4023 BuildSiteValid | 0x60D12A | nieprzeczytana – w Core prawda [H] |
| 4030 BuildingNotPaidFor | – | +0x338 (1 = opłacony) |
| 4031 GoalIsBuild | – | cel +0x5A = 0 |
| 4036 / 4037 | – | CannotAffordRepair / RepairIsSpecialUnit – w Core fałsz (naprawa i jednostki specjalne [N]) |
| 5011 GoalIsRepairSite, 5013/5014 OwnerIsHuman/Computer, 4032 BuildQueueEmpty, 4033 SmartTaskNotAssigned, 4024 BuildingInBuildQueue | rejestracja 0x617xxx | numery z rejestracji nazw (push numer, push nazwa) |
| stany citizen.tai | 8017, 4017, 4012, 4002, 4028 [P]; 4013, 4014, 4030 [W] | 8017 MoveToRepairSite potwierdzony pomiarem (wcześniej w Core 8018 [N]) |

Nie przeczytano: funkcji przyrostu HP w RepairBuilding (źródło wartości 15 – obywatel „Build rate” 1000, dom
„Health” 500; wzór [N]), akcji wejścia stanów 8017 i 4002 (tryb 0, kurs na budynek – tylko pomiar), funkcji wyboru
punktu pracy oraz EEMBuildUnit (adres 0x4B6F26 z tabeli nie należy do żadnej procedury w analizie).

## 4. Core (etap 50)

- `Swiat::postaw_fundament` – obiekt budynku HP 1, `ukonczony = false` (+0x340), wpis na listy pól z HP 1, bez
  zgłoszenia mapy.
- `Swiat::rozkaz_budowy` – cel `TypCelu::budowa` (EEUGBuildRepair) z punktem pracy, wejście w MoveToRepairSite (8017,
  tryb 0). `postaw_budynek` (gotowy budynek, etap 48) bez zmian.
- `Swiat::miejsce_budowy` – kandydaci na obwodzie (boki +0,25/+0,75, narożniki, r = 0,5·rozmiar), najbliższy
  przejezdny [P: 1 pomiar; reguła H].
- Skrypt obywatela: część „Building & Repairing” citizen.tai (własny zapis przejść) przed `tekst_land`.
- `zdarzenie_budowy` – zdarzenia z § 3; `BuildingRepaired` przy pierwszym spełnieniu ustawia `ukonczony` i zgłasza
  zmianę mapy z terminem zwykłym (`opoznienie_przebudowy_s` = 1,5 → 15000 ms [P]).
- `krok_budowy` – licznik ms: przy wejściu 1000, co takt −34, przy ≤ 0 przyrost HP i +1000 (daje dokładnie
  zmierzony rytm 29/29/30 [P]; liczba 34 = całkowite ms taktu [H]). Przyrost z `przyrost_budowy` (15 dla 32 → 37,
  `parametry_jednostek_ee.json` → `przyrost_budowy`).
- RepairBuilding (4002): kurs od razu na środek budynku [P].

Zgodność [P]: odtworzenia `odtworzenie_nagrania.py opis_budowy` + `odtworz_scenariusz.gd` – 658_1 2650/2650 próbek
obywatela i 1277/1277 fundamentu, 658_2 2650 (1 próbka nieaktualna) i 1269/1269, 659 3014 (1 rozdarta) i 1813/1813;
także z własnym RNG Core. Graf (`--graf-scn=1`): termin 97568 (659, = gra), przebudowa → maks. id 1605 (= gra);
658: 103704 wobec 103705 w grze (zegar Core zaokrągla start do pełnego ms).

Rozkaz budowy w odtworzeniu wykonywany jest po takcie, w którym nastąpiło kliknięcie (stan 8017 bez przejścia w tej
samej próbce) [P]; rozkazy ruchu i ataku – przed taktem (jak dotąd). Przyczyna różnicy [N].

## 5. Ograniczenia i pytania

- Jeden typ budynku (dom 37, 1 pole), jeden budowniczy, teren płaski, gracz człowiek, brak kolejki budowy.
- Koszt budowy, pobranie zasobów, populacja, odrzucenie miejsca (czerwony podgląd), BuildSiteValid/Clear,
  wielu budowniczych, naprawa uszkodzonego budynku, przerwanie budowy, ukończenie przez AI – [N].
- Wygląd fundamentu i etapy modelu w czasie budowy – nie badano (Godot rysuje gotowy model).
