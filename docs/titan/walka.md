# Walka w Titan – podstawy: cel ataku, cykl ataku, obrażenia, śmierć (EE / AoC)

Wpis atlasu Titan, etap 30 – **początek** rekonstrukcji walki; etap 31 – wybór celu, podejście, obrót, pełny cykl w Core (§ 8–14);
etap 32 – zakończenie obrotu, przycięcie kroku obrotu, cfg wysokości, tablice AoC, mgła (§ 15–19);
etap 33 – morale z budynków (współczynnik 0,8), obrót AoC, rozkaz ataku przez MCP, remisy (§ 20–24). Zakres: pojedynek dwóch zwykłych jednostek lądowych
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
| obrót / łuk ataku do celu | 0x61FC51 | – | [N] [Etap 31 – zastąpione: § 11] |
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
| jednostka +0x2AC / AoC +0x2B0 | ✓ | ✓ | zerowane przy wejściu w atak i w TakeDamage | [H] [Etap 31 – zastąpione: licznik szukania wroga, § 8] |
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
  została wyliczona – brak odczytu pól typu obywatela [N]. [Etap 31 – zastąpione: 42 = 15 · 2,8, § 13]
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
każdej jednostki (obrót – nie modelowany). [Etap 31 – zastąpione: Core sam wybiera cel, podchodzi i obraca się – § 14; `core_walka` zostaje jako test wzoru]

**AoC 570**: ten sam przebieg stanów, trafienie 1122 ms po ataku, losowe przeładowanie (§ 1 pkt 2).

## 6. RNG w walce

- EE: przeładowanie i obrażenia bez losowania [P]. Kroki generatora na takt w czasie pojedynku 16–22 (jak bez
  walki – AI i inne systemy).
- AoC: jedno losowanie na każde wejście w AttackEnemyUnit (0x5FEA22 → EEPhysics 0x5612B9) [W: kod; P: zmienność].
- Kolejność jednostek w takcie wpływa na moment trafienia tylko w tym samym takcie; w pomiarze nie wystąpiło [N].
- Core nie dodaje sztucznych losowań; dla AoC przeładowanie losowe nie jest wdrożone (zakres a, b i funkcja
  0x5612B9 – do odczytania). [Etap 31 – zastąpione: wdrożone, lo/hi = 0,8/1,2 odczytane, § 12]

## 7. Niewiadome i dalsze kroki

1. Wybór celu (CanISeeEnemy, LookForEnemies 2015 – kolejność przeglądania, priorytety) [N].
2. UnitInWeaponRange: pełny wzór odległości z rozmiarami (0x5F0CE8, 0x633541) [W częściowo].
3. Obrót do celu i łuk ataku (0x61FC51) [N]; w Core – takt pierwszego ataku z pomiaru.
4. Pościg, powrót do miejsca pierwszego kontaktu, utrata celu (EnemyUnitNoLongerVisible) [N].
5. Tablice trafień dla pozostałych kombinacji graczy i poziomów trudności; źródło danych tablic [N].
6. AoC: adresy wzoru obrażeń, zakres losowania przeładowania [N].
7. Obrażenia obszarowe, pociski (EEPMProjectile, `projectile.tai`), modyfikator wysokości r [W/N].

---

# Etap 31 – wybór celu, podejście, obrót i pełny cykl

Punkty 1–4 z § 7 zostały w etapie 31 rozpoznane w kodzie EE i sprawdzone pomiarami 578–581 (niżej). Punkt 7
(pociski, obszar) – nadal poza zakresem. Adresy EE; AoC tam, gdzie odczytane.

## 8. Wykrywanie i szukanie wroga (CanISeeEnemy / LookForEnemies)

| Rola | EE | Pewność |
|---|---|---|
| dispatcher zdarzeń jednostki (switch 0x61B6AB) | 0x61B677 | [P] switch_titan |
| CanISeeEnemy 20002: gdy AI[+0x208]+8 (szuka wrogów) → szukanie 0x61AC11; inaczej najpierw 0x61C251 | 0x61BFF4 | [W] |
| EnemyUnitSpotted 5004 | 0x61C00F | [W] |
| szukanie celu (LookForEnemies) | 0x61AC11 | [W] kod, [P] wynik |
| promień szukania r = ceil(max(zasięg·f, LOS)), okno ±r komórek | 0x62EBD2 / 0x62EBEE | [W] |
| przegląd kandydatów po siatce stref EEMap+0x181724 (strefy bliskie, potem dalsze) | 0x63969A | [W]; kolejność w strefie [N] |
| filtr kandydata: inny gracz, dyplomacja gracz+0x9E4[idx] ≠ 0, HP > 0, +0x33B == 0 | 0x639993 | [W] |
| ocena kandydata (funkcja punktowa) | 0x6399CA | [W] kod, [P] wybory 578 |
| mgła/widoczność kandydata dla gracza | 0x631B64 | [W]; reguła pomiarowa [H] |
| utworzenie celu EEUGAttackUnit i wstawienie do kolejki 0x5F05BD | 0x60AD45 | [W] |

Przebieg 0x61AC11 [W]:
1. Pomija szukanie, gdy licznik `+0x2AC` (AoC `+0x2B0`) > 0 – chyba że bieżący cel to miejsce (rodzaj 1) bez
   jednostki docelowej (+0x30 == 0).
2. Wariant „pierwszego kontaktu” (ICL), gdy `+0x214` ≠ −10000, AI+9 ustawione i cel nie pochodzi od gracza.
3. Promień okna jak wyżej; kandydaci z siatki stref; każdy przez filtr 0x639993 i ocenę 0x6399CA.
4. Zwycięzca → `EEUGAttackUnit` (0x60AD45) wstawiony przez 0x5F05BD z flagą „zastąp”, gdy bieżący cel jest
   rodzaju 1, 9 albo 10.
5. Po każdym szukaniu `+0x2AC := typ+0x564` (2000 ms gwardii); licznik maleje o 34 ms na takt [P: pomiar 564, 578, 580 –
   w takcie wyboru celu odczyt 1966].

Ustawienia AI (obiekt +0x208, vtable 0x82AB0C, wspólny dla gwardii i obywatela) [P odczyt 575/578]: +7 pościg poza
miejsce pierwszego kontaktu = 1, +8 szuka wrogów = 1, +9 powrót do ICL = 0, +0xA ucieka = 0.

## 9. Ocena kandydata (0x6399CA)

```
d² = 0x633541(ja, kandydat)                         // DistanceToSquared, środki
d² > +0x44 → odrzuć     (+0x44 = (zasięg·f)² gdy zasięg·f > LOS, inaczej LOS²)
!0x631B64(kandydat, gracz, 1) → odrzuć              // mgła
d² < typ+0x41C² → odrzuć                            // zasięg minimalny
m = 0x4D5F2C(...) ≤ 0 → odrzuć                      // tablica trafień (ta sama co w obrażeniach)
0x637F5A (linia strzału) → odrzuć                   // pomijane, gdy Manhattan ≤ 1
tryb wag: 0 gdy typ+0x61A, 1 gdy zasięg ≤ LOS, 2 inaczej;  W = [0x8CFA28][tryb]  (AoC [0x8E60C0])
wynik = W+0  · (kandydat atakuje mnie)
      + W+8  · (w zasięgu)
      + W+0xC · (AC kandydata < moje)
      + W+0x10 · (int(mój atak) > atak kandydata)
      + W+0x14 · (typ specjalny)
      + fistp(W+0x18 · m)
      + fistp(W+0x1C / d²)
      + W+0x20 · (AC kandydata == 0)
zwycięzca: ściśle większy wynik (remis – pierwszy w kolejności przeglądu);  W+0x24 – próg przerwania przeglądu
```
Wagi odczytane (EE = AoC, zad. 575 / 580) [P]:

| tryb | +0 | +4 | +8 | +0xC | +0x10 | +0x14 | +0x18 | +0x1C | +0x20 | +0x24 |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 (wręcz, typ+0x61A) | 2 | 1 | 50 | 1 | 1 | 0 | 1 | 50 | −500 | 50 |
| 1 (zasięg ≤ LOS) | 15 | 20 | 30 | 6 | 6 | 0 | 1 | 2 | −500 | 15 |
| 2 (zasięg > LOS) | 10 | 15 | 50 | 4 | 4 | 0 | 1 | 0 | −500 | 15 |

Znaczenie +4 i dokładna rola +0x20/+0x24 – [W] częściowo. **Remisy i kolejność**: lista stref obracana o
[0x919774]+0xB0 [N]; Core przegląda kandydatów w kolejności własnej listy jednostek i oznacza to jako założenie [N]
(diagnostyka `zalozenia_walki`). Osiągalność celu 0x62D696 – [N], w Core nie sprawdzana.

**Widoczność** (0x631B64 – mapa mgły gracza): pomiar 578/579 zgodny z regułą „odległość środka komórki kandydata
≤ LOS” [H]; mapa mgły nie jest jeszcze odczytywana.

**Różnice EE/AoC**: wagi i progi identyczne [P]; AoC – licznik szukania +0x2B0, tablica wag 0x8E60C0 [P].

## 10. Podejście i pościg (PrepareToMove 0x6222A8 → cel vt+0x08 0x60AF05)

- **Cel w ruchu** (v > 0): punkt przechwycenia 0x62C963, użyty tylko gdy trasa celu ma > 1 punkt (+0x8C > 1),
  inaczej dokładna pozycja celu [P: 578 takt 2076 – (177,1906; 106,795) bitowo].
  Równanie UMQuadraticEquation: A = va² − vt², B = 2·cos·vt·d, C = −d², d – odległość 3D. Kod zawiera dwa błędy
  dodawania (BO-10): |Da| = sqrt(dx² + dy² + 2dz), iloczyn = Dty·Day + Dtz + Daz + Dtx·Dax; punkt bieżący trasy
  bierze z = 0. Punkt = pozycja celu + r·vt·kierunek.
- **Cel stojący**: 0x62CF6A (typ 61A): w zasięgu → własna pozycja; inaczej 0x632CF4 → gdy celu ulepszenie+0xAC > 0
  → 0x63234D: 8 slotów na okręgu R = 0,5·s_ja + 0,5·s_cel, sortowane wg odległości od atakującego, pierwszy
  przejezdny [P: 578 takt 2018].
- Następnie 0x60B9D8 ustawia pole celu (+0x34) na pole jednostki docelowej [P].
- Ruch używa tej samej kolejki celów i tej samej nawigacji co rozkaz ruchu – w Core zdarzenie 8000 dla celu
  „jednostka” liczy punkt podejścia i dalej działa zwykły PrepareToMove/A*.

## 11. Zasięg, łuk i obrót (0x5F0CE8, 0x61FC51)

- **UnitInWeaponRange** 0x5F0CE8; dla typ+0x61A (walka wręcz/punktowa): 0x631935 → 0x631501:
  `4·d² < ((0,05·1,42 + s_ja + s_cel)·1,42)²` – dla gwardii próg 0,7604 [P vs 564/578].
- **FacingEnemyUnit / InsideFiringArch** 0x61FC51 → 0x61FCAF: kąt = |UMArcCos(przód · do_celu)|, przód =
  macierz·R(typ+0x458)·(0, 1, 0). „Zwrócony” gdy kąt ≤ 0,0436332 (2,5°); „w łuku” gdy kąt ≤ typ+0x45C / 2.
  Gwardia: łuk 0,349066 (20°) [P odczyt typu]; 2π = zawsze w łuku.
