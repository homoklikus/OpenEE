# Walka w Titan – podstawy: cel ataku, cykl ataku, obrażenia, śmierć (EE / AoC)

Wpis atlasu Titan, etap 30 – **początek** rekonstrukcji walki. Zakres: pojedynek dwóch zwykłych jednostek lądowych
walczących wręcz (gwardia królewska, typ 422) oraz gwardia przeciw obywatelowi. Pociski, obrażenia obszarowe,
jednostki specjalne, budynki, morze i powietrze – poza zakresem.

**Oznaczenia:** [P] potwierdzone kodem i pomiarem, [W] wniosek z kodu, [H] hipoteza, [N] nieustalone.
Adresy: EE `Empire Earth.exe` (e352d7ae…), AoC `EE-AOC.exe` (db8fc5ce…). Przesunięcia pól: `dane/titan/struktury_titan.json`
(tabela: `struktury_titan.md`).

## 1. Wynik w skrócie

1. **Obrażenia bezpośredniego trafienia są deterministyczne w EE i w AoC** i liczone wzorem 0x61DE61 [P]:
   `obrażenia = max(1, zaokr(f32(f32(m·w)·atak) − pancerz[rodzaj ataku]))`, gdzie m – tablica trafień zależna od
   poziomu trudności i od tego, czy gracze są ludźmi; w – tablica mnożników klasy celu i rodzaju ataku.
   Pojedynek EE 564: człowiek → komputer 31 (= 15 · 2,1f = 31,4999… → 31), komputer → człowiek 16 (15 · 1,071);
   13 trafień, każde dokładnie jak wzór.
2. **Cykl ataku** (Generic Attack.tai): FaceEnemyUnit (2012) → AttackEnemyUnit (2001) → WaitForReload (2021) →
   Reloaded → 2012. Licznik przeładowania +0x2A0 (AoC +0x2A4) [P]:
   - EE: := parametry+0x138 (2000 ms dla gwardii) przy wejściu w 2001, −34 ms w każdym takcie (także po śmierci),
     Reloaded przy 0 → atak co **60 taktów** (pomiar: 7 + 9 ataków, zawsze 1966 w takcie wejścia);
   - **AoC: czas przeładowania losowy** – fistp(los[a, b] · parametry+0x138) (0x5FEA22, globalny generator
     EEPhysics 0x5612B9); pomiar 570: 1668–2312 ms przy 2000 [P: zmienność; zakres a, b – H: 0,8–1,2].
3. **Moment trafienia**: 1122 ms po wejściu w AttackEnemyUnit (licznik = 878) – w EE i AoC, w każdym z 25
   zmierzonych trafień gwardii [P]. Mechanizm (klatka animacji ataku) [H].
4. **Śmierć**: HP (+0x3C, int) = max(0, HP − obrażenia) w TakeDamage (EEUnit vt+0x70, EE 0x6172BC); przy 0 stan
   Dying (6000) w tym samym takcie, po ok. 2,5 s ResourcesRotting/UnitRotting (6001/6002), po ok. 40 s Dead (6003) [P].
5. **Cel ataku**: obiekt `EEUGAttackUnit` (rodzaj 2) na czele kolejki celów; +0x2C atakujący, **+0x30 atakowana
   jednostka** (wskaźnik na obiekt `EEComplexUnit`), +0x34/+0x38 pole celu przy utworzeniu [P: odczyt 561/564/570].
   Zdarzenia walki ocenia najpierw cel (vt+0x64, EE 0x60B5CB), dopiero potem dispatcher jednostki [W].

## 2. Funkcje (EE / AoC)

