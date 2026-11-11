# Raport etapu 46 – reakcja na obrażenia, Healer.tai, źródła losowań i dynamiczny graf

Najważniejsze wyniki etapu:
- **Laboratorium działa.** Sterowanie grą przez MCP przechodzi przez odprawę i wczytuje scenariusze (zad. 643–646).
  Nowa diagnostyka `laboratorium` rozpoznaje blokadę pulpitu, konflikt kursora, brak fokusu, brak gry i odczytu pamięci.
- **578 G3, takt 414 – wyjaśnione [P].** Cel gwardii 0x1000858 to rozkaz gracza (pochodzenie +0x1C = 1, EEUGLocation
  utworzony 94319), czyli prawy klik MCP dostarczony z opóźnieniem 84 s. Nie jest to reakcja sojuszników. Z rozkazem
  w danych testu 578 G3 e45 jest zgodne w całym oknie (1286/1286, bez rozbieżnego taktu).
- **Brak reakcji sojuszników na atak [P].** Gwardia komputera w Idle 2,8 i 10 pól od atakowanej nie reaguje (644,
  oba przebiegi zgodne z Core co próbkę: 4426/4426 i 4412/4412). TakeDamage 0x6172BC nie rozsyła poleceń do sojuszników.
- **Bohater 619 – zgodny w całości [P].** TakeDamage w Idle → UnderAttack (EEUC +0x370 ze stanem 2018) → ReacquireGoal
  5001 → 2025 → 5000 oraz cykl Healer.tai co 30 taktów. 619 i 620: wszystkie jednostki zgodne do końca nagrań
  (dawniej bohater od t = 79045, a stany 16000/2025 pomijane).
- **Healer.tai działa w Core** (szukanie, cel EEUGHeal, podejście, obrót, leczenie +50 HP co 1000 ms, przerwanie).
  Parametry potwierdzone odczytem pamięci typu i pomiarem 644 (bohater z jednym i dwoma rannymi).
- **FleeDanger: zagrożenie = najbliższa jednostka atakująca obywatela (0x62FE01) [W],** nie „ostatni trafiający”.
- **Źródło dodatkowych losowań RNG [P]:** ruchome obiekty Świata (zwierzęta, ryby – 19 z 22 obiektów kolejki fizyki).
  Na mapie bez zwierząt kolejka ma 3 obiekty, a Core z jednym stanem startowym generatora zgadza się co takt przez
  190 taktów. Pozostałe losowania (gdy wszystkie jednostki stoją) – [H] AI gracza komputera.
- **Dynamiczny graf:** termin przebudowy potwierdzony w grze (+0xD4 = czas śmierci domu + 1 ms [P]). Core:
  zgłoszenie, harmonogram i jedna przebudowa po terminie (test). Zakres przyrostowy 0x4278C3 – [N] (Core przebudowuje
  całość, raz).
- Potyczka przypisuje skrypty `.tai` z danych typu. Nowa potyczka integracyjna z bohaterem i obywatelem (14 leczeń).

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.
Statusy: zbadany / zaimplementowany / test syntetyczny / potwierdzony w EE / zintegrowany z Godotem – podawane osobno.

## 1. HEAD początkowy i końcowy

- Początek: `d1363cb` (etap 45; lokalny stan = GitHub).
- Koniec: jeden lokalny commit etapu 46. Bez push, pull, fetch, reset, rebase i clean.
- Poza commitem: `godot/project.godot`, `konfiguracja/uzytkownik.cfg.przed_etapem11` (pliki użytkownika) oraz
  Riverlands_MCP (osobne lokalne repozytorium: `ee_laboratorium.py`, test, krok `laboratorium`).

## 2. Status środowiska automatyzacji

- Pulpit (zrzut świeży, aktywny), gra uruchamiana przez MCP, odczyt pamięci działa. Test minimalny 643 (e31_a:
  start, odprawa, odczyt 200 jednostek) – zaliczony. Zadania 644, 645, 646 wykonane bez błędów sterowania.
- `laboratorium` (Riverlands_MCP, tylko odczyt, bez przejmowania fokusu i kursora): pulpit, proces i pamięć EE, okno
  gry, okno aktywne, ruch kursora w oknie 0,6 s. Wynik: gotowe / zablokowane / gra_niezaladowana / nieustalone.
  Wywoływany przed i po starcie każdego scenariusza w 644–646 (zawsze „gotowe”). 6 testów jednostkowych.