- Wejście w FaceEnemyUnit (2012): tryb fizyki +0x264 := 1, animacja 13 gdy nie zwrócony, 0x5E9770 czyści trasę [P].
  Tryb 1 (EEPMLand vt+0x10 0x54DA82): obrót do celu przez vt+0x1C z flagą 1 (0x548266 z przesunięciem +0x458),
  hamowanie v' = max(0, v − 1,0·dt·a) [P: S1–S7 bez zmian, 578 bitowo do ok. 50 taktu].

## 12. Przeładowanie AoC (0x5FEA22)

`przeładowanie = fistp(f32((lo + r·(hi − lo)) · bazowe))`, r – kolejne losowanie globalnego LCG EEPhysics,
lo/hi = [[0x92FCA8]+0x984 / +0x988] = **0,8 / 1,2** [P: odczyt 580]. Sprawdzenie na prawdziwym ciągu generatora:
pomiar 580 – 27/27 przeładowań (okno 580_g1: 14/14) powstaje z jednego kroku LCG osiągalnego w danym takcie [P].
EE: stałe przeładowanie (ulepszenie+0x138) [P]. Core: `WariantTitan::aoc()` → losowanie `rng_.losuj()` przy wejściu
w 2001, EE – bez losowania.

## 13. Obrażenia klas i modyfikator wysokości

- **Gwardia → obywatel 42** = 15 · 2,8 (tablica 0x10, klasa 36 obywatela, rodzina 48) [P]. Obywatel: typ+0x4B4 = 6,
  +0x4C0 = 5, +0x4C4 = 36, +0x4C8 = 38, rozmiar 0,3, typ+0x61A = 0; zasięg 2,0, LOS 3, AC 0,5, atak 5, HP 65 [P].
- **Modyfikator wysokości** 0x61E500 (AoC 0x631918) [W kod, P skutek]: gdy typ jednostki atakującego ∈ {5, 6}
  i typ celu ∈ {2, 5, 6, 13, 15, 16, 19, 23, 24, 25, 29}: dz = z_atak − z_cel, k = 0,408248;
  dz ≥ cfg+0x5CC·k → r = gracz+0xA3C + cfg+0x604; dz ≤ −cfg+0x5E8·k → r = cfg+0x620; inaczej 1;
  cfg = [0x917BB8] (EE). Pomiar 578 G3: gwardia 857 na zboczu otrzymała 13 zamiast 16 [P skutek]. Wartości cfg nie
  zostały odczytane (zadania 582–584 nie przeszły odprawy) [N] – Core: r = 1 i założenie w diagnostyce.
  [Etap 32 – zastąpione: cfg odczytane (§ 16); z obu jednostek w 578 G3 różni się o 0,01, więc „13 zamiast 16” nie
  wynika z modyfikatora wysokości – przyczyna [N], § 16]
- **AoC**: gwardia komputer → człowiek 15, człowiek → komputer 34, na zboczu 12 [P pomiar 580]. Tablice AoC pod
  0x8E8750 / 0x8E870C / 0x8E8708 / 0x8E8710, trudność 0x931248 [W adresy] – wartości nieodczytane [N].
- **Niewyjaśnione** [N]: EE 579 – trafienie obywatela 21 przy dz ≈ 0 (oczekiwane 42); AoC obywatel 36/23.

## 14. Pełny cykl w OpenEE Core (Swiat)

Core sam wykonuje: szukanie (licznik 2000 ms) → ocena → cel EEUGAttackUnit w kolejce celów → podejście (8000 →
punkt przechwycenia/slot → A*) → CheckRange (2013) → FaceEnemyUnit (2012, tryb fizyki 1) → AttackEnemyUnit (2001) →
trafienie po 1122 ms → WaitForReload (2021) → Reloaded → … → śmierć celu (EnemyUnitDestroyed) →
ShouldIReturnToInitialContactLocation (2025) → Idle. Moment ataku **nie jest** parametrem.

Porównanie z grą (`core_walka_swiat`, dane lokalne; Debug = Release):

| okno | porównań | pierwsza różnica | przyczyna |
|---|---|---|---|
| 578 G1 (1:1 EE, Argos rozkaz ruchu, Troja stoi) | 986 | takt 48 – stan ruchu 9006 vs 5001 | CompletedUnitFacing (reguła ω == 0) o 1 takt; dalej przesunięcie szukania (takt 50) |
| 578 G3 (2:1 EE, rozkazy ataku, druga gwardia dołącza w takcie 230) | 1287 | takt 53–58 | dryf kolizji 0,003 → atak o 1 takt później |
| 580 G1 (1:1 AoC) | – | – | brak tablic obrażeń AoC – symulacja SKIP; przeładowania 14/14 |

Wynik: przebieg jakościowy zgodny (te same cele, te same rodzaje zdarzeń, liczba trafień 6/6 w G1), ale **nie
bitowy** – rozjazd czasowy o 1 takt od ok. 50 taktu, różnica HP w 42 próbkach (G1). Zgodność: wybór celu i
punkt podejścia – dokładne; obrót i cykl – model; 1:N – częściowe; AoC – brak danych.

---

# Etap 32 – zgodność cyklu z Titanem, komplet odczytów EE/AoC

## 15. Zakończenie obrotu i przycięcie kroku obrotu (pierwsza rozbieżność 578 G1)

Etap 31: w 578 G1 pierwsza różnica w takcie 48 (gra 9006 → 5001 takt wcześniej niż Core). Przyczyny – trzy reguły
modelu v4 niezgodne z kodem Titan:

1. **CompletedUnitFacing** (zdarzenie 9015) – EEUGLocation vt+0x64 0x6153A3 → **0x614F52** [W kod, P pomiar]:
   kurs = UMArcTan2(−x, y) wektora M·(0, 1, 0) minus kurs celu (+0x2C, f32), zawinięcie stałymi f32 (−π 0x82ACE0,
   π 0x828020, 2π 0x828018), |Δ| ≤ f32 0,017453292 (0x831E5C) → **macierz ustawiana dokładnie na kurs celu**
   (0x5F043B) i prawda. **Bez warunku v = 0 i ω = 0** (model v4 go wymagał). Sprawdzenie na 189 taktach stanu 9006
   z 11 pomiarów EE/AoC (e30/e31): reguła 0x614F52 – 188 zgodnych, reguła modelu v4 – 171. Jedyny wyjątek
   (581, 0x1000857, próbka 4290) przechodzi wprost do 5000 – inne przejście [N].
2. **Przycięcie kroku obrotu** (koniec 0x548266, 0x548477–0x5484B5) [W kod, P pomiar]: krok = f32(ω′·dt); zamiana
   na Δ tylko gdy Δ < 0 i krok < Δ albo Δ > 0 i krok > Δ. **Przy Δ = 0 krok nie jest przycinany** – jednostka
   „przestrzeliwuje” kurs o ω′·dt i wraca w kolejnych taktach (oscylacja ±0,4165 rad/s widoczna w pomiarach).
   Model v4 przycinał także przy Δ = 0.
3. **Tryb 4 (hamowanie, 0x54DE35 → 0x548920)** [W kod, P pomiar 578]: ω hamowane o α·dt, **kurs′ = f32(ω′·dt + kurs)**
   i krok wzdłuż nowej macierzy; gdy ω′ = 0 i v′ = 0 – brak zapisu. Model v4 nie obracał w trybie 4. Tryb 3
   (0x5488D1) przy v ≠ 0 albo ω ≠ 0 wywołuje tryb 4 (vt+0x4C).
4. **5001 ReacquireGoal nie zmienia trybu ruchu** [P: 578 – tryb 5 w 5001]; Core ustawiał spoczynek.
5. Tryb 5 nie zeruje ω przy |Δ| < 1° [P: ω ≠ 0 w takcie przejścia 9006 → 5001 we wszystkich 188 przypadkach].

Skutek w Core (dane lokalne, Debug = Release):

| Porównanie | Etap 31 | Etap 32 |
|---|---|---|
| 578 G1 (EE 1:1), 986 porównań | pierwsza różnica takt 48; stan 73, HP 42 | **brak różnic**: stan 0, HP 0, +0x2A0 0, cel 0, pozycja maks. 0,0000, ω 0, kurs ≤ 0,00018 rad (odczyt atan2 vs UMArcTan2) |
| EE 500 (ruch z obrotem końcowym, 813 próbek) | pozycja śr./maks. 0,0082 / 0,0497; v maks. 0,332; inny stan 21 | **0,0072 / 0,0205; v maks. 0,068; inny stan 17**; koniec ruchu +1 takt [N] |
| AoC 505, EE 517, AoC 525 | – | bez zmian |

Przypadki syntetyczne S2, S4, S4b, S5 (wyniki modelu v4, nie pomiary) przeliczono z Core – pole `zmiana_etap32`
w `dane/testy_ruchu/ruch_syntetyczne_etap27.json`; S1, S3, S5a, S6, S7 bez zmian bitowo. Skrót zbiorczy
c36721320b3595e4 → 13b25b683deb815f.

## 16. Modyfikator wysokości – konfiguracja z gry

Odczyt 587 (EE) i 588 (AoC) [P]: EE cfg = [0x917BB8], AoC cfg = [0x92FCA8] (ten sam obiekt co granice przeładowania
AoC); w obu: +0x5CC = 2,0, +0x5E8 = 1,0, +0x604 = 1,5, +0x620 = 0,8; premia gracza (EE +0xA3C, AoC +0xA34) = 0.
Progi: dz ≥ 2,0·0,408248 = 0,8165 → r = 1,5; dz ≤ −0,408 → r = 0,8. AoC 0x631880: ta sama budowa, rodzaj typu
+0x1B8, dodatkowo rodzaj celu 30 [W]. Rodzaj atakującego ∈ {9, 11, 12, 20} → rodzaj i z obiektu +0x1C0 / +0x210 [W]
(w Core nieobsługiwane – piechota). Core: `ModyfikatorWysokosci::z_gry(aoc)`.

**Korekta etapu 31:** „857: 13 zamiast 16” i „AoC 12 zamiast 15” mają stosunek dokładnie kary 0,8
(min(0,8·d, d − 1)), ale z jednostek w 578 G3 (ad3 0,00; 857 0,01 – pole +0x15C) nie spełnia progu −0,408.
Przyczyna [N]; to samo dotyczy EE 579 (obywatel 21 zamiast 42). [Etap 33 – zastąpione: morale z budynków, § 20] Plan: odczyt argumentów 0x61E500 i 0x61DE61
w takcie trafienia (rejestracja +0x15C atakującego i celu oraz wyniku r).

## 17. Tablice obrażeń AoC

Odczyt 588 (AoC, trudność 0) [P]: tablica 0x0C taka sama jak w EE; 0x08 = 0x0C · 2/3; 0x10 = 0x0C · 1,5
(EE: 0x08 = 0x0C · 0,714, 0x10 = 0x0C · 1,4). Gwardia (klasa 13, rodzina 48): 0x08 1,0; 0x0C 1,5; 0x10 2,25 →
człowiek → komputer 15 · 2,25 = 33,75 → 34, komputer → człowiek 15 [P: pomiar 580]. Adresy AoC: wskaźniki
0x8E870C / 0x8E8708 / 0x8E8710, mnożniki 0x8E8750, trudność 0x931248 [P odczyt]. Wybór tablicy (człowiek/komputer)
– jak EE [W, zgodny wynik].

Symulacja okna 580 G1 (AoC) w Core działa już na tablicach z gry: 1138 porównań, trafień 14 (gra 14). Pierwsza
różnica: takt 35 – **artefakt pomiaru** (powtórzona próbka gry); pierwsza prawdziwa: takt 36 – ω (oscylacja kursu
AoC przy Δ ≈ 0, reguła AoC 0x554738 nieprzeczytana [N]); przeładowania różne, bo ciąg LCG gry zużywają też inne
systemy (wzór 0x5FEA22 – 14/14 na prawdziwym ciągu).

