# Skrypty stanów jednostek (`Unit AI Scripts/*.tai`) i maszyna stanów ruchu w Titan (EE / AoC)

Etap 26 OpenEE. W etapie 25 ustalono, że przejścia stanów jednostki nie są zapisane w EXE, tylko w skryptach. Ten
dokument opisuje:
- format skryptów;
- loader;
- semantykę oceny przejść;
- rzeczywisty diagram ruchu zwykłej jednostki lądowej.

Akcje wejścia w stan i warunki zdarzeń: `ruch_jednostki.md` § 4. Objazd: `kolizje_objazdy.md` § 6.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Pliki

- Skrypty leżą w archiwum `Data/data.ssa` (format `rass`, `narzedzia/eeformaty/ssa.py`), w katalogu `unit ai scripts/`.
  Katalog `Data/Unit AI Scripts` na dysku jest pusty [P].
- EE: 58 plików `.tai` (+ `vssver.scc`); AoC: 71 [P].
- Format: **zwykły tekst ASCII**, CRLF, komentarze `//` [P].
- Do repozytorium nie trafiają. Wypakowane lokalnie: `Testy_MCP/e26/tai_ee`, `tai_aoc`.
- Zwykła jednostka lądowa (gwardia) używa `land.tai`:
  ```
  #include("Generic Attack.tai")  #include("Generic Movement.tai")  #include("Generic Death.tai")
  ```
  - Bohater (Aleksander): `hero.tai` → `Land No Pursuit.tai` + Healer + Patrol, z własnym Idle.
  - Przypisanie skryptu do typu pochodzi z bazy jednostek (typ+8 → typ+0x370) [W].
- **EE ↔ AoC** [P]:
  - `Generic Movement.tai`, `Generic Death.tai` i `land.tai` są identyczne;
  - `Generic Attack.tai` w AoC ma dodatki: EnemyUnitUndetectable (jednostki niewykrywalne), GoalIsCalamity /
    CalamityPreCast (klątwy), rozszerzone LookForEnemies.

  Dla ruchu bez wrogów różnic nie ma.

## 2. Składnia i loader

Loader z pamięcią podręczną: EE 0x619AC0 (AoC 0x62C7E0), mapa nazwa → stany pod 0x941878. Parser 0x619B9D (AoC
0x62C8BD), identyczny w obu grach [W].

| Element | Znaczenie |
|---|---|
| `/` | komentarz do końca linii (wystarczy jeden ukośnik) |
| `#include("X.tai")` | wstawienie pliku w miejscu wystąpienia (rekurencja) |
| `Stan { … }` | stan o nazwie z tablicy B (0x618E11); ten sam stan w kilku plikach to jeden obiekt |
| `Zdarzenie true(S)` | przejście OR z jednym zdarzeniem |
| `allof(Z1,Z2,…)` / `anyof(…)` | AND / OR |
| `true(S)` / `false(S)` | stan docelowy przy warunku prawdziwym / fałszywym (pola +0x2C / +0x30; +0x34 / +0x38 = 100,0 nieużywane) |
| `Zdarzenie remove()` | usunięcie wcześniejszego przejścia o tym zdarzeniu |

**Dopisywanie przejścia** (0x618ED9, AoC 0x62BBAE) [W]:
- przejście OR z jednym zdarzeniem **zastępuje w tym samym miejscu** wcześniejsze przejście OR z tym samym jednym
  zdarzeniem (albo je usuwa przy `remove()`);
- wszystkie pozostałe dopisywane są **na koniec**.

Priorytet = kolejność w połączonym pliku (po include). Dla `land.tai` najpierw przejścia z Attack, potem z Movement.

**Nieznane nazwy** dają numer 0 [H]. Po wczytaniu stan 5000 Idle zawsze istnieje, w razie potrzeby pusty [W].

## 3. Ocena przejść w takcie

Krok maszyny EE 0x5F0F7E (AoC 0x5FF2E8), ocena 0x619FF5 / 0x618CCB (AoC 0x62CD8B / 0x62B9A0) [W]:
```
dla przejść stanu w kolejności listy:
   AND: zdarzenia po kolei, stop na pierwszym fałszu;  OR: stop na pierwszej prawdzie   (leniwie)
   warunek prawdziwy i jest true(S)  → przejście do S, koniec oceny
   warunek fałszywy  i jest false(S) → przejście do S, koniec oceny
   w przeciwnym razie → następne przejście
żadne: stan bez zmian
```
- **W takcie najwyżej jedno przejście** i jego akcja wejścia (typ→vt+0x74). Wyjątek: ponowna ocena, gdy zdarzenie
  spełnił cel inny niż z czoła kolejki (wynik 2 → przełączenie celu 0x5EE965) [W].