| Rola | EE | AoC | Pewność |
|---|---|---|---|
| bezpośrednie trafienie (DealDamage): wzór, mnożniki, wywołanie celu vt+0x70 | 0x61DE61 | – | [W] kod, [P] wyniki |
| obrażenia obszarowe (okno pól, ten sam wzór) | 0x61DAE6 | – | [W] |
| modyfikator wysokości r (typy 5/6 przeciw piechocie…; z różnicy z) | 0x61E500 | – | [W] częściowo |
| tablica trafień wg trudności i ludzi/komputera | 0x4D5F2C | – | [W] |
| TakeDamage (EEUnit/EEComplexUnit vt+0x70) | 0x6172BC | (vt +0x70 wskazuje inną funkcję – układ vtable AoC inny) | [W] |
| SetHitPoints (+0x3C) | 0x616F30 | – | [W] |
| EEHitPointUpgrader – skalowanie HP przy ulepszeniu | 0x638CBF | 0x64F18D | [W] |
| regeneracja HP (co 1000 ms, typ+0x578) | 0x625B47 | – | [W] |
| wejście w stany ataku (EEUGAttackUnit vt+0x40): +0x2A0, animacja | 0x60B26F | 0x61D8DC | [W], [P] wartości |
| ustawienie przeładowania AoC (losowe) | – | 0x5FEA22 | [W] kod, [P] wartości |
| zdarzenia celu ataku (vt+0x64): EnemyUnitDestroyed, UnitNotOnMap, UnitInWeaponRange, FacingEnemyUnit, łuk… | 0x60B5CB | – | [W] |
| UnitInWeaponRange (parametry+0x9C, rozmiary) | 0x5F0CE8 | – | [W] częściowo |
| obrót / łuk ataku do celu | 0x61FC51 | – | [N] |
| konstruktor EEUGAttackUnit | 0x60AD45 | – | [W] |
| animacja (+0x260) | 0x5EFD6D | – | [W] |

Przypadki switch odczytane narzędziem `narzedzia/titan/switch_titan.py` (emulacja wyboru przypadku dla wartości):
- wejście w stan 0x61AD41: 2001 i 2012 → 0x61B5FA (cel vt+0x40), 2013 → 0x61ADD7, 2021 → 0x61AF33, 6000 → 0x61B231;
- zdarzenia celu 0x60B5D9: 2003 EnemyUnitDestroyed → 0x60B60F (HP celu ≤ 0 albo pole celu −10000), 2022 UnitNotOnMap
  → 0x60B62F, 2013 UnitInWeaponRange → 0x60B63E (0x5F0CE8), 2026 EnemyUnitNoLongerVisible → 0x60B64E,
  2027 FacingEnemyUnit → 0x60B724, 2028 EnemyUnitInsideFiringArch → 0x60B68A;
- Reloaded (2044) – dispatcher jednostki 0x61B746: +0x2A0 == 0.

Numery stanów i zdarzeń (tablice rejestracji EE 0x618E11 i 0x617C34, 161 stanów / 238 zdarzeń; AoC 166 / 247):
Idle 5000, CheckRange 2013, FaceEnemyUnit 2012, AttackEnemyUnit 2001, WaitForReload 2021, InitialAttackState 2016,
ShouldIFollowEnemyUnit 2024, ShouldIReturnToInitialContactLocation 2025, UnderAttack 2018, RunFromAttacker 2019,
RetaliateAgainstAttacker 2020, ReacquireGoal 5001, ReacquireEnemyUnit 5002, LookForEnemies 2015, Dying 6000,
ResourcesRotting 6001, UnitRotting 6002, Dead 6003. Zdarzenia: CanISeeEnemy 20002, EnemyUnitDestroyed 2003,
UnitInWeaponRange 2013, Reloaded 2044, EnemyUnitInsideFiringArch 2028, FacingEnemyUnit 2027, CeaseFire 2036,
EnemyWithinMinimumRange 2035, GoalIsUnit 5010, ShouldIRun 20000, ShouldIRetaliate 20001. Numery w EE i AoC są
identyczne dla wszystkich wymienionych [P: kod obu binarek].

## 3. Struktury