## 18. Mgła i przegląd kandydatów (statyka)

- **0x631B64** [W]: gdy brak menedżera mgły [0x9183BC] albo gracz+0x466 == 0 → widoczny. Inaczej (typ+0x58C ≤ 1
  i rodzaj ≠ 25) pole kandydata (+0x1C/+0x20) → kafel mgły 0x40DD00 → 0x44E46E: licznik widoczności gracza
  (8 bitów, dwa gracze na słowo) > 1 albo gracz+0x465 ≠ 0. **Warunek wykrycia = pole kandydata obecnie widoczne dla
  gracza (dowolna jego jednostka)**, nie tylko dla szukającej. Odczyt 587/588: gracz+0x466 = 1 dla gracza 1 i 5 [P].
  Core: `widoczny_dla` – dowolna jednostka gracza, odległość pól ≤ LOS [H co do kształtu odsłaniania].
- **0x63969A + 0x40CFC7** [W]: lista stref kandydatów jest permutowana funkcją 0x40CFC7 z kluczem
  [0x919774]+0xB0 (obiekt EEPhysics; pole +0xB0 – prawdopodobnie licznik czasu [H]): s = k mod n, zamiany
  a[i] ↔ a[s] i dalsze zamiany z indeksem n − s − 1, s := (2·(n − s − 1) + 1) mod n (szczegóły permutacji [H]);
  przegląd od końca listy. To jest
  mechanizm remisów – kolejność kandydatów zależy od czasu gry. Nie wdrożone (brak pomiaru +0xB0) [N].
- **0x62D696** (osiągalność) – nieprzeczytana [N]; w Core prawda (założenie w diagnostyce).

## 19. Eksperymenty etapu 32

| Zadanie | Cel | Wynik |
|---|---|---|
| 585–586 | gotowość pulpitu, inhibitor | KDE Wayland; LockedHint no, wygaszacz nieaktywny; `kde-inhibit` działa [P] |
| 587 (EE), 588 (AoC) | tablice, wagi, cfg, typy, rozkaz ataku | start przez odprawę bez problemu (inhibitor); cfg, tablice AoC, wagi [P]; rozkaz ataku – nieudany (PPM na wrogu daje EEUGLocation albo nic; wróg prawdopodobnie we mgle) |
| 589 (EE) | rozkaz ataku na dalszego wroga, odwrót | wybór atakującego nieudany (kadr kamery); odwrót wydany po walce – nie sprawdza LOS |
| 590 (EE) | odwrót w trakcie walki, rozkaz ataku po odsłonięciu | pojedynek 855–ad0 zakończony śmiercią ad0 przed rozkazem odwrotu (855 wygrał w ok. 14 s) – odwrót z Idle, bez pościgu; rozkaz ataku 856 → ad2: PPM daje EEUGLocation (wróg widoczny na ekranie) [N]; nowe okno testowe 590 G1: stan, HP, przeładowanie i cel bez różnic w 1110 porównaniach |

Wniosek dla etapu 33: odwrót trzeba wyzwalać zdarzeniem (pierwsze trafienie), nie czasem; rozkaz ataku wymaga
sprawdzenia obiektu pod kursorem z pamięci gry przed PPM.

---

# Etap 33 – dokładne obrażenia, obrót AoC, rozkaz ataku

## 20. Współczynnik 0,8 = morale z budynków (EEAEMoraleFromBuildings)

Pełna ścieżka trafienia wręcz [W kod EE, P wyniki]:

```
DealDamage 0x61DE61 (this = typ atakującego, arg1 = atakujący, arg2 = cel):
  typ ataku = atakujący+0x1C0 albo this; U = parametry gracza (gracz+0x874)[typ+0x4B8]; atak = U+0xD8
  U+0xA0 ≠ 0 → obszar 0x61DAE6
  w = f32 T_8D2050[cel.typ+0x4C0·6 + typ+0x4C0];  m = 0x4D5F2C(rodzina, typ celu, gracz celu, gracz atakującego)
  d = f32(m·w·atak) − cel.parametry+0xE0[typ+0x4C0]
  r = 0x61E500(atakujący, cel): r ≠ 1 → r > 1: max(r·d, d + 1); r < 1: min(r·d, d − 1)
  obr = max(1, fistp(f32(d)))
  ten sam gracz albo sojusz: atakujący+0x200 ≠ 0 → ceil(obr·0,1) (0x832090), inaczej 0
  cel vt+0x70 (TakeDamage 0x6172BC)(atakujący, obr, gracz, 1)
TakeDamage:
  (cel+0x30)+0x1CC ≠ 0 → przekazanie dalej; flaga [0x918EA0] / +0x33B → bez obrażeń
  arg4 ≠ 2 → 0x664EA1: wektor modyfikatorów celu (+0xF8: +0x100…+0x104); każdy: vt+0x30(1, obr, &wynik) –
      wynik liczony z TYCH SAMYCH obr i nadpisywany (modyfikatory się nie kumulują – ostatni wygrywa) [W]
      [Etap 34 – doprecyzowane] vt+0x30 zapisuje wynik tylko dla efektów morale; po usuwaniu nadmiarowych (§ 25.5)
      na liście zostaje co najwyżej jeden efekt morale, więc „ostatni wygrywa” nie występuje w grze [P: kod]
  0x5EDCA4: wynik −= fistp(obr·0,8) gdy +0x2C4 > 0; wynik += fistp(obr·0,6) gdy +0x2C8 > 0 [W]
EEAEMoraleFromBuildings vt+0x30 (0x6640BA):
  n = min(+0x24, +0x20) (vt+0x4C 0x664202), obcięte do 0…10
  wynik = obr − fistp(f32(n · 0,1f · obr))                       (0x827810 = 0,1)
```

Pomiar [P]:
- Odczyt `walka_modyfikatory` (591 EE, 596 AoC, 593 EE b): w scenariuszu e31_a gwardie 857 i 858 (gracz 1) mają
  jeden modyfikator `EEAEMoraleFromBuildings` (budynek w (185, 110), +0x20 = +0x24 = 2 → poziom 2); pozostałe
  jednostki – brak.
- Wszystkie trafienia z 6 pomiarów (578, 579, 580, 581, 587, 589): każde zmniejszone trafienie (poza dwoma
  przypadkami [N] niżej) ma w chwili trafienia niepusty wektor +0x100/+0x104, każde pełne – pusty. 857: EE 16 → 13 (= 16 − fistp(3,2)), AoC 15 → 12
  (= 15 − 3); obywatel w (164,5; 101,5) przy budynku Troi: 42 → 21 (poziom 5 [W] – poziomu w tej chwili nie
  odczytano).
- Modyfikator wysokości 0x61E500 w tych trafieniach zwraca 1 (dz ≈ 0,01) – hipoteza z etapu 31 obalona.
- [N]: 856 w 589 (takt ~5841) otrzymuje 18 bez modyfikatora – inny atakujący (kilku jednocześnie), nieustalony;
  AoC obywatel 36 → 23 (poziom niepasujący do 36 – inny atakujący [H]); 857 w 589 późne trafienia 14.

Core: `BojJednostki::morale` (poziomy modyfikatorów), `obrazenia_po_modyfikatorach` (0x6640BA, ostatni wygrywa),
`Swiat::ustaw_morale`. Źródła morale (budynki, zasięg, maksimum) – poza Core [N]; w testach poziomy z odczytu.
578 G3: różnice HP 384 → 59, pierwsza różnica HP przesunięta z taktu 102 na 334.

## 21. Obrót AoC (0x554738) i reguły EE

Rdzeń obrotu AoC 0x554738 ma tę samą budowę co EE 0x548266 (to samo przycięcie kroku 0x5549C3, bez przycięcia przy
Δ = 0). Różnią się gałęzie zmiany ω po decyzji 0x554F56 [W kod, P pomiar]:
- kod 3 (0x554980): Δ < 0 → ω − ad (≥ −ωmax), **inaczej, także przy Δ = 0**, ω + ad (≤ ωmax);
- kod 4 (0x5548D6): ω < 0 → ω′ = ω + ad, przy Δ < 0 co najmniej −ad, przy Δ = 0 zero gdy ω′ > −0,001;
  ω ≥ 0 → ω′ = ω − ad, przy Δ > 0 co najmniej +ad, przy Δ = 0 zero gdy ω′ < 0,001. **Przy ω = 0 i Δ ≠ 0
  jednostka zaczyna obrót (±ad)** – Core (model v4) dawał 0;
- ad zapisywane jako f32 (fst), próg 0,001 = f32 0x84237C.
Skutek: AoC 505 – pierwszy rozbieżny takt 224 → **803**, kąt śr. 0,12° → 0,00°; 580 G1 – kurs i ω zgodne
w oknie (pierwsza różnica stanu w takcie 57 to spóźniona próbka stanu gry, pozycja identyczna; pierwsza
rzeczywista – przeładowanie 146: ciąg LCG zużywany także przez inne systemy gry). AoC 525 1,9 pola: pierwszy takt
bez zmian (68), metryki po nim +0,00002 pola. S5a (model v4 AoC) przeliczony (`zmiana_etap33`).
EE 500 +1 takt końca ruchu – nie wyjaśnione [N]; reguła EE (0x54880E) nie ma odpowiednika zmienionych gałęzi.

## 22. Rozkaz ataku przez Riverlands_MCP

`walka_atak_weryfikowany`: kamera na parze atakujący–cel, piksel celu potwierdzany zaznaczeniem gracza (LPM),
wybór atakującego w tym samym kadrze, PPM w potwierdzony piksel, kontrola EEUGAttackUnit w kolejce, maks. 3 próby
z zapisem powodu. Wynik 594: **piksel celu nie został potwierdzony** (zaznaczenie gracza pozostaje puste po LPM na
wrogu) – wróg był we mgle (856 nie doszedł do zadanego punktu: punkt PPM różni się od zamierzonego o ok. 2 pola,
z terenu przyjęto z = 1,84) [P]. 597/598 (cel widoczny, w kadrze, 1,4–1,75 pola od atakującego): **LPM na wrogu nie zmienia
zaznaczenia gracza** (lista pozostaje pusta) – weryfikacja przez zaznaczenie działa tylko dla własnych jednostek [P].
Rozkaz ataku przez MCP nadal nieosiągnięty; następny krok: wskaźnik „obiekt pod kursorem” z pamięci (różnicowy
odczyt przy kursorze nad celem / poza nim).

**Wycofanie w trakcie walki (601)** [P] – wyzwalacz zdarzeniem (`walka_czekaj_na_stan`: 2012/2001), rozkaz
ruchu bez ponownego wyboru: 855 (HP 103) dostaje rozkaz w stanie 2021 i odchodzi ok. 10 pól. ad0 (AI, HP 29)
**ściga go przez całą drogę** (pętla 10003/5002/2013/2024/8000, poza zasięgiem miejsca pierwszego kontaktu –
zgodnie z AI+7 = 1), zadaje 2 trafienia w trakcie odwrotu; po dojściu 855 przechodzi w Idle i **sam ponownie wybiera
ad0** (2013 po 1 takcie), zabija go; ad0 nie traci celu (brak EnemyUnitNoLongerVisible – cel cały czas w LOS).
Utrata celu poza LOS i przeszkoda – nadal bez pomiaru [N].
Narzędzie: nieudany start 601 (zawieszenie na odprawie przy odblokowanym pulpicie) został wykryty i ponowiony
automatycznie z zapisem powodu (`proby_startu`).