- **Leniwa ocena ma znaczenie:** zdarzenia ze skutkami ubocznymi (EnemyUnitSpotted tworzy cel ataku,
  NextWaypointRetrieved dociąga trasę, ObstacleDetected losuje liczbę z globalnego generatora) wykonują się tylko
  wtedy, gdy wcześniejsze warunki do nich dopuszczą [W].
- **Idle „co 350 ms”:** kod pomija ocenę, gdy termin +0x254 jest **mniejszy** od zegara. Każda ocena w Idle ustawia
  termin na zegar + 350, a wejście w Idle na 0xFFFFFFFF. W efekcie Idle jest oceniany **co takt**, odwrotnie niż
  sugeruje pole terminu (BO-8, podejrzenie) [W].
  - [Etap 26 – zastąpione: w `ruch_jednostki.md` § 4 „w Idle najwyżej co 350 ms”.]
  - Pomiar: przejście z Idle do 2015 następuje w takcie zaraz po rozkazie [P].

## 4. Diagram ruchu jednostki lądowej (`land.tai`, bez wrogów)

Połączona tabela po include. Kolumna „Akcja wejścia” dotyczy stanu źródłowego: tak działa po wejściu w ten stan.
Kolumna „Pewność” dotyczy przejścia.

| Stan źródłowy (akcja wejścia) | Prio | Warunek | Cel | Pewność |
|---|---|---|---|---|
| **5000 Idle** (tryb 3; czyści trasę; zdejmuje cel i aktywuje następny; +0x214 = −10000; warunkowo 1 losowanie RNG) | 1 | CanISeeEnemy | CheckRange | [W] |
| **8000 PrepareToMove** (limit prób celu → Idle; inaczej czyści trasę, cel+0x18++, prośba do EEPathManager) | 1 | allof(GoalIsLoadContainer, ContainerInRange) | WaitForTransport | [W] |
| | 2 | NoMoreWaypoints | TurnToUnitFacing | [W] |
| | 3 | MovePreparationComplete (+0x33E i trasa niepusta) | LookForEnemies | [P] |
| **2015 LookForEnemies** (brak akcji) | 1 | allof(CanITargetEnemies, GoalIsPatrol, EnemyUnitSpotted) | CheckRange | [W] |
| | 2 | allof(GoalIsLocation, AttackMoveEnabled, EnemyUnitSpotted) | CheckRange | [W] |
| | 3 | allof(CanITargetEnemies, GoalIsNotPlayerInitiated, GoalIsNotAttack, EnemyUnitSpotted) | true: CheckRange, **false: Advance** | [P] |
| **10003 Advance** (tryb 0, +0x33F = 0, animacja chodu) | 1 | ArrivedAtMoveWaypoint (+0x33F) | GetNextMoveWaypoint | [P] |
| | 2 | ObstacleDetected (+0x20C albo +0x248 > T, losowanie co takt) | RepathAroundObstacle | [W] |
| | 3 | allof(OneWaypointRemaining, GoalIsUnit) | ReacquireEnemyUnit | [W] |
| **9000 GetNextMoveWaypoint** (zdejmuje 1 punkt trasy) | 1 | anyof(EnemyUnitDestroyed, CeaseFire) | ShouldIReturn… | [W] |
| | 2 | allof(GoalIsAttackLocation, LocationInWeaponRange) | FaceLocation | [W] |
| | 3 | allof(AttackerIsRangedUnit, UnitInWeaponRange) | FaceEnemyUnit | [W] |
| | 4 | EnemyUnitMoved | CheckRange | [W] |
| | 5 | allof(GoalIsLoadContainer, NextWaypointRetrieved) | GetContainerProgress | [W] |
| | 6 | ShouldMoveToNextAutoWaypoint (9016) | GetNextAutoWaypoint (8021) | [W] |
| | 7 | NextWaypointRetrieved | **true: LookForEnemies, false: TurnToUnitFacing** | [P] |
| **9002 RepathAroundObstacle** (objazd, `kolizje_objazdy.md` § 6) | 1 | MovePreparationComplete | true: Advance, false: ShouldIReturn… | [W] |
| **8021 GetNextAutoWaypoint** (zdejmuje cel) | 1 | UnitHasGoal | true: PrepareToMove, false: ShouldIReturn… | [W] |
| **9006 TurnToUnitFacing** (tryb 5: hamowanie z jazdą, potem obrót) | 1 | GoalIsLoadContainer | GetContainerProgress | [W] |
| | 2 | anyof(UnitFacingNotRequired, CompletedUnitFacing) | ReacquireGoal | [P] |
| | 3 | UnitHasGoal | false: ReacquireGoal | [W] |
| **5001 ReacquireGoal** (akcja 0x61B241) | 1 | BlockedByWall | ShouldIReturn… | [W] |
| | 2 | GoalIsUnit | ReacquireEnemyUnit | [W] |
| | 3 | GoalIsAttackLocation | FaceLocation | [W] |
| | 4 | GoalIsLocation | **Idle** | [P] |
| | 5–7 | GoalIsExplore / GoalIsLoadContainer / UnitHasGoal(false) | FindUnexploredArea / ReacquireLoadContainer / ShouldIReturn… | [W] |
| **2025 ShouldIReturnToInitialContactLocation** | 1 | allof(HasValidICL, ReturnsToICL, GoalIsNotPlayerInitiated) | true: ReturnToICL, false: Idle | [W] |

