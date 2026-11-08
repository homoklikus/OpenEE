# OpenEE – raport etapu 31: pełny cykl ataku w OpenEE Core, wybór celu i przeładowanie AoC

Etap 31 doprowadza walkę wręcz do stanu, w którym jednostki OpenEE Core **same** wykonują pełny cykl: wykrycie →
wybór celu → podejście → obrót → wejście w zasięg → atak → przeładowanie → kolejny atak → śmierć celu → powrót.
Moment rozpoczęcia ataku nie jest już parametrem. Walka jest częścią `Swiat` (jedna lista jednostek, jedna kolejka
celów, jedna maszyna stanów, wspólny zegar i RNG).

Szczegóły:
- `docs/titan/walka.md` § 8–14 – wybór celu, podejście, zasięg, łuk i obrót, przeładowanie AoC, obrażenia klas, cykl
  w Core i porównanie z grą;
- `docs/titan/skrypty_stanow.md` § 7 – stany i zdarzenia walki;
- `docs/titan/BLEDY_ORYGINALU.md` BO-10 – błąd w punkcie przechwycenia;
- `docs/titan/struktury_titan.md` (z `dane/titan/struktury_titan.json`, 109 pól) – nowe pola walki;
- `docs/PLAN_REKONSTRUKCJI_TITAN.md` § 4.8 – prognoza;
- `docs/cpp/ARCHITEKTURA_CORE.md` § 13, `docs/cpp/INTEGRACJA_GODOT.md` § 6.

**Oznaczenia:** [P] potwierdzone kodem i pomiarem; [W] wniosek z kodu; [H] hipoteza; [N] nieustalone.

**Rozdział wyników.** „Gra” – pomiar w oryginalnym EE (`Empire Earth.exe` e352d7ae…) albo AoC (`EE-AOC.exe`
db8fc5ce…) przez Riverlands_MCP. „Model” – dane syntetyczne albo obliczenia Core bez serii z gry.

**Środowisko.** Zlecenie wskazywało Debian 13. Polecenia na komputerze użytkownika wykonywały się w maszynie
wirtualnej **Ubuntu 22.04** (GCC 11.4, CMake z `~/.local/bin`, Godot 4.7.2); część kontroli – w kontenerze
**Ubuntu 24.04** (GCC 13.3). Debian 13 nie był dostępny. Wyniki obu kompilatorów są identyczne (skróty niżej).

## 1. Stan wyjściowy

- Commit `48282c6d` (etap 30), sprawdzony na początku etapu.
- CTest 18/18 grup, GDExtension 22/22, Godot 324/324, 11 plików testów Riverlands_MCP, narzędzia titan 14/14,
  S1–S7 bitowo, Debug = Release.
- Walka w etapie 30: wzór obrażeń, przeładowanie, czas trafienia, śmierć – w module niezależnym od `Swiat`;
  takt pierwszego ataku podawany z pomiaru; zdarzenia walki w `Swiat` – fałsz z licznikiem.

## 2. Narzędzia

| Narzędzie | Zmiana | Koszt (szac.) |
|---|---|---|
| Riverlands_MCP `ee_walka` | odczyty: `walka_parametry_typu` (typ, ulepszenie, obiekt wizualny, wiersz dyplomacji), `walka_priorytety` (wagi wyboru celu EE/AoC), `walka_przeladowanie_aoc` (lo/hi), `walka_globalny` (odczyt globalny, także przez wskaźnik), tablice obrażeń AoC; surowe bajty obiektu AI (+0x208/+0x20C) w rejestracji | ok. 15 min |
| `narzedzia/titan/pomiar_core.py walka` | okno walki → `openee_walka_v1` (stan startowy z kolejką celów, próbki co takt: HP, liczniki, cel; wejścia w atak ze stanem RNG przed/po; kontrola wariantu tablic) | ok. 15 min |
| testy | `test_ee_etap31.py` (6 testów MCP, pamięć podstawiona), 3 nowe testy `pomiar_core walka` (17/17), `core_walka_swiat` | ok. 15 min |
| statyka | skrypty dezasemblacji w lokalnym katalogu roboczym (Capstone), `switch_titan.py` do dispatcherów 0x61B6AB / 0x60B5D9 | wielokrotnego użytku |

Odczyty są tylko odczytami (bez zapisów do pamięci gry). Riverlands_MCP pozostaje lokalnym repozytorium.

## 3. Funkcje wyboru celu