## 23. Remisy i kolejność kandydatów

- 0x6399CA: osiągalność 0x62D696 sprawdzana **tylko dla kandydata z wynikiem większym od dotychczasowego**
  (+0x68); osiągalny → najlepszy := kandydat; nieosiągalny → 0x5E8651 (rejestr nieosiągalnych) i przegląd trwa.
  Wynik ≥ W+0x24 (próg) **kończy przegląd** (+0x6D = 1) – pierwszy kandydat powyżej progu wygrywa niezależnie
  od dalszych [W].
- Klucz permutacji [0x919774]+0xB0 – odczyt 595 [P]: wartości 1, 0, 0, 1 przy liczniku taktów +0xB4 = 375, 418,
  462, 505 – zgodne z parzystością licznika taktów [H]; dla n kandydatów s = k mod n ∈ {0, 1}. Permutacja
  0x40CFC7 nie jest wdrożona – brak pomiaru kolejności na scenariuszu z remisem [N].
- 0x62D696 [W częściowo]: odrzuca cel z polem −10000; zasięg² z ulepszenia+0x9C, porównanie z 0x825784; dalej
  test ścieżki (typ+0x430, +0x5D4) – nieprzeczytany do końca.

## 24. Pierwsze rozbieżne takty (etap 33)

| Okno | Pierwszy takt | Przyczyna |
|---|---|---|
| 578 G1 | brak | – |
| 578 G3 | 169 (ω 857 w 2021) | [N]; HP do taktu 334 zgodne (morale) |
| 580 G1 (AoC) | 57 (spóźniona próbka stanu) / 146 przeładowanie | ciąg LCG gry [N – inne systemy losujące] |
| 590 G1 | 97 (kurs w trybie 1) | Core obraca o jeden krok ω przy ruchomym celu, gra nie [N]; kolejność jednostek odwrócona daje gorszy wynik (64) |
| 589 G3 (nowe) | 1 | start okna w trakcie trasy (odtworzenie trasy z próbki) [N] |

## 25. Morale z budynków – pełne reguły (etap 34)

Źródło: statyka EE i AoC (dezasemblacja Capstone), dane `dbareaeffect`, `dbunitset`, `dbobjects`, `dbgamevariant`,
odczyty modyfikatorów z etapu 33 (591/593). Implementacja: `cpp/core/include/openee/efekty_obszaru.hpp`,
`Swiat::przebieg_efektow` (`cpp/core/src/symulacja.cpp`); dane wejściowe z narzędzia
`narzedzia/titan/efekty_obszaru.py`.

### 25.1. Funkcje

| Funkcja | EE | AoC | Pewność |
|---|---|---|---|
| Fabryka efektów obszaru (switch po typie szablonu +0x20 − 1, 8 przypadków) | 0x663A73 | – | [P] |
| Konstruktor `EEAreaEffect` (+0x04 = 1, +0x08/+0x0C = 0, +0x10 = szablon) | 0x664826 | 0x67BF4B | [P] |
| Konstruktor `EEAEMoraleFromBuildings` (vtable EE 0x835CA8, AoC 0x84BD6C) | 0x6641CA | 0x67B911 | [P] |
| Poziom: min(+0x24, +0x20) (vt+0x4C) | 0x664202 | 0x67B949 | [P] |
| Oznacz do przeliczenia: +0x1C = 1 (vt+0x3C) | 0x66420F | 0x67B956 | [P] |
| Zliczanie domów (vt+0x44) | 0x664214 | 0x67B95B | [P] |
| Filtr domu – prostokąt / koło | 0x66453F / 0x664753 | 0x67BC86 / – | [P] |
| Redukcja obrażeń (vt+0x30) – etap 33 | 0x6640BA | – | [P] |
| Test jednostki w obszarze (szablon) | 0x664B52 → 0x664BE9 | – | [P] |
| Relacja graczy (szablon +0x28) | 0x664A89 | – | [P] |
| Zestaw jednostek (`dbunitset`) | 0x4A7618 → 0x52BFA4 | – | [P] |
| Loader szablonu z pliku | 0x664C71 | – | [P] |
| Menedżer – jeden przebieg | 0x663DBD | 0x67B634 | [P] |
| Wywołanie co 2000 ms w takcie `EEPhysics` | 0x547742 (z 0x546D5D) | 0x553C59 (z 0x553211) | [P] |
| Przypisanie efektów jednostkom (obiekt generujący) | 0x5EC018 → 0x6637B3 | – | [P] |
| Usuwanie nadmiarowych | 0x664EDB → 0x664E0B | 0x67C721 → 0x67C651 | [P] |
| Przeliczenie wszystkich efektów gracza (`EEPlayer` vt[47]) | 0x55C00E → 0x55C02A | – | [P] |
| Gracz: dodanie / usunięcie obiektu – dla domu przeliczenie | 0x555CE7 (0x555D98) / 0x55C397 (0x55C4FD) | – | [P] kod, [W] nazwy |

### 25.2. Kto daje morale

`dbobjects` „Area Effect ID” 1–4 → szablony `dbareaeffect`. Morale dają szablony typów 2, 5 i 6 [P: dane i fabryka]:

| Szablon | Typ | Kształt | Relacja | Obszar | Max morale | Zestaw | Obiekty |
|---|---|---|---|---|---|---|---|
| 4 TC Morale Bonus Rng 10 | 5 `MoraleFromBuildings` | 1 kwadrat | 2 sojusznik | 10 | 2 | 1 People Morale 1 | Town Center (35) |
| 14 Capitol Morale Bonus Rng 10 | 5 | 1 | 2 | 10 | 4 | 1 | Capitol (41) |
| 7 / 44 Tower Morale (Capitol / TC) | 2 `EEAEMorale` | 1 | 1 ten sam gracz | 10 | poziom = +0x40 = 5 | 108 Towers | Capitol, Town Center |
| 6 / 37 Hero Morale, 3, 34, 39 | 6 `MoraleFromMilitaryHeroes` | 2 koło | 2 | 7 / 12 / 4 / 6 | – | różne | bohaterowie, Golden Hind |

Szablony i reguły są w EE i AoC identyczne; różnią się tylko zestawy jednostek (AoC zawiera dodatkowe typy) [P: dane].

### 25.3. Poziom (EEAEMoraleFromBuildings)

- Konstruktor: +0x20 = Max morale (+0x3C szablonu) + „Alter max morale (dynamic)” bieżącego wariantu gry
  (`dbgamevariant`, indeks [0x918300+0x4F8]: Scenarios 0, Tournament 0, Standard 2); +0x24 = 0; +0x1C = 1 [P].
- Po każdym przeliczeniu +0x24 = min(n, +0x20), a przy ujemnym minimum 0 [P]. Poziom = min(+0x24, +0x20).
- n = liczba **domów** (typ+0x4B8 == 37, czyli `b  House`) [P], które:
  - należą do gracza zapisanego w efekcie przy jego utworzeniu (+0x18; równość numeru, sojusznicy się nie liczą);
  - mają HP > 0 i ustawione +0x340 (obiekt na mapie [W]);
  - mają kotwicę (pole +0x1C/+0x20) w prostokącie: ix = ftol(x), iy = ftol(y) środka źródła, r = fistp(promień);
    gdy ułamki obu współrzędnych środka leżą w (0,25; 0,75) – [i − r, i + r], w przeciwnym razie [i − r, i + r − 1].
    Town Center 2 × 2 o kotwicy (184, 109) ma środek (185, 110), więc liczy domy z [175, 194] × [100, 119];
  - dla kształtu 2: dodatkowo odległość² kotwicy od (ix, iy) ≤ r² (f32).
  Duplikaty (obiekty wielopolowe) są usuwane. Obiekt `x House - Copper` (412) **nie** jest liczony [P: typ].
- Promień = rozmiar szablonu (+0x2C) · typ+0x428 źródła (1,0 z loadera 0x61C72C; zmiany ulepszeniami [N]).
- Przeliczenie wykonuje się tylko przy fladze +0x1C, ustawianej przez konstruktor i przez
  `SuggestRecomputeAllAreaEffects` gracza. To wywołanie występuje przy dodaniu i usunięciu **domu** u gracza.
  Zmiana HP, budowa domu i przejęcie budynku z efektem nie mają osobnej ścieżki [N].

### 25.4. Kto otrzymuje efekt (0x664B52)

Kolejno: typ jednostki należy do zestawu „Apply on unit set” (+0x38); relacja (+0x28) między **bieżącym**
właścicielem źródła a graczem jednostki (1 ten sam, 2 IsAlly = ten sam albo +0x9E4 = 0 w obu kierunkach,
3 wróg, 4 każdy); +0x340 jednostki; położenie w obszarze. Kształt 1: |cx − px| ≤ r i |cy − py| ≤ r, pozycje
f32 (granica włącznie). Kształt 2: odległość przez funkcję DLL ≤ r [W]. HP odbiorcy nie jest sprawdzane.
Źródło otrzymuje własny efekt (wyjątek: typ 1, leczenie).

Zestaw jednostek (0x52BFA4): gdy ma rodziny (1…0x38), należy typ z rodziną z listy i bez ID na liście obiektów;
gdy nie ma rodzin – typ z ID z listy obiektów; jeżeli to nie zachodzi, decyduje „Include unit set”; na końcu
„Exclude unit set” wyklucza [P: kod; przypisanie pól pliku 19/20 do +0x30/+0x34 – W]. Royal Guard (422) należy do
zestawu 1 [P: dane].

### 25.5. Wiele źródeł

Poziomy się **nie sumują**. Usuwanie nadmiarowych (0x664E0B) traktuje typy 2, 5 i 6 jako jedną klasę. Z efektów tej
klasy na liście jednostki zostaje ten o największym poziomie (vt+0x18, porównanie bez znaku). Przy remisie zostaje
pierwszy [P]. Zatem TC (2) i Capitol (4) w jednym miejscu dają poziom 4, ale dopiero od drugiego przebiegu: w pierwszym
oba mają jeszcze licznik 0 i zostaje pierwszy. TakeDamage (etap 33) przechodzi całą listę; vt+0x30 innych efektów
zwraca fałsz bez zapisu, więc działa jedyny pozostały efekt morale [P].

### 25.6. Kiedy

Takt `EEPhysics`: losowania → menedżer tras (0x4A396B) → **efekty obszaru** (0x547742) → pętla jednostek (0x547AAD).
Akumulator +0x9C (f32, reset 0) dostaje +0x98 = 34,0909 ms; porównanie ≥ 2000 na stosie x87; po przebiegu
+0x9C −= 2000. Jeden przebieg na takt, pierwszy w takcie 59 od startu gry, potem co 58 lub 59 taktów [P: kod].
Przebieg (0x663DBD):
1. czyszczenie list efektów wszystkich jednostek (0x5E948A);
2. przypisanie: każdy obiekt z efektami i +0x340, dla każdego jego efektu, każda jednostka z regionu
   (kolejność kandydatów z siatki regionów – [H]);
3. usuwanie nadmiarowych (poziomy z poprzedniego przebiegu);
4. aktualizacja wygenerowanych: pozycja źródła → +0x08/+0x0C i przeliczenie domów przy +0x1C;
5. przebudowa listy regionów i 6. `UpdateAffectedBy` (dla morale bez działania).

Wnioski: jednostka, która weszła w obszar, dostaje morale dopiero przy najbliższym przebiegu, a po wyjściu zachowuje
je do następnego. Zniszczony dom zmienia poziom dopiero w kroku 4 najbliższego przebiegu. Zniszczony budynek-źródło
przestaje przydzielać efekt przy najbliższym przebiegu (lista jest wtedy czyszczona) [W: licznik referencji].