**Rola stanów** [W, P]:

| Stan | Rola |
|---|---|
| 8000 | przygotowanie trasy |
| 2015 | rozglądanie się za wrogiem przed każdym odcinkiem; bez wrogów przechodzi do Advance w 1 takt |
| 10003 | jazda |
| 9000 | zdjęcie punktu i decyzja: następny punkt / koniec trasy / następny cel automatyczny |
| 9002 | objazd |
| 9006 | hamowanie i obrót do zadanego kierunku |
| 5001 | rozstrzygnięcie po dojściu: dla celu-miejsca Idle |
| 8021 | przejście do następnego celu +0x32 |
| 5000 | spoczynek |

**Zmierzone przebiegi** (każda strzałka to 1 takt; EE 500, 509, 517–518; AoC 505, 525) [P]:
```
rozkaz:          5000 → 2015 → 10003 (pierwszy takt ruchu)        [8000 nieuchwycony – wejście z obsługi grupy]
każdy punkt:     10003 → 9000 → 2015 → 10003
koniec trasy:    10003 → 9000 → 9006 → 5001 → 5000
cel w miejscu:   5000 → 2015 → 10003 (1 takt, v = 0) → 9006 → 5001 → 5000   (EE 517)
po kolizji:      10003 (v → 0) → 9000 → 9006 → 5001 → 5000              (EE 518)
śmierć:          … → 6000 Dying → 6001 → 6002 UnitRotting → 6003 Dead   (Generic Death.tai; EE 514, 524)
```

**Anulowanie rozkazu** [W]:
- nowy rozkaz przechodzi przez obsługę grupy do stanu 8000 PrepareToMove (`kolejka_rozkazow.md`);
- trasa jest czyszczona, prędkość zachowana.

**Shift** [P, etap 25]:
- 9006 zachodzi od razu, bo UnitFacingNotRequired jest prawdziwe przy więcej niż jednym celu w kolejce;
- potem 5001 → 5000; wejście w Idle aktywuje następny cel, a stąd 8000.

## 5. Niewiadome

- [N] Kto dokładnie wywołuje 8000 przy rozkazie (obsługa grupy ustawia stan bezpośrednio – `cele_jednostek.md`); w
  pomiarze stan 8000 trwa krócej niż 1 próbka.
- [N] Pole rekordu bazy jednostek z nazwą skryptu; skrypty innych typów (np. Land Patrolling) dla ruchu.
- [N] Warunki CanITargetEnemies i postawy (+0x208) poza ruchem bez wrogów.

## 6. Aktualizacja etapu 27

- **BO-8 potwierdzone w kodzie** [W→P co do kodu]: porównanie terminu +0x254 z zegarem to skok `jb` (bez znaku). Ocena
  jest pomijana tylko wtedy, gdy termin < zegar. Każda ocena ustawia termin = zegar + 350, więc w Idle ocena zachodzi
  co takt. Wejście w Idle zużywa 2 losowania z globalnego generatora (warunkowo). Ma to znaczenie dla determinizmu
  (`specyfikacja_ruchu_godot.md` § 5).