| Funkcja | EE | AoC | Pewność |
|---|---|---|---|
| CanISeeEnemy 20002 | 0x61BFF4 | – | [W] |
| szukanie (LookForEnemies) | 0x61AC11 | – | [W] kod, [P] wynik |
| promień okna | 0x62EBD2 / 0x62EBEE | – | [W] |
| przegląd stref | 0x63969A | – | [W], kolejność w strefie [N] |
| filtr kandydata | 0x639993 | – | [W] |
| ocena kandydata | 0x6399CA | wagi [0x8E60C0] | [W] kod, [P] wybory |
| mgła | 0x631B64 | – | [W], reguła [H] |
| osiągalność | 0x62D696 | – | [N] |

Kolejność, odrzucenia, funkcja punktowa, remisy i wagi: `walka.md` § 9. Wagi EE i AoC są identyczne [P].
Zależność od stanu: szukanie blokuje licznik +0x2AC (AoC +0x2B0), z wyjątkiem celu-miejsca bez jednostki;
cel od gracza wyłącza wariant ICL [W]. Nazwy funkcji – tylko tam, gdzie wynikają z nazw stanów/zdarzeń w tablicach
rejestracji; pozostałe opisano rolą.

## 4. Wykrywanie

- Szukanie co 2000 ms (typ+0x564), licznik −34 ms na takt, w takcie wyboru odczyt 1966 [P: 578, 580].
- Okno ±ceil(max(zasięg·f, LOS)) komórek; odrzucenie d² > +0x44 [W].
- Widoczność: pomiar zgodny z „środek komórki kandydata w odległości ≤ LOS” [H]; mapa mgły nie jest odczytywana.
- Wejście/wyjście z LOS: w 578 G1 Troja (stoi) wybiera cel w 34. takcie, Argos (w ruchu) w 50. takcie – oba po
  wejściu przeciwnika w zasięg widzenia [P]. Wyjście z LOS (EnemyUnitNoLongerVisible) – nie zmierzone [N].

## 5. Podejście i pościg

PrepareToMove 0x6222A8 → cel EEUGAttackUnit vt+0x08 0x60AF05:
- cel w ruchu – przechwycenie 0x62C963 (tylko gdy trasa celu > 1 punkt) z błędami dodawania (BO-10); punkt z gry
  odtworzony bitowo [P];
- cel stojący – 8 slotów 0x63234D (R = 0,5·s_ja + 0,5·s_cel), pierwszy przejezdny wg odległości [P];
- pole celu := pole jednostki docelowej (0x60B9D8) [P].
W Core: istniejąca kolejka celów (cel „jednostka”) i istniejący PrepareToMove/A* – bez drugiej nawigacji.

## 6. Zasięg i łuk

Zasięg wręcz 0x631935 → 0x631501: 4·d² < ((0,071 + s_ja + s_cel)·1,42)², gwardia 0,7604 [P]. Łuk: InsideFiringArch
gdy |kąt| ≤ typ+0x45C/2 (gwardia 20°) [P odczyt]; zasięg minimalny typ+0x41C [W].

## 7. Obrót

FacingEnemyUnit: |UMArcCos(przód · do_celu)| ≤ 0,0436332 (2,5°), przód obrócony o typ+0x458 [W kod, P skutek].
FaceEnemyUnit włącza tryb fizyki 1 (EEPMLand vt+0x10 0x54DA82): obrót do celu, hamowanie v' = max(0, v − dt·a).
Brak dowolnego kąta – w Core `TrybRuchu::do_celu` z tymi samymi tablicami trygonometrii co ruch.

## 8. Cykl EE

578 G1 (1:1, gwardia Argos z rozkazem ruchu kontra gwardia Troi): gra – 6 + 6 trafień (31 i 16), Core – 12
trafień, te same cele. **Pierwsza różnica: takt 48** (stan ruchu 9006 vs 5001 – CompletedUnitFacing o 1 takt
wcześniej w grze), potem szukanie w takcie 50 i przesunięcie cyklu o 1 takt (pierwsza różnica HP – takt 167).
986 porównań: stan różny w 73, HP w 42, pozycja śr. 0,217 maks. 0,69 pola. Bez ukrytych korekt czasu startu.

## 9. Cykl AoC

580 G1 (AoC 1:1): przebieg stanów jak EE; trafienia 34 (człowiek → komputer) i 15; śmierć w takcie 534 [P].
Symulacja Core okna AoC – **SKIP**: brak tablic obrażeń AoC (odczyt w zadaniach 583–584 nie doszedł do gry).

## 10. Przeładowanie losowe (AoC 0x5FEA22)

`fistp(f32((lo + r·(hi − lo))·bazowe))`, lo/hi = [[0x92FCA8]+0x984/+0x988] = 0,8/1,2 [P odczyt].
Seria gry: 27/27 przeładowań w 580 (14/14 w oknie testowym) to wynik jednego kroku LCG osiągalnego w danym
takcie [P]. Core: `WariantTitan::aoc()` – jedno losowanie na wejście w 2001; EE – brak losowania.