- `ee_test_start` (asynchroniczny test scenariusza) nie zamyka odprawy kampanii – nie nadaje się do map
  z odprawą; do eksperymentów służy `start_testowy` (zamyka odprawę kliknięciem).

## 3. Przyczyny wcześniejszych awarii

- 642 (etap 45): `start_testowy` kończył się w menu na etapie wczytywania scenariusza; dziennik kliknięć odprawy nie ma
  wpisów po 15:14 – awaria była wcześniej, w nawigacji menu. Dziś ta sama ścieżka działa. Przyczyna – [N]; najbardziej
  prawdopodobny konflikt wejścia z innym procesem sterującym pulpitem [H] (nie da się już sprawdzić).
- **Opóźnione rozkazy MCP [P]:** prawy klik `obs_rozkaz` bywa wykonywany przez grę z dużym opóźnieniem: 578 (zad. 641)
  – 84 s, 644 pościg – 24,7 s (cel EEUGLocation z czasem utworzenia długo po kroku). Przyczyna w ścieżce wejścia [N].
  Skutek: eksperymenty z rozkazem w ustalonym momencie wymagają sprawdzenia czasu utworzenia celu w nagraniu; narzędzia
  porównania biorą rozkaz z nagrania (czas utworzenia celu), nie z czasu kroku MCP.

## 4. Mechanizm reakcji sojuszników i TakeDamage [W, P]

TakeDamage 0x6172BC (ofiara = obiekt, +0x30 – część EEUnit):
1. Napastnik żywy, innego gracza, wrogi (tablica +0x9E4), typ napastnika spełnia 0x631A09 (nie klasy 9/11/12/20
   i kilka typów) → +0x1DC := napastnik (0x617917, uchwyt z licznikiem).
2. Ofiara w Idle (5000) i obiekt EEUC ofiary ma stan 2018 w mapie +0x370 (0x622017) → stan 2018 UnderAttack
   i akcja wejścia (vt+0x74). Bohater 173 ma EEUC = EEUCLandPriest (odczyt RTTI +0x2C w grze) – reaguje [P: 619];
   obywatel (EEUCLandCitizen) – nie [P: 638, 644]. Rejestracja 2018 w EEUC innych klas – [N].
3. Statystyki gracza (vt+0x84): EEPlayer 0x557147 – licznik obrażeń i flaga alarmu +0xA28; EEComputerPlayer
   0x43163C – czas ostatniego ataku +0xEE0 i flagi +0xEF7/+0xEF8. **Brak poleceń dla innych jednostek.**
4. Alarm minimapy 0x55EDD2 (gracz +0x928). Odjęcie HP, śmierć.

Pomiar 644 [P]: druga gwardia komputera w Idle 2,8 pola i 10 pól od atakowanej – bez zmiany stanu przez cały bój,
Core identycznie (sojusz_blisko 4426/4426, sojusz_daleko 4412/4412 próbek). Warianty „za przeszkodą”, „w ruchu”,
„walczący” – niewykonane (mechanizm nie istnieje w kodzie, więc nie dają nowej informacji) [W].

Core: zapis +0x1DC i przejście do 2018 (parametr typu `reakcja_underattack` = EEUC z 2018), stan UnderAttack w skrypcie
świata (Generic Attack: CanFlee → RunFromAttacker; allof(CanITargetEnemies, …) → RetaliateAgainstAttacker, inaczej
ReacquireGoal). Zdarzenia UnitIdleOrAttackingDefenselessBuilding, IsAttackerInRetaliationRange, CanDamageAttacker,
AttackerIsReachable – nieodwzorowane (fałsz) [N]; dla bohatera nieistotne (CanITargetEnemies = fałsz).
Statusy: zbadany [W], zaimplementowany, test syntetyczny (GDExtension), potwierdzony w EE (619/620, 644).

## 5. Wyniki 578 G3 i 619

