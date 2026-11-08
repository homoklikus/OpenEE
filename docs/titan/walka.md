# Walka w Titan – podstawy: cel ataku, cykl ataku, obrażenia, śmierć (EE / AoC)

Wpis atlasu Titan, etap 30 – **początek** rekonstrukcji walki; etap 31 – wybór celu, podejście, obrót, pełny cykl w Core (§ 8–14). Zakres: pojedynek dwóch zwykłych jednostek lądowych
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