## 11. 1:N

578 G3 (EE, 2:1): gwardia Troi ad3 i gwardia Argos 857 atakują się (cele AI, nie od gracza); druga gwardia Argos
858 przychodzi rozkazem ruchu i wybiera ad3 w takcie 230. ad3 ginie w takcie 390 (dwa trafienia 31 w taktach 330
i 334 – dwaj atakujący); obaj zwycięzcy: 2025 → Idle [P]. Core: 1287 porównań, pierwsza różnica w takcie 53–58
(dryf kolizji 0,003 → atak o 1 takt później); wybór celu przez 858 – w grze w takcie 230, w Core w tym takcie jeszcze brak celu (skutek wcześniejszego przesunięcia).
Syntetyczny test 2 na 1 w `core_walka_swiat` (model). Wynik: **częściowy**.

## 12. Obrażenia klas

- Gwardia → obywatel 42 = 15 · 2,8 (tablica 0x10, klasa 36, rodzina 48) [P].
- Gwardia na zboczu: 13 zamiast 16 (578 G3) – modyfikator wysokości 0x61E500 [P skutek, W kod]. Konfiguracja
  [0x917BB8] nieodczytana [N] → Core r = 1 z założeniem w diagnostyce.
- Kolejność: m·w (f32) → ·atak (f32) → −pancerz → r (wysokość) → ogień bratobójczy → fistp(f32), min 1.
- AoC: 15 / 34 (12 na zboczu) [P pomiar]; tablice AoC – adresy [W], wartości [N].
- Niewyjaśnione [N]: EE 579 – obywatel otrzymał 21 przy dz ≈ 0; AoC obywatel 36/23. Ulepszenia – nie badane.

## 13. Integracja ze Swiat

`docs/cpp/ARCHITEKTURA_CORE.md` § 13. Jedna lista jednostek, wspólne id, pozycje, RNG i zegar; cele ruchu i ataku
w jednej kolejce; jedna maszyna stanów; fizyka i nawigacja bez duplikatów; decyzje w C++, GDExtension tylko
przekazuje dane i migawki (`ustaw_walke`, `ustaw_tablice_walki`, `rozkaz_ataku`, `walka`, `zdarzenia_walki`).
`PojedynekTitan` i test `core_walka` zostają bez zmian.

## 14. .tai

Stany walki wbudowane w `wbudowany_land()` (lista w `skrypty_stanow.md` § 7). Zdarzenia celu przy celu innym niż
jednostka – fałsz z licznikiem (nie cichy fałsz). Cykl ruchu nienaruszony: S1–S7 bitowo, skrót c36721320b3595e4.
CompletedUnitFacing (reguła ω == 0) – niezmieniona, bo usunięcie warunku psuje S2/S4b; właściwa reguła [N].

## 15. Testy porównawcze

| Przypadek | id celu | pozycja | prędkość/obrót | stan .tai | trafienia/HP | przeładowanie | RNG | śmierć | ocena |
|---|---|---|---|---|---|---|---|---|---|
| 578 G1 EE 1:1 | dokładne do t. 50 | dokładne do t. 48 | model | różnica t. 48 | 12 = 12, przesunięte o 1 takt | 1 takt | EE bez losowań | brak w oknie | model |
| 578 G3 EE 2:1 | dokładne ad3/857; 858 – spóźnione | dryf 0,003 od t. 53 | model | różnica t. 58 | przesunięte | 1 takt | EE bez losowań | ad3 – przesunięta | częściowe |
| 580 G1 AoC 1:1 | – | – | – | – | – | 14/14 dokładnie | dokładne (LCG) | – | brak danych (tablice) |
| synt. 1:1 / 2:1 | – | – | – | – | HP 103 / 0, skrót zdarzeń 9ddaf83720646edb | – | – | t. śmierci 294 (2:1) | model |

Nie wykonano [N]: wróg za przeszkodą, rozkaz ataku od gracza, wyjście wroga z LOS, ucieczka/utrata celu przy
żywym wrogu – zadania 582–584 nie przeszły odprawy (§ 22).

## 16. Różnice EE/AoC

Wagi celu, progi, stany i numery zdarzeń – identyczne [P]. AoC: przeładowanie losowe [P], licznik szukania +0x2B0,
animacja +0x264, przeładowanie +0x2A4 [P]; obrażenia AoC inne przy tych samych parametrach (tablice) [N].

## 17. RNG i determinizm