| Przebieg | Wynik |
|---|---|
| 578 G3 e45 (z rozkazem z nagrania) | 1286/1286, stan/HP/+0x2A0/cel/pozycja/kurs/ω bez różnic, brak rozbieżnego taktu |
| 590 G1 e45 | 1108 porównań bez różnic; 8 próbek ze spóźnionym tylko ω pominiętych jawnie (kryterium jak dla stanu) |
| 619 (graf z SCN) | wszystkie 7 jednostek zgodne (bohater 7272/7273, 1 próbka nieaktualna) – bez pomijania 16000/2025 |
| 620 | wszystkie jednostki zgodne do końca |
| 578 G3 / 590 G1 e31 (dawne) | pierwsze różnice 190 (kurs) i 98 (kurs) – bez listy fizyki w tamtych nagraniach [N] |

Zmiany w narzędziach: `pomiar_core.py walka` zapisuje rozkazy gracza z okna (`rozkazy`), test `walka_swiat` je wydaje
przed taktem. Test pomija próbkę z ω z poprzedniej próbki gry, gdy ω Core z poprzedniego taktu jej równe (wyścig
odczytu przy stojącej jednostce), i raportuje ich liczbę. Tolerancji nie zmieniono.
619/620: kolejność listy jak kolejka fizyki po wczytaniu (`--kolejnosc=pozycja`, etap 44/45 [P]); faza licznika
+0x22C bohatera w chwili T0 z pomiaru (LookForHealee co 30 taktów od 1. taktu scenariusza).

## 6. Obywatel

- **0x62FE01 (zagrożenie dla FleeDanger) [W]:** lista uchwytów wskazujących obywatela (+8), kandydat = jednostka bez
  kontenera (+0x1C0 = 0), której bieżący cel to EEUGAttackUnit (albo EEUGGather) z celem = obywatel; wybór: najmniejszy
  kwadrat odległości pól (0x61680D, obrys +0x58C), remis – pierwszy. Hipoteza etapu 45 („ostatni trafiający”) obalona
  kodem; Core – nowy wybór. Rozstrzygający pomiar dwóch atakujących (dalszy trafiający łucznik + bliższy) – [N].
- TakingLightDamage – tylko w Idle (citizen.tai, Gather.tai), w RepairBuilding tylko z OwnerIsComputer [W].
- Pościg przerwany (644): obywatel ucieka (8000 w 63238, cel (168,5; 112,5) – kierunek 5), gwardia ściga i drugim
  trafieniem zabija go w ruchu (6000, tryb 2) – rozkaz odejścia gwardii dotarł dopiero po 24,7 s.
  Core (stan generatora z nagrania): ucieczka zgodna; 1. różnica t = 63817 – pozycja obywatela 0,002 (odpychanie
  z obracającą się gwardią takt wcześniej w Core) [N: aktywność kroku końcowego przy ω ≠ 0 i push = 0,001].
- Trafienie w ruchu (644 „ruch”): obywatel gracza 1 nie wszedł w pole widzenia gwardii (rozkaz MCP trafił w inny punkt) –
  przebieg ruchu zapisany, bez trafienia.
- Niewykonane: trafienie w trakcie ucieczki z przeżyciem, rozkaz w kolejce, blokada budynkiem, wszystkie kierunki
  zablokowane (0x62C7C8 z obiektami – w Core nadal tylko przejezdność terenu [N]).

Statusy: 0x62FE01 zbadany [W] i zaimplementowany; ucieczka potwierdzona w EE (638 4264/4264, 644 do t = 63817).

## 7. Healer.tai – stan implementacji

| Element | EE | Status |
|---|---|---|
| HealSearchTimeElapsed (18000) | 0x61BF25: EEUC+0x4A4 ≠ 0 i licznik +0x22C = 0 | [W], Core, test, 619/644 [P] |
| licznik +0x22C | 0x600822: > 0 → c − f32(PH+0x98)·0,001, poniżej 0 → 0; po 16000 := +0x4A4 | [W], Core, 619 cykl 30 taktów [P] |
| LookForHealee (16000) | 0x61B57A → 0x620A68 (promień LOS, lista zapytania 0x635F39 od końca, 0x630E07, 0x5ECAD0) → EEUGHeal (0x612A8A) przez 0x5F05BD | [W], Core, test, 644 [P] |
| TurnToFaceHealee (16002) | cel vt+0x40 – tryb 1 do celu | [W], Core, 644 [P] |
| HealUnit (16001) | 0x621019: w zasięgu – animacja 3 | [W], Core |
| leczenie | cel EEUGHeal 0x612EF8: w 16001, cel żywy, sojusznik: +0x3C += PH+0xA4 (34 ms); > 1000 → HP = min(HP + ulepszenie+0x150, HPmax), +0x3C −= 1000 | [W], Core, test, 644 [P] |
| zdarzenia 18001–18006 | 0x612E0E: TargetNeedsHealing, HealeeInHealingRange (DistanceToSquared ≤ +0x4A0²), GoalIsHeal, FacingHealee (0x61FC51), HealeeDestroyed, HealeeNoLongerVisible | [W], Core |
| podejście | PrepareToMove z celem EEUGHeal – punkt = pozycja leczonego [H: vt+0x08 celu niezbadane] | Core |
| przerwania | śmierć celu (HealeeDestroyed), poza zasięgiem → PrepareToMove, pełne HP → 2025 | Core, test (śmierć celu) |
| Godot | potyczka: parametry z dbobjects, skrypt z „TAI Script” | zintegrowany (14 leczeń w demonstracji) |