- **Wyjście z grupy:** wejście w Idle (EE 0x55C567) odłącza jednostkę od grupy ruchu, a grupa przelicza parametry
  (`kolizje_objazdy.md` § 11) [P].
- **Sekwencje stanów zmierzone w etapie 27** (EE 532, 535, 536):
  10003 → 9000 → 2015 → 10003 … → 9006 → 5001 → 5000, zgodnie z diagramem § 4 [P].
  Kolizja z regułą (a): 10003 → 9006 → 5001 w jednym–dwóch taktach [P].
- **Nie zweryfikowano kontrolowanym testem:** Shift (aktywacja następnego celu), automatyczny punkt +0x32, porzucenie
  rozkazu, objazd 9002 [N].

## 7. Aktualizacja etapu 31 – stany walki (`Generic Attack.tai`, `land.tai`)

**Diagram walki wręcz** (EE 578/580, gwardia; [P] sekwencje, [W] warunki):
```
Idle 5000 ──CanISeeEnemy 20002 (licznik szukania 0)──▶ cel EEUGAttackUnit ──▶ 8000 PrepareToMove (punkt podejścia)
  ▶ 10003 ruch ⇄ 5002 ReacquireEnemyUnit / 2013 CheckRange / 2024 ShouldIFollowEnemyUnit
  ▶ 2013 CheckRange ──UnitInWeaponRange──▶ 2012 FaceEnemyUnit ──FacingEnemyUnit (≤ 2,5°)──▶ 2001 AttackEnemyUnit
  ▶ (1122 ms – trafienie) ▶ 2021 WaitForReload ──Reloaded (+0x2A0 == 0)──▶ 2012 …
  ▶ EnemyUnitDestroyed 2003 ──▶ 2025 ShouldIReturnToInitialContactLocation ──▶ 5000 (szukanie następnego celu)
cel atakowany:  UnderAttack 2018 ──▶ RetaliateAgainstAttacker 2020 / RunFromAttacker 2019 (obywatel: ucieczka 8000 → 10003)
śmierć:         HP 0 ──▶ 6000 Dying (ten sam takt) ──▶ 6001 / 6002 ──▶ 6003
```
- Wejścia stanów (cel EEUGAttackUnit vt+0x40, 0x60B26F): 2012 – tryb fizyki 1, animacja 13 gdy niezwrócony, trasa
  czyszczona; 2001 – tryb 1, animacja 0, +0x2A0 := ulepszenie+0x138 (AoC: 0x5FEA22), +0x2AC := 0; 2021 (0x61AF33) –
  tryb 3, gdy animacja ≠ 0 i bit 0 typ+0x5D4 = 0; 2013 (0x61ADD7) – zapis ICL (+0x118/+0x11C) i kursu +0x214 [P].
- **Zdarzenia celu** (vt+0x64 0x60B5CB) oceniane przed dispatcherem jednostki. Gdy czołowym celem nie jest
  `EEUGAttackUnit`, zdarzenia celu (EnemyUnitDestroyed, UnitInWeaponRange, FacingEnemyUnit, InsideFiringArch,
  EnemyUnitNoLongerVisible, UnitNotOnMap) są w Core **fałszem z diagnostyką** (licznik zdarzeń nieobsłużonych), nie
  cichym fałszem – w etapie 30 EnemyUnitDestroyed bez celu dawał prawdę i psuł ruch.
- Core: `SkryptStanow::wbudowany_land()` zawiera teraz także CheckRange, ShouldIFollowEnemyUnit, FaceEnemyUnit,
  ChangeTargetForSpecialEnemy, AttackEnemyUnit, WaitForReload, InitialAttackState, ReacquireEnemyUnit,
  RetaliateAgainstAttacker, RunFromAttacker, ReturnToInitialContactLocation, Dying, ResourcesRotting, UnitRotting.
  Cykl ruchu (S1–S7, skrót c36721320b3595e4) bez zmian [P].
- [N] CompletedUnitFacing przy przejściu 9006 → 5001: reguła „ω == 0” daje 1 takt różnicy w 578 G1 (takt 48);
  usunięcie warunku psuje S2/S4b – właściwy warunek nieustalony.
- [N] Postawy (+0x208: pościg, powrót, ucieczka) inne niż domyślne – nie mierzone.