EE: walka bez losowań [P]. AoC: jedno losowanie na atak [P]. Core nie dodaje innych wywołań RNG. Debug = Release
(GCC 11.4 i GCC 13.3): skrót zdarzeń pojedynku 9ddaf83720646edb, liczby porównań i różnic 578 identyczne,
S1–S7 c36721320b3595e4. Zabezpieczenia f32 zachowane (zapisy przez `f32()`, emulacja x87 w ocenie celu).

## 18. MCP i statyka

Statyka: dispatchery `switch_titan.py`, dezasemblacja Capstone; adresy z pewnością w § 3 i w `walka.md`. Pomiar:
zadania 572–584 (13), w tym 4 serie walki i odczyty typów/wag (575, 576). Schemat struktur: +6 pól (109), m.in.
typ +0x41C/+0x458/+0x45C/+0x564/+0x61A, jednostka +0x208 i +0x2AC (licznik szukania).

## 19. Efekt automatyzacji

Narzędzia etapu 30 (rejestrator walki, `pomiar_core`, schemat) pozwoliły w ok. 25 min od początku eksperymentów
mieć serie 1:1 i 2:1 w EE i AoC. Ręczne przygotowanie okna (etap 30) zastąpił `pomiar_core walka` – konwersja
okna z gry do testu Core trwa sekundy; sprawdzenie przeładowania AoC na ciągu LCG – automatyczne w CTest.
Koszt nowych narzędzi ok. 45 min; zysk – każde kolejne okno walki bez pracy ręcznej [W].
Słabość: start gry przez odprawę zależy od wolnego pulpitu (§ 22) – automatyzacja nie usunęła tego ryzyka.

## 20. Prognoza

`PLAN_REKONSTRUKCJI_TITAN.md` § 4.8: pozostało A ≈ 5,8 J (≈ 6,4 tyg.), B ≈ 12,7 J (≈ 16 tyg.), C ≈ 20,2 J
(≈ 29 tyg.) w modelu realistycznym; zużyte na walkę od etapu 30 ≈ 3,5 h. Prognoza nie skraca się z samego
zakończenia etapu – część zużytego nakładu zrównoważyły nowe niewiadome.

## 21. Regresja

| Kontrola | Wynik |
|---|---|
| CMake Release (GCC 11.4, z GDExtension) | OK |
| CMake Debug (GCC 11.4) | OK |
| CTest Release / Debug | **19/19** (nowa grupa `walka_swiat`) |
| GDExtension | **22/22** (21 dotychczasowych w tym środowisku + 1 nowy test walki) |
| Godot | **324/324** |
| Riverlands_MCP | **12** plików testów OK (11 + `test_ee_etap31.py`) |
| narzędzia titan | **17/17** (14 + 3) |
| S1–S7 | bitowo, skrót c36721320b3595e4 |
| `git diff --check` | czysto |
| brak danych prywatnych | SKIP części lokalnej (`core_walka_swiat`), symulacja AoC – SKIP (brak tablic) |

Uwaga: wersja testów GDExtension z etapu 30 daje w tym środowisku 21 (nie 22) zaliczonych – różnica w liczeniu
po stronie środowiska, nie zmiana testów.

## 22. Problemy

- **Odprawa scenariusza:** w zadaniach 572–574 i od 15:45 UTC (582–584) gra nie przyjmowała kliknięcia potwierdzenia odprawy (kursor zablokowany
  w rogu 1023 × 767), gdy pulpit użytkownika był aktywny. Zadania 582 (EE: cfg wysokości, rozkaz ataku, ucieczka),
  583 i 584 (AoC: tablice obrażeń, wagi, cfg) skończyły się na starcie. Bez nich: brak tablic AoC, cfg wysokości,
  rozkazu ataku gracza i utraty celu przy żywym wrogu.
- **Rozjazd o 1 takt** od ok. 50 taktu: CompletedUnitFacing (maszyna ruchu), kolejność listy fizyki [H], dryf
  kolizji – nie walka sama w sobie.
- Kolejność kandydatów w strefie, osiągalność 0x62D696 i mapa mgły – [N], w Core założenia z licznikiem.

## 23. Rekomendacja etapu 32

1. Powtórzyć zadania 582–584 przy wolnym pulpicie: tablice obrażeń AoC, cfg [0x917BB8] (wysokość), rozkaz ataku
   gracza, ucieczka/utrata celu, wróg za przeszkodą.
2. Ustalić regułę CompletedUnitFacing i kolejność listy fizyki – to one dają pierwszy rozbieżny takt.
3. Odczytać mapę mgły i kolejność stref (0x63969A, [0x919774]+0xB0), sprawdzić osiągalność 0x62D696.
4. Dopiero potem strzelcy (zasięg > LOS, tryb wag 2) i pociski.

Etap 32 nie został rozpoczęty. Brak `git push`.