### 25.7. Zgodność z pomiarem

Scenariusz `e31_a`, gracz 1:
- 3 domy (182, 113), (182, 111), (181, 112) w prostokącie TC; wariant gry Scenarios (+0) → poziom 2;
- odczyt +0x20 = +0x24 = 2 dla 857 i 858, +0x08/+0x0C = (185, 110) [P: etap 33];
- 855 i 856 (|dx| > 10) bez efektu, wróg 0x5000ad3 w kwadracie bez efektu (relacja 2) [P].

Core odtwarza te poziomy samodzielnie dla wszystkich 5 okien (578 G1/G3, 580 G1 AoC, 589 G3, 590 G1). Wyniki
okien są takie same jak przy poziomach wpisanych ręcznie (etap 33).

### 25.8. Otwarte [N]

- Bohaterowie (typ 6): poziom = fistp(UCU+0xDC) bohatera (EE 0x6647DB), przy HP ≤ 0 funkcja zwraca wskaźnik
  bohatera zamiast poziomu (rejestr eax). Potencjalny błąd oryginału, zob. BLEDY_ORYGINALU BO-11 [H]. W Core
  nieodwzorowane.
- Wieże jako odbiorcy (typ 2, zestaw 108) – wieże nie są obiektami Core.
- Budowa domu (fundament a +0x340), przejęcie budynku-źródła (czy efekt +0x18 jest tworzony od nowa).
- Faza akumulatora +0x9C przy starcie z migawki gry (okna testowe) – Core wykonuje wtedy jeden przebieg odtworzeniowy.
- Kolejność kandydatów z siatki regionów (ma znaczenie tylko przy remisie poziomów).

## 26. Jednostki dystansowe i pociski – mapa statyczna (etap 34, przygotowanie)

Rozpoznanie wstępne, bez implementacji w Core. Klasy z RTTI:
- typy obiektów (`EEUnitClass`) – `EEUCProjectile`, `EEUCMissile`, `EEUCBomb`;
- modele ruchu (`EEPhysicsModel`, odpowiedniki `EEPMLand`) – `EEPMProjectile`, `EEPMMissile`;
- efekt graficzny – `EEE3DLinearProjectile`.

| Element | EE | AoC | Pewność |
|---|---|---|---|
| Wykonanie ataku w cyklu (0x61E11C): typ atakującego +0x3FC (typ pocisku) = 0 i zasięg maks. UCU+0x9C ≤ 1,0 → DealDamage 0x61DE61 (wręcz) | 0x61E1E2–0x61E208 | – | [W] |
| jw., +0x3FC = 0 i zasięg > 1,0 → test linii 0x637F5A, potem DealDamage (strzał bez pocisku) albo cel pośredni (obiekt na linii – inny gracz niż sojusznik) | 0x61E212–0x61E300 | – | [W] |
| jw., +0x3FC ≠ 0 → wystrzał: 0x62028B (pojedynczy; typ pocisku vt+0x30) albo 0x623A53 (gdy lista +0xE4 typu niepusta; vt+0x34, tworzy EEUGAttackUnit 0x60AD45 – pocisk jako obiekt z celem) | 0x61E305–0x61E322 | – | [W] |
| Wywołujący 0x61E11C: cykl ataku (stany walki) i trafienie pocisku | 0x6240CD, 0x60ABB0, 0x60B33C; pocisk 0x607D79 (`EEUCProjectile`/`Bomb` vt+0x74 = 0x607B11), rakieta 0x606067 (`EEUCMissile` vt+0x74 = 0x605E9B) | `EEUCProjectile` vt+0x74 = 0x619388, `EEUCMissile` 0x61765D | [W] |
| Typ pocisku vt+0x30 / +0x34 (wystrzał) | 0x61ED60 / 0x61EB9D | 0x6329F7 / 0x6327FF | [W] |
| Typ pocisku vt+0xA8 | pocisk 0x607E2B, rakieta 0x606109, bomba 0x600888 | wszystkie trzy 0x6355E3 (różnica EE/AoC) | [W] |
| Model ruchu pocisku – takt (vt+4) | `EEPMProjectile` 0x550695, `EEPMMissile` 0x54E67D | 0x55D015, 0x55AFF0 | [W] |
| Ustawienie pozycji obiektu (z taktu pocisku) | 0x63854F → 0x5F043B | – | [W] |
| Dane: dbobjects „Projectile ID”, „Initial projectile angle”, „Parabolic projectile”, „Ammo amount”, „Min range”, „Max range”, „Attack angle”, „Area of effect” | – | – | [P: schemat] |

Wniosek [W]: obrażenia pocisku liczy ta sama funkcja wykonania ataku (0x61E11C → DealDamage), wołana z obsługi
zderzenia pocisku (vt+0x74). Nie liczy ich osobny wzór. Moment trafienia pocisku zależy więc od lotu, a nie od
klatki animacji. Do sprawdzenia [N]: czy atakującym w DealDamage jest pocisk, czy strzelec (kontekst +0x1C0).

Eksperymenty referencyjne do etapu 35+:
1. łucznik vs nieruchomy cel – takt wystrzału, takt trafienia, tor (pozycje pocisku co takt), HP;
2. cel ruchomy – punkt celowania i chybienia;
3. minimalny zasięg („EnemyWithinMinimumRange”, stan 2035) i odwrót strzelca;
4. łuk ostrzału (`Attack angle`, InsideFiringArch 0x61FCAF) z obrotem;
5. pocisk paraboliczny i zależność od wysokości (modyfikator 0x61E500);
6. obszar rażenia (0x61DAE6) i ogień do sojusznika;
7. te same przypadki w AoC (inne vt+0xA8).

## 27. Cel nieosiągalny, ponowny wybór i stan 9006 przy celu ataku (etap 37)

Kod EE (adresy Empire Earth.exe, analiza capstone) i nagrania 616/619/620 (EE, e35_a) [P: kod; P: pomiar co takt]:

1. **Mapa celów nieosiągalnych jednostki** (EEUnit +0xA0, liczba +0xB0, klucz = id celu +0x24). Wpis: pole atakującego
   (+0x1C/+0x20), pole celu, id, **termin = czas gry + 30000 ms** (0x7530).
   - 0x5E8651(cel): nowy wpis albo odświeżenie samego terminu (pola zostają z pierwszego wpisu).
   - 0x5EC9BB(cel, sprawdź_pola): brak wpisu → fałsz; termin ≤ czas gry → wpis usunięty, fałsz; bez sprawdzania pól →
     prawda; z polami: pole atakującego i pole celu jak przy wpisie → prawda, inaczej wpis usunięty, fałsz.
2. **Kto wpisuje** [P: kod]:
   - EnemyUnitReachable (0x60B1EA) przy fałszu, gdy nie ma ważnego wpisu;
   - punkt podejścia do celu stojącego (0x62D1F2): brak przejezdnego z 8 miejsc 0x632CF4 → 0x62CD76 → 0x5E8651 –
     **przy każdym PrepareToMove**, także przy rozkazie gracza;
   - wybór celu (0x639D65), gdy osiągalność 0x62D696 najlepszego kandydata jest fałszywa; RepathAroundObstacle
     (0x622776, cel AI); odwet na atakujących (0x623717) – te trzy ścieżki nie wystąpiły w pomiarach [N].
3. **Kto czyta**: wybór celu (0x639B61) – ważny wpis (z polami) odrzuca kandydata; odwet (0x623629) [P: kod].
4. **EnemyUnitReachable** = (typ+0x61A → 0x5ECAD0) ∧ 0x62D696 ∧ **licznik prób celu ≤ 25** (`cmp 25, [cel+0x18]`,
   `sbb`, `inc`). *[Etap 37 – zastąpione: „< 25” (§ 10, etap 31).]* 619: 2013 przy liczniku 25, porzucenie przy 26.
5. **Przebieg z nagrań**: każda próba (gracza i AI) = 26 × PrepareToMove co 9 taktów (307 ms), potem 2025 → 5000.
   Ponowny wybór tego samego celu przez AI następuje 30,2–30,5 s po ostatnim PrepareToMove (616: 135675, 173894,
   212113 wobec ostatnich 8000 przy 105195, 143414, 181633), czyli przy pierwszym przeglądzie po upływie terminu.
   W 619 po porzuceniu obywatela AI od razu (1 takt) wybiera innego widocznego wroga – bohatera 0x5000ad2.
6. **Rozkaz gracza a AI**: cel gracza (`pochodzenie_1C` = 1) nie jest kontynuowany po porzuceniu – kolejka pustoszeje,
   dalej wybiera AI (cel z `pochodzenie_1C` = 0). Oba rodzaje celów używają tego samego licznika prób celu (+0x18)
   i tej samej mapy nieosiągalnych (mapa należy do atakującego, nie do celu).
7. **9006 przy celu innym niż EEUGLocation**: zdarzenie 9014 UnitFacingNotRequired obsługuje cel (vt+0x64);
   EEUGAttackUnit (0x60B5CB) przekazuje je do bazy 0x62871E = zawsze prawda; EEUGLocation (0x6153CA): cel+0x31 = 0
   albo w poziomie > 1 cel. Tryb fizyki 5 (0x54E0F1) wykonuje się tylko dla celu EEUGLocation (dynamic_cast celu
   +0x1F0); przy celu ataku albo bez celu **nie robi nic** – pozycja, v i ω zostają (619: v = 0,259 zamrożone).

Core (etap 37): mapa nieosiągalnych w `BojJednostki::nieosiagalne`, `Swiat::cel_nieosiagalny` / `oznacz_nieosiagalny`,
filtr kandydatów w `szukaj_wroga`, wpis w `punkt_podejscia` (brak miejsca) i w EnemyUnitReachable; licznik ≤ 25;
9014 i tryb 5 jak wyżej. 0x62D696 i 0x5ECAD0 nadal przyjmowane jako prawda [N].

## 28. Regeneracja HP, bohater w 619 i pełne odtworzenie e35_a (etap 38)

**Regeneracja HP – 0x625B47** [P: kod + pomiar 619]. Wywoływana z aktualizacji typu jednostki (0x60071D, 0x60498C,
0x605490) tylko wtedy, gdy typ+0x578 („Health regeneration” z dbobjects) ≠ 0. Flaga [0x918EA0] ≠ 0 pomija całość
(w Core zawsze 0 [W]).

```
licznik = EEUnit+0x290 − czas_taktu        ; czas_taktu = [0x919774]+0xA4 = 34 ms (pomiar: −34 co takt)
jeśli licznik > 0:  EEUnit+0x290 := licznik
inaczej:            nowe = min(HP + typ+0x578, ulepszenie+0x144)
                    jeśli HP > 0 i nowe > 0: HP := nowe (setter 0x616F30)
                    EEUnit+0x290 := 1000     ; bez przenoszenia nadwyżki → okres 30 taktów (1000 − 29·34 = 14)
```

Pomiar 619 (bohater 173 „h1-4 Alexander the Great (heal)”, regeneracja 2): licznik 898 w pierwszej próbce
(t = 9909), dalej −34 co takt, po 14 → 1000 i HP +2; trafienia gwardii (−14) nie przesuwają fazy. W 622 licznik
startowy 1000 (t = 9806). Pole +0x290 to odliczanie, nie termin bezwzględny (poprawione w `struktury_titan.json`).