| Pole | EE | AoC | Znaczenie | Pewność |
|---|---|---|---|---|
| jednostka +0x3C | ✓ | ✓ | HP (int) | [P] |
| jednostka +0x260 / AoC +0x264 | ✓ | ✓ | animacja: 13 ruch, 0 atak, 7/8 spoczynek, 4 umieranie, 5 gnicie | [P] wartości |
| jednostka +0x2A0 / AoC +0x2A4 | ✓ | ✓ | licznik przeładowania [ms] | [P] |
| jednostka +0x2AC / AoC +0x2B0 | ✓ | ✓ | zerowane przy wejściu w atak i w TakeDamage | [H] |
| jednostka +0x332 | ✓ | – | licznik zabitych | [W] |
| parametry (EEUnitClassUpgrade) +0x9C / +0xA4 | ✓ | ✓ | zasięg maks. / pole widzenia (0,5 / 4,0) | [P] |
| parametry +0xA0 | ✓ | ✓ | promień obrażeń obszarowych (0) | [P] |
| parametry +0xD8 | ✓ | ✓ | atak (15,0, f32) | [P] |
| parametry +0xE0 | ✓ | ✓ | pancerz ×6 (shock, arrow, pierce, gun, laser, missile) = 0/6/0/0/0/0 | [P] |
| parametry +0x138 | ✓ | ✓ | przeładowanie [ms] (2000) | [P] |
| parametry +0x144 | ✓ | ✓ | HP maks. (215) | [P] |
| typ +0x4C0 | ✓ | – | rodzaj ataku (0 = shock) i wiersz klasy celu | [P] wartość |
| typ +0x4C4 | ✓ | – | wiersz tablicy trafień (13) | [P] wartość |
| typ +0x4C8 | ✓ | – | rodzina ataku = dbobjects „Family attack type” (48) | [P] |
| typ +0x494 | ✓ | – | mnożnik ognia bratobójczego | [W] |

Wartości bazy (dbobjects) zgadzają się z parametrami gracza dla gwardii bez ulepszeń [P]: Health 215, Attack 15,
Attack reload time 2,0, Max range 0,5, Line of sight 4,0, pancerze. Wartości „gotowe” są w EEUnitClassUpgrade
gracza – ulepszenia i cywilizacja działają przez nie [W].

## 4. Wzór obrażeń (0x61DE61)

```
U  = parametry atakującego (gracz.0x874 → typ);  atak = U.+0xD8
U.+0xA0 ≠ 0  → obrażenia obszarowe 0x61DAE6 (osobno; tu: 0)
w  = f32 T_8D2050[ cel.typ+0x4C0 · 6 + atak.typ+0x4C0 ]                    // tablica w pamięci (EE 0x8D2050)
m  = 0x4D5F2C(rodzina = atak.typ+0x4C8, klasa = cel.typ+0x4C4, gracze)      // tablica trafień
d  = m·w;  d ≤ 0 → brak trafienia
d  = f32(d·atak) − cel.parametry.+0xE0[atak.typ+0x4C0]
r  = 0x61E500(atakujący, cel):  r > 1 → d = max(r·d, d + 1);  r < 1 → d = min(r·d, d − 1)        [W]
ten sam gracz → d ·= cel.typ+0x494
obrażenia = fistp(f32(d)) (zaokrąglenie do najbliższej), co najmniej 1;  cel→vt+0x70(atakujący, obrażenia, …)
```
- **Tablica trafień** (0x4D5F2C): trzy tablice wskazywane przez 0x8D2008 / 0x8D200C / 0x8D2010, każda: [klasa
  4C4][rodzina 4C8] f32. Wybór zależy od [0x918808] (poziom trudności) i od `gracz vt+0x74` (człowiek) [W].
  Odczyt EE (zad. 566, trudność 0): klasa 13, rodzina 48 → 0x08: 1,071; 0x0C: 1,5; 0x10: 2,1. Pojedynek: człowiek
  (Argos) → komputer (Troja) używa 0x10, komputer → człowiek 0x08 [P]. Pozostałe kombinacje [N].
- **Tablica 0x8D2050** (odczyt 566): wiersze 0–5 = mnożniki 1,0 z jednym 1,5 (wiersz 0: kolumna 2; 1: kolumna 0;
  2: kolumna 1 – „papier-kamień-nożyce”), wiersz 10: 1, 1, 1, 0, 0,8, 0. Wartości ładowane w czasie gry (w pliku EXE
  zera) – źródło (plik bazy) [N].