Rozbieżność kodu i pomiaru [N]: 0x630E07 i 18001 porównują HP/HPmax z progiem +0x49C instrukcjami, które czytam
jako „≤” (pełne HP kwalifikuje się), a pomiar pokazuje koniec leczenia w takcie po osiągnięciu pełnego HP i brak celu
przy pełnym HP sojusznika. Core stosuje porównanie ostre (zgodne z pomiarem) i opisuje rozbieżność w kodzie.

## 8. Parametry i wyniki leczenia

| Parametr | Źródło | Wartość (bohater 173) |
|---|---|---|
| +0x4A4 okres szukania | dbobjects „Unknown#51”; pamięć typu [P] | 1,0 s (30 taktów) |
| +0x49C próg HP | „Unknown#50”; pamięć [P] | 1,0 |
| +0x4A0 zasięg leczenia | „Healing range / Ability range”; pamięć [P] | 4,0 |
| ulepszenie +0x150 | „Healer heal amount” | 50 HP / 1000 ms |
| promień szukania | pole widzenia ulepszenia +0xA4 | 6,0 |
| zestaw leczonych (+0x10C, 0x4A7618) | nieodczytany [N] | gwardia 422 leczona [P] |
| pierwszy kandydat | lista zapytania od końca [W]; 644 – przy równym HP wybrana jednostka późniejsza w kolejce fizyki [P] | |
| zasób / koszt | brak w kodzie leczenia [W] | |

Pomiar 644 [P]:
- 1 ranny: 16000 → 16002 → 8000 (podejście z 4,85 pola) → 9000 → 16002 → 16001; leczenie po 29 taktach od wejścia
  w 16001 (183 → 215); takt później 2025 → 5000.
- 2 rannych (199/199): najpierw 0x1000857 (późniejszy w kolejce fizyki), po wyleczeniu natychmiast 16000 i drugi cel.
- Przy pełnym HP: 16000 → 2025 → 5000 co 30 taktów (jak 619).
- Odtworzenie 644 w Core – rozbieżne od startu (gwardie w polu widzenia od początku: w grze bój zaczyna się później
  niż w Core) [N: opóźnienie pierwszego CanISeeEnemy po wczytaniu]; synteza wzoru w teście GDExtension zgodna co takt.
- Niewykonane: cel poza zasięgiem szukania, cel nieosiągalny, kilku uzdrowicieli, rozkaz gracza dla bohatera.

## 9. Analiza RNG

- Jeden generator RTSPhysics ([0x919774]+0x18, LCG 214013/2531011). Import 0xB2FBC8 wywoływany w 68 miejscach EXE
  (AI graczy 0x44–0x4A: 27, mapa/obiekty 0x51–0x52: 14, jednostki 0x5E–0x63: 13, efekty 0x66: 3, inne) [W].
  Osobne strumienie grafiki/dźwięku – nie znaleziono w tej analizie [N].
- Kolejność w takcie (etap 45): 0x546CE9, zatwierdzenie kolejki fizyki, 0x547C09, menedżer tras, pętla jednostek.
- **Klasa dodatkowych losowań [P]:** 638 – 332 z 2676 taktów niezgodnych przy stanie z nagrania, 244 przy wszystkich
  jednostkach testowych w Idle/rozkładzie. Kolejka fizyki czystej mapy ma 22 obiekty: 3 testowe + 19 obiektów Świata
  (kury, kozy, konie, jelenie – 16, ryby – 3). Mapa e46 bez zwierząt (`swiat_usun_typy`): kolejka 3 obiekty.