**Bohater 0x5000ad2 – parametry** (odczyt zad. 621 z typu i ulepszenia EE [P]): klasa 8, rodzina ataku 55, rodzaj/wiersz
5, łuk 0,349066, rozmiar 0,55, punktowy, szukanie 1000 ms, zasięg 0,6, LOS 6, atak 14, pancerz [3,0,3,0,0,0],
przeładowanie 2000, HP 1235, a 2,0, vmax 0,8, α = ωmax = 6,98132, +0xAC 0,8, regeneracja 2, leczenie innych 50 w
promieniu 4,0 (dbobjects, efekt 138 – nieużyte w 619). Brak odczytu: c4/c8 ruchu (bohater stoi – bez wpływu) [N].
Obrażenia gwardii na bohaterze: 15 · 1,4 (tablica 0x10, klasa 8 × rodzina 48) · r(wysokość) − 3 = **14** – Core z
modyfikatorem wysokości `z_gry` daje 14 w każdym z 79 trafień [P: 619].

**Stany bohatera w 619** [P pomiar, N mechanizm]: bohater nie atakuje (gracz 5 bez celu w LOS 6 – gwardia A stoi
poza nim do 77716, potem bohater jest celem); cykl 5000 → 16000 (LookForHealee, Healer.tai) → 2025 → 5000 co
~1023 ms oraz 5001 przez 2 takty po każdym trafieniu. Skrypt leczenia nie jest w Core – porównanie stanów bohatera
pomija 16000/2025 (jawny parametr narzędzia) i zatrzymuje się na 5001 (t = 79045); HP bohatera zgodne w całym zapisie.

**Wybór bohatera w 619 to AI, nie rozkaz** [P: kolejka celów]: cel EEUGAttackUnit utworzony w 71988 ma
`pochodzenie` 0 (nie od gracza) – po porzuceniu obywatela (5000 w 71954) Idle `CanISeeEnemy` → CheckRange 2013
w następnym takcie (bez 2016/2012, tryb 3 – brak obrotu przed ruchem). Rozkaz MCP na bohatera wszedł dopiero w
88694 (pochodzenie 1, 2016 → 2012). Rozkazy dla 0x1000858 (zgłoszone przez MCP jako nieudane) weszły z opóźnieniem
w 123981, 152108 i 180236 (pochodzenie 1). Etap 37 błędnie przypisywał t = 71988 rozkazowi.

**Obrót trybu 1 do celu EEUGLocation** [P: 622, takt 86682]: rozkaz ruchu wydany w trakcie WaitForReload (tryb 1
z 2012/2001 aktywny) – pierwszy takt obraca jednostkę w stronę punktu ruchu (ω = +0,4165), nie w stronę dawnego celu
ani własnej pozycji. Core: w trybie 1 bez celu-jednostki pozycja celu = punkt celu EEUGLocation (+0x30).

**Zmiana pola atakującego (B1)** [P: 622]: po przejściu gwardii z pola (161,105) na (162,108) – 22,8 s po ostatnim
wpisie obywatela w mapie nieosiągalnych – AI wybiera obywatela ponownie natychmiast (94524, pochodzenie 0); wpis
z innym polem atakującego nie blokuje wyboru. Reguła etapu 37 (pola atakującego i celu w kluczu ważności) daje ten
sam przebieg co takt (622: 6725 taktów zgodnych, macierz bitowo). Zmiana pola celu (B2) i dwie gwardie na jeden
cel jako niezależne mapy (B3) – nie zmierzone (cel wroga nie daje się przesunąć przez MCP; rozkaz drugiej gwardii
wchodzi z opóźnieniem i ma inny przebieg – § niżej).

**Druga gwardia na bohatera (0x1000858, 619/620)** [P pomiar, N przyczyna]: PrepareToMove wybiera miejsce
(164,5; 105,025) – miejsce (163,975; 105,025) zajmuje gwardia A – i wstawia przed celem ataku EEUGLocation
(163,5; 103,5); trasa = 1 punkt (własna pozycja), 10003 → 9000 → cel EEUGLocation zdjęty → 2016 → drugi
PrepareToMove bez EEUGLocation → 9000 → 9006 → 5001 → 5002 → 2025 → 5000 z usunięciem celu gracza. Core: brak
testu zajętości miejsca i wstawiania EEUGLocation – 9006 już w pierwszym przejściu, potem cykl 5002/2013. Pierwsza
rozbieżność 0x1000858: 619 t = 124254, 620 t = 109423. Wymaga analizy 0x632CF4/0x62D696 (zajętość pól, okno A*).

**0x5ECAD0** [W: kod]: test osiągalności przez mapę 0x917BC8: najpierw 0x4256BE(jednostka, pole celu) – test
bezpośredni; inaczej identyfikatory regionów (+0xDA obiektów pól z 0x42C49A) obu jednostek i macierz połączeń
regionów [0x917CC4][i·[0x917CEC] + j]. To nie A* – spójność regionów mapy. **0x622776 / 0x623717** [W]: miejsca
wywołania wpisu do mapy nieosiągalnych 0x5E8651 – w PrepareToMove (potem funktor 0x6233D2/0x630013 i dalsze
przygotowanie trasy) i w drugiej akcji stanu (powrót do 0x6236DD). Reguł nie wdrożono – brak pomiaru rozróżniającego.

## 29. Miejsca podejścia, pośrednie EEUGLocation i osiągalność (etap 39)

**Łańcuch wywołań** [W: kod]: PrepareToMove 0x6222A8 → cel vt+0x08 (EEUGAttackUnit 0x60AF05) → cel ruchomy
(v > 0): przechwycenie 0x62C963; cel stojący: 0x62CF6A → (atakujący +0x61A) w zasięgu 0x631935 → własna pozycja;
inaczej 0x632CF4 → (ulepszenie celu +0xAC > 0) 0x63234D, w przeciwnym razie 0x62C315/0x632A8B/0x62C697; porażka
0x632CF4 → 0x62CD76 (wpis do mapy nieosiągalnych). Po wyborze 0x60AF05 zapisuje punkt w mapie grupy atakującego
(+0x1C8 → 0x5DF33D, klucz = id jednostki).

**0x63234D – wybór miejsca** [W: kod; P: 619/620 i 578 G3]:
1. Pozycja celu: cel w ruchu z trasą – pozycja przewidziana (+0x164 · +0x174); inaczej vt+0x5C (pozycja).
2. R = 0,5·s_ja + 0,5·s_cel (typ +0x474). Osiem miejsc w kolejności wstawiania: N, E, S, W, NE, SE, SW, NW
   (jak w Core od etapu 31), sortowanie wg odległości od atakującego (0x63A48B).
3. Obiekty w promieniu R + 2,0 od celu (0x63603B: siatka obiektów 0x635288/0x635861, filtr d² ≤ r²,
   obiekt bez jednostki – środek pola).
4. Dla kolejnych miejsc: (a) gdy atakujący ma grupę (+0x1C8) – 0x5DF185 (punkty innych członków grupy w
   odległości < (0,5·s)²) – **wynik ignorowany** (al nieużywane, 0x632625) [W]; (b) pole miejsca przejezdne dla
   atakującego (0x62C7C8); (c) dla każdego obiektu z listy: typ+0x619 ≠ 0 i to samo pole → zajęte; inaczej żywa
   jednostka (HP > 0) z flagą typu +0x600 albo +0x606 → zajęte, gdy **(0,5·(s_obiektu + s_ja))² > d² + 0,1·s_ja**
   (d² – GE2DPoint::DistanceToSquared miejsca i pozycji obiektu). Pierwszy wolny kandydat wygrywa; brak – pozycja
   celu i fałsz.
5. Sprawdzenie zajętości jest geometryczne (punkt i promienie), nie po polach i nie rezerwacją; jednostka w ruchu
   blokuje tak samo jak stojąca (warunek nie patrzy na v) [W]. Flag +0x600/+0x606 nie odczytano – Core przyjmuje je
   dla każdej jednostki bojowej [H].

Pomiar [P]: 619 – gwardia 0x1000858 wybiera (164,5; 105,025) zamiast bliższego (163,975; 105,025), na którym stoi
gwardia 0x1000856 (d² = 0,0034; próg 0,25 > 0,0034 + 0,05). Core z tą regułą: punkt celu ataku 0x1000858 równy
grze (kolejka w 124113). 578 G3 (dwie gwardie na jeden cel): różnice stanu 75 → 5, HP 59 → 1, celu 8 → 0,
maks. pozycji 0,449 → 0,003; 589 G3: stan 84 → 65, HP 17 → 6, maks. pozycji 0,438 → 0,029. Pomiar 623 (e39_a):
cztery gwardie (dwa układy) wybrały miejsca zgodne z sortowaniem – w tym układzie zajętość nie rozstrzygała [P].

**Pośrednie EEUGLocation – 0x4A26E3** [W: kod; P: 619/620]: prośba o trasę jednostki 0x4A1AFF uruchamia etap grafu
podsektorów (EEAIAStarGraphMachine), gdy bajt prośby +0x1C = 1. PrepareToMove ustawia go dla celu położenia bez
+0x32/+0x1D **oraz dla każdego innego celu z +0x1D = 0** (0x622431). Po zakończeniu grafu 0x4A26E3 ustawia na
bieżącym celu +0x1D = 1 (0x4A2764) i – gdy ścieżka grafu ma > 1 podsektor – dla podsektorów 0 … n − 3 tworzy
EEUGLocation w punkcie reprezentatywnym podsektora (+0x3C/+0x40, pole + 0,5; z = 0, kurs 0, pochodzenie z celu
+0x1C) i wstawia je na czoło kolejki (0x5F05BD). Konstruktor 0x614C86 (vtable 0x831E64). Dlatego:
- drugi PrepareToMove tego samego celu pomija graf (+0x1D = 1) – w 619 drugie przejście bez EEUGLocation;
- po zdjęciu EEUGLocation (9000, koniec trasy) cel ataku wraca na czoło → InitialAttackState 2016.
Punkt (163,5; 103,5) w 619/620 = punkt reprezentatywny podsektora na ścieżce [H – wymaga odczytu podsektorów].
**Core nie ma grafu podsektorów** (status „niewdrożony”) – to pierwszy brakujący warunek Titan dla 0x1000858.

**Usunięcie celu gracza po drugim 9006** [W, częściowo]: 9006 → 5001 ReacquireGoal → 5002 ReacquireEnemyUnit →
`EnemyUnitReachable` fałsz → 2025 ShouldIReturnToInitialContactLocation → 5000 (zdjęcie celu). EnemyUnitReachable =
licznik ≤ 25 i 0x62D696. **0x62D696** (EE): pole celu −10000 → fałsz; T = max(zasięg², 2,0); prawda, gdy typ+0x430
= 0, gdy (typ+0x5D4 & 6) = 0 albo gdy odległość (0x406D5E) ≤ T; jednostki w garnizonie/transporcie (+0x1D8) –
fałsz; inaczej A* Bounded 0x4A189C (klucz 0xB) w prostokącie = obwiednia pól obu jednostek powiększona o
2·⌈max(LOS, T)⌉, budżet 2·max(2·⌈…⌉, odległość pól 0x409914) ≤ 0x23; prawda, gdy pierwszy punkt wyniku jest w
odległości pól ≤ T od pola celu. W Core nadal prawda [N] – brak rozpoznania 0x4A189C i 0x409914 (metryka).

**Rozkazy MCP drugiej gwardii** [P: 623]: cel EEUGAttackUnit powstaje 650–850 ms czasu gry po PPM (4 rozkazy).
W 619/620 rozkazy 0x1000858 najpewniej były przyjęte – trzy próby MCP ↔ trzy cele, każdy porzucony po ~680 ms
(2016 … 9006 → 5000), więc odczyt kolejki 0,8 s czasu rzeczywistego po PPM widział pustą kolejkę [H: liczba i
kolejność się zgadzają; czasów kroków MCP w czasie gry nie zapisano]. `walka_atak_rzut_gry` (etap 39) czyta kolejkę
w każdym takcie do 1000 ms czasu gry po PPM i zapisuje zaznaczenie +0x9B0/+0x9AC, czas PPM, czas utworzenia celu
i porzucenie w oknie.