- **Zaokrąglenie** [P]: 2,1 jako f32 = 2,0999999 → 15 · 2,1f = 31,4999986 → fistp → 31 (gra: 31). Bez f32 wynik
  byłby 32. Core stosuje te same zapisy f32.
- **Obywatel** (cel klasy innej niż gwardia): trafienie 42 (65 → 23), potem 23 → 0 (obcięte do HP). Wartość 42 nie
  została wyliczona – brak odczytu pól typu obywatela [N].
- **AoC**: wzór w kodzie nieprzeczytany; wyniki pojedynku 570: człowiek → komputer 34, komputer → człowiek 15 przy
  tych samych parametrach (atak 15, pancerz 0) – inne wartości tablicy trafień albo inny poziom trudności [N].

## 5. Przebieg pojedynku (pomiar)

**EE 564** (gwardia Argos 0x1000855 kontra gwardia Troja 0x5000AD0, start w odległości 8 pól, rozkaz ruchu w stronę
przeciwnika – atak rozpoczęty automatycznie po wejściu w pole widzenia):
- Troja: CheckRange → ShouldIFollowEnemyUnit → PrepareToMove → podejście (10003/5002/2013/2024 w pętli) →
  FaceEnemyUnit; Argos analogicznie po zatrzymaniu.
- Pierwszy atak Argos t = 60 158 ms, Troja 60 329 (5 taktów później – obrót).
- Trafienia co 60 taktów, zawsze przy liczniku 878: Troja 215 → 184 → … → 29 → 0 (7 trafień po 31, ostatnie 29),
  Argos 215 → 199 → … → 119 (6 trafień po 16).
- Śmierć Troi w takcie trafienia (6000); Argos: ShouldIReturnToInitialContactLocation (2025) → Idle → CheckRange na
  nowy cel (obywatel Troi) w 3 taktach.
- Obywatel po pierwszym trafieniu: UnderAttack (2018) → ucieczka (8000 → 10003); drugi atak go zabija.

**OpenEE Core** odtwarza ten przebieg co takt (HP obu jednostek, licznik +0x2A0, stan) w 786 porównaniach
bez różnicy (`core_walka`, dane lokalne). Wejściem są: parametry z pamięci, m i w z tablic, takt pierwszego ataku
każdej jednostki (obrót – nie modelowany).

**AoC 570**: ten sam przebieg stanów, trafienie 1122 ms po ataku, losowe przeładowanie (§ 1 pkt 2).

## 6. RNG w walce

- EE: przeładowanie i obrażenia bez losowania [P]. Kroki generatora na takt w czasie pojedynku 16–22 (jak bez
  walki – AI i inne systemy).
- AoC: jedno losowanie na każde wejście w AttackEnemyUnit (0x5FEA22 → EEPhysics 0x5612B9) [W: kod; P: zmienność].
- Kolejność jednostek w takcie wpływa na moment trafienia tylko w tym samym takcie; w pomiarze nie wystąpiło [N].
- Core nie dodaje sztucznych losowań; dla AoC przeładowanie losowe nie jest wdrożone (zakres a, b i funkcja
  0x5612B9 – do odczytania).

## 7. Niewiadome i dalsze kroki

1. Wybór celu (CanISeeEnemy, LookForEnemies 2015 – kolejność przeglądania, priorytety) [N].
2. UnitInWeaponRange: pełny wzór odległości z rozmiarami (0x5F0CE8, 0x633541) [W częściowo].
3. Obrót do celu i łuk ataku (0x61FC51) [N]; w Core – takt pierwszego ataku z pomiaru.
4. Pościg, powrót do miejsca pierwszego kontaktu, utrata celu (EnemyUnitNoLongerVisible) [N].
5. Tablice trafień dla pozostałych kombinacji graczy i poziomów trudności; źródło danych tablic [N].
6. AoC: adresy wzoru obrażeń, zakres losowania przeładowania [N].
7. Obrażenia obszarowe, pociski (EEPMProjectile, `projectile.tai`), modyfikator wysokości r [W/N].