- Pozostałe losowania na mapie bez zwierząt: 411 taktów z > 2 losowaniami, w tym 12 przy wszystkich jednostkach w Idle,
  w nieregularnych odstępach – [H] AI gracza komputera (gracz 5). Odtworzenie wymaga symulacji AI graczy – poza etapem.

## 10. Odtwarzanie deterministyczne

| Przebieg | Tryb RNG | Wynik |
|---|---|---|
| 646 (bez zwierząt) | stan startowy z nagrania, dalej Core sam | jednostki 4643/4643 zgodne; RNG zgodny co takt 190 taktów (do pierwszego losowania spoza Core) |
| 638 obywatel | stan co takt z nagrania | 4264/4264 (zgodność wymaga stanu z gry – nie jest odtworzeniem autonomicznym) |
| 644 pościg | stan co takt z nagrania | do t = 63817 |
| 631/633/634/638k, sojusz ×2 | własny | zgodne do końca nagrań |

Narzędzia rozróżniają tryby: `odtworz_scenariusz.gd` zapisuje `tryb_rng` (`wlasny`, `stan_startowy_z_nagrania`,
`z_nagrania_co_takt`) i liczbę losowań Core w takcie (`rng_n`); `odtworzenie_nagrania.py porownaj` drukuje jedno
podsumowanie z trybem i ostrzeżeniem, że zgodność ze stanem co takt nie jest odtworzeniem autonomicznym.

## 11. Dynamiczna przebudowa grafu

[W] 0x4288A7 → 0x422DB6 (pola obiektu, posortowane) → 0x4A36F3(1, natychmiast): przy +0xD8 = 1 termin bez zmian, inaczej
+0xD4 = teraz + 1 ms (albo + opóźnienie *0x9183C0·10000); 0x4A3641 → 0x4278C3 po terminie, przy pustej kolejce grafu.

[P] 645 (trzy gwardie niszczą dom 0x5000ad0): dom wchodzi w Dying w t = 62010, odczyt EEPathManager: +0xD4 = 62011,
+0xD8 = 0 w najbliższym odczycie (≤ 2 s – przebudowa wykonana). Zgłoszenie następuje przy śmierci obiektu (6000), nie
przy usunięciu (6003). Odczyt list obiektów pól i podsektorów przed/po – niewykonany (rejestrator bez tych pól) [N].

Core: `ustaw_wejscie_mapy` (wejście floodu zachowane przy budowie grafu z SCN), `usun_obiekt_mapy`, `zglos_zmiane_mapy`,
`krok_przebudowy` w takcie menedżera (po drugim losowaniu, przed pętlą jednostek). Przebudowa raz po terminie, nie co
takt; zakres – cały graf z zachowanego wejścia [N: przyrostowy 0x4278C3]. Trasy jednostek nie są unieważniane [N].
Statusy: zbadany [W], zaimplementowany, test syntetyczny (e35_a: 1 zgłoszenie → 1 przebudowa, wersja 1 → 2 i bez
kolejnych przez 10 taktów), termin potwierdzony w EE; trasa przed/po – niezmierzona; Godot – brak (budynki nie są
jednostkami Core – nie da się ich zniszczyć w potyczce).

## 12. Demonstracja zniszczenia przeszkody

W grze – wykonana (645, termin przebudowy jak wyżej). W potyczce Godot – niewykonana: budynki są obiektami mapy
(dodaj_obiekty_scn), nie jednostkami z HP w Core. Potrzebne: budynki jako cele ataku w Core (etap 47).

## 13. Skrypty `.tai` w potyczce

- Potyczka czyta „TAI Script” z dbobjects i woła `ustaw_skrypt_jednostki`: Land Patrolling → skrypt świata (Generic
  Attack/Movement/Patrol/Death [W]), Citizen → citizen.tai, Military Healer Prophet → Healer.tai + land. Nieznane nazwy
  trafiają do raportu (`skrypty_nieznane`) i zostają na skrypcie świata (Prophet – [N]).