## 30. Pochodzenie punktu (163,5; 103,5), osiągalność 0x62D696 i pełne 619/620 (etap 40)

**Punkt (163,5; 103,5)** [P: kod + odczyt + pomiar 624]: punkt reprezentatywny (163, 103) podsektora 472, do którego
należy pole celu ataku drugiej gwardii ((164,105) w 619, (163,105) w 624). Gwardia stoi na polu (162,118) w podsektorze
523; 523 nie ma 472 na liście sąsiadów, więc A* grafu kończy przez 469 i daje ścieżkę [472, 469, 523] (n = 3) →
0x4A26E3 wstawia punkt podsektora o indeksie 0 (cel) i ustawia na EEUGAttackUnit +0x1D = 1. Kolejność w 624:
8000 (punkt + atak, próby: punkt 1, atak 0) → 2015 → 10003 → 9000 → (8021 GetNextAutoWaypoint, zdjęcie +0x32) → 2016
→ … → drugi 8000 bez punktu (+0x1D = 1) → 9000 → 9006 → 5001 → 5002 → 2025 → 5000.

**Dlaczego trasy mają 1 punkt** [P: Core + mapa]: pole (162,118) jest nieprzejezdne (las) – gwardia stoi w nim od
startu scenariusza; A* po polach z takiego pola kończy się po 2 iteracjach, trasa = własna pozycja.

**0x62D696** [W: kod; P: 619/620/624 przez zgodność co takt]: metryka 0x409914 = kwadrat odległości pól (całkowity);
0x406D5E = kwadrat odległości pozycji. T = max(zasięg², 2,0). Szybka prawda: typ+0x430 = 0, (typ+0x5D4 & 6) = 0
(oba przyjęte ≠ 0 [H]) albo d²(pozycje) ≤ T. Inaczej A* Bounded w obwiedni pól obu jednostek ± 2·⌈max(LOS, T)⌉
(przycięta do mapy), budżet min(2·max(2·⌈…⌉, d²(pola)), 0x23) iteracji; prawda, gdy węzeł końcowy wyniku (pierwszy
element listy) ma d²(pola, pole celu) ≤ T. Core: `Swiat::osiagalny_62d696` (AStarTitan, koniec = najbliższy węzeł).
0x5ECAD0 (spójność regionów) nadal prawda [N].

**Zwykły PPM** [P: nawigacja_wejscie pkt 3; 616]: trasa idzie przez prośbę grupową, kolejka nie dostaje punktów +0x32
nawet przy ścieżce grafu 3 podsektorów (616: cel w podsektorze 572) – Core traktuje cel zwykłego PPM jak po etapie
grafu (+0x1D = 1) [H: kto ustawia flagę]; cel z Shift przechodzi etap grafu przy aktywacji.

**Wyniki** (gwardie 0x1000856 i 0x1000858, pełny skład, graf z gry): 619 – 7270/7273 i 7273/7273 taktów stanu,
kolejki wszystkich jednostek bez różnicy; 620 – 6418/6419 i 6419/6419, kolejki bez różnicy; 616 (z rozkazem
220637 dla 0x1000858) – 6420/6423 i 6423/6423; 622 – bez różnicy. Pozycja, macierz, v i ω gwardii A bez rzeczywistych
różnic we wszystkich czterech nagraniach.

## 31. Etap 43 – czyste scenariusze 631/633/634 (odtwarzanie w Core)

- **Wysokość z zapisu scenariusza** [P 631]: jednostka bez aktualizacji fizyki zachowuje z z rekordu SCN (translacja
  macierzy +44) – np. 1,837 przy terenie 0,408; dosadzenie do terenu dopiero przy pierwszej aktualizacji fizyki.
  Przechwycenie 0x62C963 liczy odległość 3D z tą wartością: punkt (164,5001; 110,184) zamiast 109,8895.
  Core: `Swiat::ustaw_z`.
- **Faza liczników od startu scenariusza** [P 629/631]: pierwsze szukanie celu w 34 ms; odtworzenie od czasu gry 0.
- **Kolejność jednostek w takcie (czysta mapa)** [P 631/633/634]: jednostki o mniejszym id przetwarzane wcześniej
  (gwardia gracza 1 przed celem gracza 5 – w takcie 62419 CheckRange widzi poprzednią pozycję celu). Dla scen
  z kampanią (578 G3) ta reguła nie obowiązuje – kolejność listy gry zależy od całego scenariusza [N].
- **Umieranie gwardii** [P]: 6000 trwa 2455 ms (72 takty), 6001 – 1 takt, 6002 – 40 129 ms, potem 6003;
  w Core DyingAnimationFinished nie jest zamodelowane [N] (jedyna różnica 631/633/634).
- Wyniki: 631 – gwardia i obserwator 2808/2808 próbek (stan, HP, pozycja, kurs), cel do śmierci; 633 (2v1) – obie gwardie
  3695 + 2 spóźnione / 3697; 634 (3v1, z kontaktem) – trzy gwardie 6413/6413.

## 32. Etap 44 – śmierć: Generic Death.tai z danych typu

| Stan | Zdarzenie (0x61B677) | Warunek | Licznik |
|---|---|---|---|
| 6000 Dying | DyingAnimationFinished (0x1770) | +0x337 ≠ 0 (koniec sekwencji) albo czas klatki typu = 1 | animacja 0x62462B: +0x2FC += ms taktu (34); przy ≥ czasie klatki (typ +0x318[anim] = „wartość” sekwencji dbgraphics) kolejne klatki, reszta zostaje; po ostatniej klatce +0x337 = 1 |
| 6001 ResourcesRotting | ResourcesRottedAway (0x1771) | zasoby +0x40 = 0 | wejście 0x61B1F6: +0x2A8 = 0; takt 0x5FB218: +0x2A8 += ms, co 4000 ms −1 zasób |
| 6002 UnitRotting | UnitRottedAway (0x1772) | +0x2A8 = 0 | wejście 0x61B25E: +0x2A8 = typ+0x548 (dbobjects „Rotting time” × 1000); takt: −34 ms, nie poniżej 0 |
| 6003 Dead | – | – | usunięcie z mapy [N] |

Pomiary [P]:

| Typ | Sekwencja umierania | 6000 | 6001 | 6002 |
|---|---|---|---|---|
| gwardia (631/633/634) | 24 klatki × 102 ms | 72 takty = ⌈24·102/34⌉ | 1 takt | 1177 taktów = ⌈40 000/34⌉ |
| obywatel (638) | 17 klatek × 94 ms | 47 taktów = ⌈17·94/34⌉ | 1 takt | 1177 taktów |

**„Wartość” sekwencji dbgraphics to czas klatki w ms**, a nie czas cyklu (hipoteza z FORMATY_ETAP4 § 2.3 obalona).
Bohatera nie zmierzono. Core: parametry `smierc_klatki`, `smierc_ms_klatki`, `rozklad_ms` i `zasoby` (bez nich – zachowanie
jak przed etapem 44); Godot pobiera je z baz gry (`ObiektyScnCore.parametry_smierci`).

Wyniki odtworzeń po zmianie: 631 2808/2808 próbek wszystkich jednostek, 633 3697 (2 próbki spóźnione), 634 6413/6413
z przejściem 6003. Wcześniej cel był zgodny do 2186/2084/2081 próbek.

## 33. Etap 45 – obywatel (citizen.tai, FleeDanger), tryb śmierci i kolejka fizyki

- **FleeDanger 0x620687** (wejście 8019 przez vt+0x40 EEUC) [W; P: 638]:
  - odległość: gracz ≠ 0 → fistp(f32(LOS · 1,5)); gracz 0 → losowanie 1..2;
  - oktant 0x62F451 z pól +0x1C/+0x20 przez UMArcTan2(ux − ax, ay − uy); te same pola → +π/2 → oktant 1;
  - 0x632FFC: n = losuj(0, 3) + 3, b = losuj(0, 1) ≠ 0, n obrotów (tablica w kodzie Core);
  - do 8 pól kandydujących od kierunku, test 0x62C7C8; cel EEUGLocation, pochodzenie 1, stan 8000.
  638: stan generatora przed taktem 62215 = 132607946; losowania ucieczki to 3. i 4. losowanie taktu → n = 3, b = 0
  → kierunek 7, cel (168,5; 104,5). Odtworzenie zgodne co próbkę (4264/4264) przy stanie generatora z nagrania.
- **TakingLightDamage** (0x61BA3A): +0x29C > HP; +0x29C = HP na początku aktualizacji typu.
- **Tryb 2 (0x54DDFF)** przy wejściu w Dying: v = 0 (0x54A55B), ω = 0, bez kroku końcowego vt+0x48 [W; P: 638 –
  śmierć w ruchu, t = 66988; 578 – 6000 z trybem 2]. Od 6001 gra pokazuje tryb 6 (gałąź domyślna 0x549FA4: HP ≤ 0 →
  nic) – w Core tryb 2, skutek ten sam.
- **Kolejka fizyki 0x918DDC**: dodanie na koniec, usunięcie zatwierdzane w następnym takcie (Dead 6003 → poza kolejką
  takt później) [W: 0x530896/0x530913/0x53066A; P: 641].
- **Healer.tai** (bohater 173): HealSearchTimeElapsed = EEUC+0x4A4 ≠ 0 i licznik +0x22C = 0; licznik maleje o
  PH+0x98 · 0,001 s (0x600822); LookForHealee (0x61B57A) szuka celu 0x620A68 w LOS (lista od końca, 0x630E07:
  HP/HPmax ≤ typ+0x49C, sojusznik, maska klas) i ustawia +0x22C = +0x4A4 [W]. W Core niewdrożone w etapie 45 (raporty/archiwum/RAPORT_ETAP_45 § 7); wdrożone w etapie 46 (§ 34).

## 34. Etap 46 – TakeDamage, UnderAttack, Healer.tai i zagrożenie 0x62FE01

- **TakeDamage 0x6172BC** [W; P: 619, 638, 644]: napastnik wrogi i typ spełnia 0x631A09 → +0x1DC := napastnik
  (0x617917); ofiara w Idle i EEUC ofiary ma stan 2018 (+0x370, 0x622017) → UnderAttack (vt+0x74). EEUCLandPriest
  (bohater 173) – tak [P: 5001 po trafieniu w 619]; EEUCLandCitizen (obywatel) – nie [P]. Gracz: statystyki
  (EEPlayer 0x557147, EEComputerPlayer 0x43163C), alarm 0x55EDD2 – bez poleceń dla sojuszników [P: 644].
- **UnderAttack** (Generic Attack): CanFlee → RunFromAttacker; allof(CanITargetEnemies, …) → RetaliateAgainstAttacker,
  inaczej ReacquireGoal (5001) → (brak celu) ShouldIReturnToInitialContactLocation → Idle.
- **0x62FE01** (zagrożenie dla FleeDanger) [W]: najbliższa (kwadrat odległości pól, 0x61680D) jednostka z bieżącym
  celem EEUGAttackUnit/EEUGGather wskazującym obywatela, bez kontenera; nie „ostatni trafiający”.