- Parametry leczenia z dbobjects (`ObiektyScnCore.parametry_leczenia`).
- Kompozycja: parser `.tai` w Core obsługuje dołączanie, allof/anyof i usuwanie przejść (testy CTest na plikach gry);
  skrypty wbudowane składają teksty w kolejności dołączeń zamiast kopiować maszyny stanów. Ładowanie plików `.tai`
  z instalacji w potyczce – nie w tym etapie (decyzja: wbudowane teksty pokrywają używane typy, parser pozostaje do
  weryfikacji na plikach).
- `potyczka_e46.json`: 5 gwardii vs 3 gwardie + bohater + obywatel. Demonstracja: ataki z rozkazu gracza, 14 leczeń,
  7 śmierci, martwe po 6003 usunięte z kolejki fizyki. Ucieczka obywatela nie wystąpiła (obywatel zaatakował
  napastnika – Idle CanISeeEnemy).

## 14. Macierz typów jednostek

| Typ | Ruch | Obrót | Kolizja | Wybór celu | Reakcja na obrażenia | Śmierć / kolejka | Parametry | Skrypt |
|---|---|---|---|---|---|---|---|---|
| gwardia 422 | [P] 631–634 | [P] | [P] 638k | [P] 578/590 | brak 2018 (Idle → CanISeeEnemy) | [P] 72/1/1177, usunięcie po 6003 [P] | pamięć | Land Patrolling = świat |
| obywatel 32 | [P] 638 | [P] | [N] 644 t = 63817 | – | FleeDanger [P], bez 2018 | [P] 47/1/1177, tryb 2 | dbobjects | Citizen |
| bohater 173 | [P] 644 podejście | [P] 16002 | – | nie atakuje (AI 0) | 2018 → 5001 [P] | – | dbobjects + pamięć | Military Healer Prophet |
| prorok 216 (obserwator) | stoi | – | – | – | – | – | vmax 0,45 | Prophet [N] |
| dom (budynek) | – | – | – | – | – | Dying 62010, zgłoszenie mapy [P] | dbobjects HP | – |
| zwierzęta Świata | [N] | – | – | – | – | – | – | Land Animal [N] – źródło losowań [P] |

Dodatkowa jednostka bojowa innego rodzaju – brak (w czystych scenariuszach brak wzoru i parametrów) [N].

## 15. Zmiany w Core, GDExtension, Godot i MCP

Core:
- `zagrozenie_62fe01` (FleeDanger); TakeDamage: `atakujacy_1dc`, Idle → UnderAttack przy `reakcja_underattack`;
  stan UnderAttack i zdarzenie CanFlee w skrypcie świata.
- Healer.tai: stany 16000–16002, zdarzenia 18000–18006, cel `TypCelu::leczenie`, licznik +0x22C, leczenie
  w `liczniki_walki`, `wbudowany_uzdrowiciel`, parametry `leczenie_*`, `ustaw_faze_leczenia`.
- Dynamiczny graf: wejście mapy w świecie, zgłoszenie, termin, przebudowa w takcie.
- Dziennik zdarzeń: „leczenie”, „ucieczka”.

GDExtension: `usun_obiekt_mapy`, `ustaw_faze_leczenia`, `migawka_diagnostyczna`; diagnostyka: `rng_losowan`,
`wersja_grafu`, `przebudowy_grafu`, `przebudowa_zaplanowana`, `termin_przebudowy`; parametry walki `leczenie_*`,
`leczone_typy`, `reakcja_underattack`. 6 nowych testów.

Godot: potyczka (skrypty z danych, parametry leczenia, raport zdarzeń i kolejki fizyki), `potyczka_e46.json`,
`ObiektyScnCore.parametry_leczenia`, `odtworz_e35.gd` (leczenie, faza licznika, kolejność listy),
`odtworz_scenariusz.gd` (`--rng-tylko-start`, `rng_n`, `tryb_rng`).

Narzędzia: `pomiar_core.py walka` (rozkazy gracza), `odtworzenie_nagrania.py` (podsumowanie pierwszej rozbieżności),
`scenariusz_czysty.py` (`swiat_usun_typy`), `scenariusze_czyste.py` (baza bez zwierząt), warianty e46.
CTest: rozkazy z pomiaru, wykrywanie próbek ze spóźnionym ω.

Riverlands_MCP (lokalnie): `ee_laboratorium.py`, krok zadania `laboratorium`, test (17 modułów, 104 testy).

## 16. Regresja

Testy syntetyczne:

| Zestaw | Wynik |
|---|---|
| CTest Release / Debug | 20/20 / 20/20 |
| GDExtension | **60/60** (+6: leczenie, dwóch rannych, UnderAttack, migawka i powtarzalność, śmierć leczonego, dynamiczny graf) |
| Godot | 325/325 |
| Riverlands_MCP | 17/17 modułów (104 testy; +1 moduł laboratorium) |
| Narzędzia Titan | 20/20 |
| S1–S7 | `68b0c69ecb8b0cbc` |
| skrót mapy | `c8297c16f0d48b1a` |
| skrót scenariuszy | `22b0f0cf4a1ec660` |

Porównania z grą:

| Przebieg | Wynik |
|---|---|
| EE 578 G1 | 986/986 |
| 619 / 620 | wszystkie jednostki zgodne (bohater włącznie) |
| 631 / 633 / 634 / 638k | zgodne do końca |
| 638c obywatel | 4264/4264 (RNG z nagrania) |
| e45 590 G1 / 578 G3 | bez rozbieżności w oknie |
| e31 590 G1 / 578 G3 | 1. różnica 98 / 190 (kurs) |
| 644 sojusz blisko / daleko | 4426/4426 / 4412/4412 |
| 644 pościg | do t = 63817 |
| 644 bohater (1 i 2 rannych) | wzór cyklu odtworzony syntetycznie; odtworzenie startu [N] |
| 645 dom | termin przebudowy = t śmierci + 1 ms (mechanizm w Core) |
| 646 bez zwierząt | 4643/4643, RNG autonomiczny 190 taktów |
| potyczka troja / e46 | działa / działa (leczenie, śmierci, kolejka fizyki) |

Wzorce zmienione z uzasadnieniem: brak. Nowe dane testowe: `walka_578_g3_e45.json` i `walka_590_g1_e45.json`
przeliczone z polem `rozkazy` (lokalnie, poza repozytorium).

## 17. Pierwsze pozostałe rozbieżne takty

| Przebieg | Pierwsza różnica |
|---|---|
| 644 pościg | t = 63817, pozycja obywatela 0,002 – odpychanie takt wcześniej w Core (gwardia ω ≠ 0, push 0,001) |
| 644 bohater | od startu – moment pierwszego zauważenia wroga po wczytaniu |
| 646 RNG | t = 10260 – losowanie spoza jednostek (AI gracza komputera [H]) |
| e31 590 G1 / 578 G3 | 98 / 190 (kurs) |

## 18. Otwarte problemy

1. Porównanie progu leczenia (kod „≤”, pomiar „<”) [N].
2. Zakres przyrostowej przebudowy 0x4278C3 i wpływ na trasy; budynki jako jednostki Core [N].
3. Losowania AI gracza komputera [H]; zwierzęta Świata (Land Animal.tai) poza Core.
4. Aktywność kroku końcowego przy ω ≠ 0 i push = 0,001 (644 pościg) [N].
5. Opóźnione rozkazy MCP (prawy klik) – przyczyna w ścieżce wejścia [N].
6. 0x62C7C8 z obiektami pól i dwóch atakujących dla 0x62FE01 – bez pomiaru.
7. Zestaw leczonych typów (+0x10C) i kolejność zapytania 0x635F39 [N].
8. Skrypt Prophet i rejestracja stanu 2018 w EEUC innych klas [N].
9. Opóźnienie pierwszego CanISeeEnemy po wczytaniu scenariusza (644 bohater) [N].

## 19. Propozycja etapu 47

1. Budynki jako jednostki Core (HP, śmierć 6000, zgłoszenie mapy przy śmierci) i pomiar trasy przed/po zniszczeniu
   domu w przejściu; przyrostowa przebudowa 0x4278C3.
2. Krok końcowy przy ω ≠ 0 (pomiar kontaktu obracającej się gwardii z uciekającym obywatelem).
3. Rejestrator: listy obiektów pól, podsektory zmienionych pól, kolejka zgłoszeń menedżera.
4. AI gracza komputera jako źródło losowań: pomiar z graczem 5 bez AI (scenariusz z dwoma graczami-ludźmi) albo
   analiza aktualizacji EEComputerPlayer.
5. Próg leczenia: śledzenie 0x612E9C w debugerze; warianty leczenia niewykonane w 644.
6. Przyczyna opóźnionych rozkazów MCP.