- **Healer.tai** [W; P: 619, 644; pamięć typu]: HealSearchTimeElapsed = +0x4A4 ≠ 0 i +0x22C = 0; licznik +0x22C
  −f32(PH+0x98)·0,001 na takt (0x600822); LookForHealee 0x61B57A: 0x620A68 (LOS, lista od końca, 0x630E07, 0x5ECAD0) →
  EEUGHeal, +0x22C := +0x4A4; TurnToFaceHealee – tryb 1; HealUnit 0x621019; leczenie 0x612EF8 (+0x3C += 34 ms; > 1000 →
  +ulepszenie+0x150 HP do HPmax). Bohater 173: próg 1,0, zasięg 4,0, okres 1,0 s, 50 HP/s. Pomiar: koniec leczenia
  w takcie po pełnym HP, brak celu przy pełnym HP – porównanie ostre (odczyt kodu sugeruje „≤” – [N]).
- **Rozkazy MCP z opóźnieniem** [P]: 578 G3 takt 414 to rozkaz gracza (pochodzenie 1) dostarczony 84 s po kroku MCP.

## 35. Etap 47 – budynki jako cele ataku, śmierć budynku, próg leczenia

- **Model obiektu** [W; P: zad. 645, 647]: budynek to `EEUnit` (vtable 0x831494, jak gwardia); klasa EEUC z pola
  „Unit type” przez fabrykę 0x62188D (2/0x13 Building 0x8335A8, 0x19 Gate, 0x1d Fortress, 0x18 Mining, 6 Citizen,
  5/8/15 Land, 0 Ambient); klasa fizyki EEPMBuilding 0x82CCC0. Żywy budynek **nie jest** w kolejce fizyki 0x918DDC
  [P: 645/647 – 2 kontakty gwardii przy domu, nie 3]; Kill dopisuje go na koniec kolejki, zatwierdzenie w następnym
  takcie. Skrypt: „Simple Building.tai” = tylko Generic Death. Pamięć typu domu 37 [P: 647]: HP 500, pancerz 0, LOS 2,
  rodzina +0x4C4 = 3, +0x4C8 = 9, +0x612 = 0, +0x600 = 1, +0x4B4 = 2, „Size of collider” +0x474. Mur 467: +0x4C4 = 44,
  +0x474 = 0,9, +0x612 = 1.
- **Obrażenia** [P: 647, 648]: zwykła ścieżka EEUGAttackUnit/TakeDamage. Gwardia → dom: 6 na trafienie – modyfikator
  wysokości (z rekordu domu 1,0206 przy z gwardii 0 → r = 0,8; min(0,8·6,93; 5,93) → 6); gwardia → mur: 4 (m = 0,35,
  tablica 0x10, rodzina 44). Wiersze tablicy trafień rodziny 3: 0x08 0,23562, 0x0C 0,33, 0x10 0,462; rodziny 44:
  0,1785 / 0,25 / 0,35. Pole rekordu SCN u3c = ułamek HP [P].
- **Mury nie są celem samoczynnym** [W: 0x639AC3 – kandydat z typem +0x612 odrzucony, chyba że szukający ma +0x61E;
  P: 647 – gwardia stoi przy murze w Idle]. Core: `ParametryWalki::atakuje_mury`.
- **Śmierć budynku** [W; P: 645 682/682 próbek, 647 674/676]:
  - EEPMBuilding tryb 2 (0x54BF34): x += (0,5 − r1)·0,01f, y += (0,5 − r2)·0,01f (dwa losowania), z −= dt·0,13f; zmiana
    stosowana tylko gdy floor(x), floor(y) się nie zmieniają;
  - DyingAnimationFinished budynku – EEUCBuilding vt[39] 0x601A4B: z < −2,0 (bezwzględnie, [0x83166C]); 645: 683 takty
    do 6001 (z = −2,00189);
  - 6001 → 6002 → 6003 jak Generic Death (6002 – 59 taktów w 645); po 6003 brak nowej rejestracji w grafie [P];
  - na polu domu pojawia się obiekt gruzu (np. 0x24ac, HP 1), który nie blokuje [P: 647 `mapa_obszar`].
- **Zgłoszenie mapy** [P: 647 – śmierć 52261, +0xD4 = 52262, +0xD8 = 0 w odczycie 52295] przy wejściu w 6000.
- **Przerwany atak** [P: 647 `dom1_przerwany`]: gwardia z rozkazem ruchu w trakcie cyklu 2012/2001/2021 (trafienie co
  2045 ms, 6 HP) przechodzi 2015 → 10003; dom zostaje z HP 12, bez regeneracji i bez ponownego wyboru (dom poza LOS).
- **Próg leczenia rozstrzygnięty** [W: 0x5EDC82, 0x630E07]: kandydat wymaga HP > 0, HP < HPmax i +0x340; dopiero potem
  porównanie HP/HPmax ≤ próg (fcompp, jb). Warunek „HP < HPmax” wyjaśnia pomiar 644 (brak celu przy pełnym HP) bez
  zmiany kierunku porównania progu – rozbieżność etapu 46 usunięta. Core: `potrzebuje_leczenia`.
- Core (etap 47): `Swiat::dodaj_obiekt_budynku`, skrypt `SkryptStanow::wbudowany_budynek()`, `smierc_budynku`,
  `krok_budynku`, kontakty i punkty podejścia pomijają budynki. Godot: budynki potyczki jako obiekty Core
  (`potyczka_e47.json`).

## 36. Etap 48 – prorok, kontakt celu ataku, budynki 2×2 i pozostałości

- **Parametry ruchu z ulepszenia gracza** [P: zad. 650, odczyt +0x34 jednostki]: prorok 216 gracza 1 na czystej mapie e42
  ma +0xA8 a = 2,22222, +0xAC vmax = 0,5, +0xB0 α = 13,57478, +0xB4 ωmax = 15,51404, +0xC8 c8 = 0,07367, +0xC4 c4 = 0,45
  (dbobjects: 2,0 / 0,45 / 12,217 / 13,963 / 0,08185 / 0,5) – ×10/9 dla a, vmax, α, ωmax; c8 = 1/α. Gwardia 422 bez zmian.
  Źródło mnożnika – [N]. Dane: `parametry_jednostek_ee.json` → `ruch_ulepszenia.e42`; `odtworz_scenariusz.gd --ulepszenia=e42`.
- **648 (prorok)**: przy parametrach z ulepszenia, skrypcie Prophet.tai i przekazaniu trasy 0x4A2B29 zgodność od rozkazu
  (48068) do t = 63510 – stan, pozycja i kurs (1688 próbek, wcześniej 1241). Trasa A* identyczna z grą (8 punktów).
  Pierwsza różnica: odepchnięcie od muru gracza 1 (kontakt z budynkiem – `kolizje_objazdy.md`, etap 48) [N w Core].
- **644 pościg rozwiązany** [W: 0x549179; P]: push od atakującego na cel ×0,25 i budzik tylko przy |push| < 0,001 –
  4148/4148 próbek wszystkich jednostek (wcześniej do t = 63817).
- **Atak na budynek od początku** (e48_dom_t0 1v1, e48_dom_3v1, e48_koszary; zad. 650/651) [P: 5 miejsc z gry; reguła
  ogólna – H]: przy PrepareToMove gra zamienia punkt celu na **miejsce podejścia przy budynku**: 0,25 (połowa rozmiaru
  gwardii) za krawędzią obrysu, po dwa miejsca na pole przylegające bokiem (pole + 0,75, potem pole + 0,25), pola
  uporządkowane wg kwadratu odległości pól od pola atakującego (bez narożników), pierwsze wolne. Dom (164, 112):
  (164,75; 113,25), przy zajętym (164,25; 113,25); koszary 2×2: (164,75; 114,25) i (164,25; 114,25). Core (etap 48,
  `punkt_podejscia` dla budynku): dom 1v1 zgodny co próbkę od rozkazu przez podejście, wszystkie trafienia i HP do śmierci
  domu (67635), dalej tylko drganie zapadania (losowania RNG spoza Core); 3v1 i koszary – trafienia, HP i takt śmierci
  zgodne, pierwsze różnice pozycji gwardii 0,02 przy dojściu (47386 / 73295) [N]. Wcześniej Core brał środek budynku
  i wstawiał punkt grafu (różnica 1,7 s po rozkazie). Miejsca na pozostałych bokach i przy innych rozmiarach – [H].
- **Pozostałość** – `architektura_nawigacji.md` (etap 48). **Mury**: obrażenia 4, `atakuje_mury` – bez zmian.

## 37. Etap 49 – miejsca podejścia z czterech stron, EnemyUnitReachable przy martwym celu, budowa

[P: zad. 650, 651, 654 – 11 wyborów miejsca z gry; W: 0x63234D, 0x60B1EA]

**Miejsce podejścia przy budynku.** Wybór w grze (trasa rozkazu ataku, ostatni punkt):

| Budynek | Atakujący z | Wybrane miejsce |
|---|---|---|
| dom (164,112) | S (164,5; 118,5) | (164,75; 113,25) |
| dom | S, drugi przy zajętym | (164,25; 113,25) |
| dom | N (164,5; 106,5) | (164,25; 111,75) |
| dom | E (170,5; 112,5) | (165,25; 112,25) |
| dom | W (158,5; 112,5) | (163,75; 112,75) |
| dom | NE (169,5; 107,5) | narożnik (165,25; 111,75) |
| dom | SW (159,5; 117,5) | narożnik (163,75; 113,25) |
| dom (3v1) | (163,5; 118,5) | (164,75; 113,25) – nie narożnik |
| koszary (164…165, 112…113) | S (163,5; 119,5) | (164,75; 114,25), drugi (164,25; 114,25) |
| koszary | N (165,5; 106,5) | (165,25; 111,75) |
| koszary | W (158,5; 113,5) | (163,75; 113,25) |

Reguła Core (etap 49, [H]): kandydaci na obwodzie odsuniętym o 0,5·rozmiar atakującego – po dwa na pole boku
(pole + 0,25 / + 0,75) i 4 narożniki; kolejność wstawiania – obchód zgodnie z ruchem wskazówek zegara od lewego górnego rogu;
sortowanie stabilne: odległość Czebyszewa pól, boki przed narożnikami, kwadrat odległości pól. Zgodna z 10 z 11 wyborów;
koszary z W – niezgodna (gra (163,75; 113,25), reguła (163,75; 113,75)) [N]. Odrzucona w etapie: miara kąta od środka
budynku (myliła 3v1 i koszary S). Funkcja budynkowa nie jest 0x632A8B (ta filtruje kandydatów po stronie muru, typ
+0x4B4 = 0x19 albo +0x612) [W]. Odtworzenia 654: dom N/E/W/SW i koszary N – zgodne w całości; dom NE – miejsce i trasa
zgodne, różnica kursu od pierwszego obrotu FaceEnemy przy różnicy kąta dokładnie π (kierunek obrotu przy remisie) [N].

**EnemyUnitReachable (0x60B1EA) nie sprawdza HP celu** [W: kod; P: 649 koszary t = 74966 – gwardia w 5002 przy koszarach
w 6000 przechodzi do 2013 CheckRange, dopiero potem do 2025]. Core usunął własne założenie HP > 0 – koszary 3v1 zgodne
co próbkę do zapadania budynku.

**Budowa (pakiet D)** – rozpoznane tylko klasy: komunikat `EEMBuildUnit` (vtable 0x824B40: 0x4C04FA, 0x401A2E, …,
0x4B40EA, 0x4B6F26 – dwa ostatnie wpisy poza procedurami analizy Ghidra), cel `EEUGBuildRepair` (vtable 0x8319F0),
akcja `EEABuild` (0x824AC4). Rozkazu budowy nie wydano – MCP nie ma ścieżki interfejsu budowy (przycisk, podgląd
fundamentu, kliknięcie), a zapis pamięci wykluczają zasady etapu. Pomiaru nie ma [N].
