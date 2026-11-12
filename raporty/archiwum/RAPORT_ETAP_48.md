# Raport etapu 48 – Prophet.tai, fizyka kontaktu, budynki 2×2 i gruz

Najważniejsze wyniki etapu:
- **644 pościg zgodny w całości** (4148/4148 próbek, wcześniej do t = 63817). Przyczyna z kodu 0x549179: gdy atakujący
  pcha swój cel ataku, push celu jest mnożony przez 0,25 (stała 0x825450). Budzik ustawia (0,001; 0,001) tylko przy
  |push| < 0,001.
- **Prorok w 648**: parametry ruchu z ulepszenia gracza (odczyt pamięci: ×10/9), skrypt Prophet.tai w Core i przekazanie
  trasy po porażce Bounded (0x4A2B29 → poprawa początku maszyną Bounded z limitem 50). Trasa A* identyczna z grą, stany,
  pozycja i kurs zgodne od rozkazu do t = 63510. Pierwsza brakująca operacja: odepchnięcie od muru (kontakt z budynkiem).
- **Atak na budynek**: gra podchodzi do miejsca 0,25 za krawędzią obrysu, nie do środka. Po odtworzeniu reguły atak
  1v1 na dom zgodny co próbkę od rozkazu do śmierci domu.
- **Koszary 2×2**: graf przed i po zniszczeniu identyczny z grą (id, pola, punkty, sąsiedzi, wolne id). Gruz 2×2 na
  4 polach; trasa proroka przez zwolniony teren zgodna do końcowego obrotu.
- **Gruz** = dbobjects „Debris on death#2” (361 dla 1×1, 362 dla 2×2) jako obiekt mapy od taktu śmierci, bez przebudowy.
- **Testy Riverlands_MCP** przechodzą w jednym procesie (108 testów, kolejność losowa, dwukrotnie).

Oznaczenia: [P] – kod i pomiar, [W] – analiza statyczna, [H] – hipoteza, [N] – nieustalone.
Osobno podawane: mechanizm Titan / implementacja Core / test syntetyczny / pomiar EE / zgodność co takt / Godot.

## 1. HEAD początkowy i końcowy

- Początek: `337edd0` (etap 47, lokalnie). Bez push, pull, fetch, clone, reset, rebase i clean; bez porównań z GitHubem.
- Koniec: jeden lokalny commit etapu 48 (hash w podsumowaniu sesji / `git log -1`).
- Poza commitem: `godot/project.godot`, `konfiguracja/uzytkownik.cfg.przed_etapem11`, pliki `.uid` starszych skryptów,
  Riverlands_MCP (osobne repozytorium, zmiany lokalne).

## 2. Analiza Prophet.tai

[W: pliki .tai; P: 648, e48_prorok] – szczegóły w `docs/titan/skrypty_stanow.md` § 10.
- dbobjects 216: „TAI Script” = Prophet, „Unit type” 13 (EEUC z 0x6055E5).
- Skład: część proroka (klątwy), Generic Movement, nadpisania, Generic Death, końcowe `ReacquireGoal { AlwaysTrue true(Idle) }`.
  **Bez Generic Attack** – Idle tylko z AmIUnderAttack.
- Nadpisanie `GetNextMoveWaypoint { NextWaypointRetrieved true(Advance) … }` zastępuje przejście w miejscu (0x618ED9):
  prorok idzie 9000 → 10003, gwardia 9000 → 2015 → 10003 [P: 648].
- Rozkaz ruchu: PrepareToMove (8000) → LookForEnemies (2015) → Advance; punkty zdejmowane w GetNextMoveWaypoint jak dla
  gwardii; obsługa zakleszczenia (RepathAroundObstacle) i nieosiągalnego celu z Generic Movement – bez zmian.
- Inne parametry niż gwardia: ruch z ulepszenia gracza (§ 3).
- Core: `SkryptStanow::wbudowany_prorok()` (własny zapis w kolejności dołączeń), przypisanie z danych typu.
  Zdarzenia klątw – fałsz (brak celu klątwy w Core).
- Wynik bez zmiany mapy (e48_prorok, zad. 650): 2704/2704 próbek – stan, pozycja, kurs, czas końca ruchu.

## 3. Wynik nagrania 648

| Element | Wynik |
|---|---|
| cel | zgodny (EEUGLocation z nagrania, +0x1D = 1, brak punktów grafu) |
| parametry ruchu | ulepszenie gracza (+0x34) [P: zad. 650]: a 2,22222, vmax 0,5, α 13,57478, ωmax 15,51404, c8 0,07367, c4 0,45 – ×10/9 względem dbobjects (źródło mnożnika [N]) |
| trasa | identyczna z grą (8 punktów) po poprawce 0x4A2B29 (`astar_wyniki.md` § 11) – wcześniej objazd kosztu 134 zamiast 112 |
| stany | zgodne od rozkazu (48068) do 65453 |
| pozycja i kurs | zgodne od rozkazu do 63510 (1688 próbek; wcześniej różnica od 48170) |
| czas zakończenia ruchu | niezgodny – po 63510 |

Rozdzielenie źródeł: (1) interpretacja rozkazu – poprawna; (2) wybór trasy – był błędny (Bounded + reszta zamiast
poprawy początku), poprawiony; (3) fizyka – parametry ruchu z dbobjects zamiast z ulepszenia, poprawione.
Pierwsza brakująca operacja Titan: odepchnięcie proroka od muru gracza 1 przy (160, 111) – licznik +0x248 rośnie od
63510. Mur jest w Core obiektem mapy, a budynki nie są kontaktami (etap 47) [N: flaga +0x2D8 budynków].

## 4. Fizyka kontaktu (644)

[W: kod 0x5498C4, 0x549179; P: 644 – dopasowanie i odtworzenie]
- 0x5498C4: wariant małej kolizji (vt+0x3C = 0x549179), gdy rozmiar (+0x244 = „Size of collider”) którejś strony < 1,0.
- 0x549179: gdy cel bieżący u (+0x1F0) to EEUGAttackUnit z celem o, push dodawany o jest ×0,25 (0x825450).
- Budzik: push o := (0,001; 0,001) tylko, gdy obie składowe |·| < 0,001.
- Odczyt push gwardii (0,001; 0,001) w nagraniu = budzik od obywatela (gałąź ru < ro).
- Kolejność w takcie (od końca kolejki: gwardia, potem obywatel) i moment wykrycia kontaktu były już poprawne;
  błędny był współczynnik pchania celu ataku (5/3 zamiast 0,25·5/3).
- Dopasowanie do nagrania (wszystkie takty kontaktu): własny współczynnik obywatela 1,185 (kod 1,2), gwardii 0,43 (kod 0,417).
- Core: `krok_koncowy`. Wynik: 644 pościg 4148/4148, wszystkie jednostki.
- Eksperymenty B4: kontakt trzech gwardii (e48_kontakt3) – trzy kontakty, bez odepchnięcia, Core zgodny 2571/2571;
  pozostałe przypadki B4 pokryte nagraniami 631–634, 638k, 644 (przy niezmienionych wynikach).

## 5. Budynki wielopolowe

[P: zad. 650 `e48_koszary`] Koszary 34 („Square occupied” 2, kotwica X, Y = lewy dolny róg, środek X + 1):
- obiekt na listach 4 pól; przed zniszczeniem pola tworzą osobny podsektor (428);
- po śmierci wszystkie 4 pola zwalniane w tym samym takcie, przebudowa jednego sektora, wolne id [428];
- Core – graf przed i po identyczny z grą (3/3 i 2/2 podsektory: id, pola, punkty, sąsiedzi);
- atak trzech gwardii (Core z miejscem podejścia przy budynku): trafienia, HP i takt śmierci zgodne; pierwsze różnice
  pozycji gwardii 0,02 przy dojściu (73295) [N];
- C5 (wczytanie → atak → zniszczenie → 4 pola → graf → nowa trasa): spełnione; trasa proroka po zniszczeniu zgodna
  z grą do końcowego obrotu (3088 próbek).
- Obrót budynku a zajmowane pola – niebadany (wzory scenariusza bez obrotu) [N].

## 6. Mechanizm gruzu

[P: 647, 648, 650 – dom, mur, wieża, koszary]
- Typ: dbobjects „Debris on death#2” typu budynku – 361 „Amb - Debris 1x” (dom, mur, wieża), 362 „Amb - Debris 2x”
  (koszary); „Unit type” 0, HP 1, „Collidable” 0, skrypt Simple Building.
- Powstaje w takcie śmierci (6000) – w 647 w tym samym takcie co zgłoszenie mapy; na początku listy każdego pola budynku.
- Właściciel: Świat (id 0x24ac – kolejny id gracza 0). Brak stanu `.tai` w odczycie, nie blokuje ruchu.
- Trwa po 6003 (odczyt 150 s po śmierci). Brak kolejnej przebudowy (+0xD4/+0xD8 bez zmian).
- Core: `Gruz`, wpis na listy pól wejścia grafu bez blokady i bez zgłoszenia; GDExtension `gruz()`; parametr budynku
  `gruz_typ` z dbobjects (Godot: `ObiektyScnCore.parametry_budynku`). Test CTest (2×2) i GDExtension (1×1).
  Godot nie rysuje gruzu (model gruzu – osobny etap; brak zastępczego obiektu Godota).

## 7. Aktualizacja grafu po dodaniu przeszkody

- [W: 0x55C315] dodanie jednostki gracza: obiekt z +0x600 ≠ 0 albo +0x4B4 = 0x19 → 0x4288A7(obiekt, 0) – zgłoszenie przy
  utworzeniu obiektu budynku, z terminem zwykłym (+0xD4 = teraz + fistp(*0x9183C0·10000) [N wartości]). Fundament to ten
  sam obiekt, więc blokada powstaje przy postawieniu, nie po ukończeniu budowy [W].
- Core: `Swiat::postaw_budynek` – rejestracja na polach, blokada od razu, zgłoszenie zwykłe; test CTest: przebudowa
  sektora, pole budynku jako osobny podsektor (jak dom w 647 przed zniszczeniem), stara trasa bez zmian.
- Pomiar w grze: zablokowany – postawienie budynku wymaga obywatela, zasobów i interfejsu budowy, których sterowanie MCP
  nie obsługuje. E3 (kilka zmian, zmiana w trakcie szukania trasy) – tylko synteza (etap 47: dwa sektory w jednym takcie).

## 8. Pełna trasa po zmianie mapy

| Przebieg | Wynik |
|---|---|
| 648 – prorok, stara trasa po przebudowie | zgodna (trasa nie jest przeliczana) |
| 648 – nowy rozkaz | trasa identyczna, ruch zgodny do 63510 (mur) |
| 650 koszary – rozkaz proroka po zniszczeniu | trasa i pozycje zgodne do końcowego obrotu |
| e48_prorok – bez zmiany mapy | pełna zgodność |

## 9. Faza ataku na budynki

- Przyczyna braku zgodności w 647/648: punkt celu przy PrepareToMove. Gra stawia go 0,25 za krawędzią obrysu, a Core
  używał środka budynku i przez to wstawiał punkt grafu.
- Reguła w Core [P: 5 miejsc z gry; H dla innych boków i rozmiarów]: po dwa miejsca na pole przylegające bokiem
  (pole + 0,75, potem + 0,25). Pola są uporządkowane wg kwadratu odległości od pola atakującego, bez narożników;
  wybierane jest pierwsze wolne miejsce. Szczegóły: `walka.md` § 36.
- Wyniki co próbkę:

| Nagranie | Przed | Po |
|---|---|---|
| 651 dom 1v1 (od rozkazu) | 1116 próbek | do śmierci domu (1846 próbek); dalej tylko drganie zapadania (RNG) |
| 650 dom 3v1 | 1106 | gwardia 1: 1254, gwardia 2: 2034; HP i takt śmierci domu zgodne |
| 650 koszary 3v1 | 1107 | ok. 2010 próbek obu gwardii; HP i takt śmierci zgodne |

- Zapadanie (x/y z dwoma losowaniami) odtworzone wzorem (etap 47). W odtworzeniach z własnym RNG przebieg się rozjeżdża,
  bo gra losuje też poza Core (§ 11).

## 10. Pierwsze CanISeeEnemy

- e48_widzi [P]: wróg w odległości 3 od wczytania – cele obu gwardii utworzone w 34 ms (pierwszy takt), Core – takt 1.
- e48_widzi_ruch [P]: wróg 4,09 po ruchu – brak wykrycia w grze i w Core (zgodne 2572/2572).
- 644 bohater: rozbieżność „od startu” wynika z metody, nie z mechaniki. Opis przyjmował pozycje jednostek z pierwszej
  próbki nagrania (po 4,8 s walki), a odtworzenie liczyło od czasu 0 [P: pozycje opisu ≠ pozycje scenariusza]. Arbitralnego
  opóźnienia nie dodano.

## 11. AI gracza komputerowego

- Trzecie losowanie w takcie występuje w tych samych czasach gry w 646 i 647 (10261, 12068, 19227, 19568, 26386, 38454)
  mimo różnej zawartości scenariuszy [P]. Na początku obu nagrań wszystkie jednostki stoją (2 losowania na takt), więc
  stan generatora jest wspólny. Harmonogram może więc zależeć od czasu albo od RNG – nie da się tego rozdzielić bez
  wyłączenia AI.
- Wywołania generatora w zakresie AI graczy (0x44xxxx–0x4Axxxx): 27 miejsc (lista z 0xB2FBC8) [W]; funkcja planująca nie
  została rozpoznana [N].
- Eksperyment „bez AI komputera”: niewykonany – narzędzia scenariusza nie przełączają typu gracza [N].
- Core: brak pozornych losowań; diagnostyka `rng_n` / `tryb_rng` bez zmian.

## 12. Stan autonomicznego RNG

Bez zmian: 646 – 4643/4643 przy stanie startowym z nagrania (190 taktów RNG autonomicznie); 638c i 644 pościg – zgodność
wymaga stanu generatora co takt (wyraźnie oznaczone w porównaniu).

## 13. Testy Riverlands_MCP

- Reprodukcja: osobno 18/18 modułów; razem 3 niepowodzenia i 23 błędy.
- Pierwsza różnica: test_ee_etap30 + test_ee_kamera – OSError „brak 0x930dfc”. Moduł kamery był związany z atrapą pamięci
  innego pliku.
- Przyczyny: (1) unittest importuje wszystkie pliki przed pierwszym testem, a moduły z `sys.modules` i atrybuty pakietu
  `riverlands_mcp` wiązały atrapy pierwszego pliku; (2) importy leniwe w czasie testu trafiały do atrap ostatniego pliku;
  (3) `time.sleep` był podmieniany w bibliotece standardowej (wyłączał opóźnienia w innych testach).
- Poprawka (`testy/_izolacja.py`): przy imporcie pliku czyszczenie podmodułów `riverlands_mcp.*` i atrybutów pakietu;
  `setUpModule`/`tearDownModule` przywracają zestaw modułów danego pliku; atrapa `time` per moduł. Treść testów bez zmian.
- Wynik: 108 testów w jednym procesie – OK; kolejność losowa (3×) – OK; zestaw podwójnie – OK; `discover` – OK.
- Nowa diagnostyka: `obs_rozkaz.czasy_gry` [P: 650 – start kroku 7397, PPM 33375–38045, cel 38352].

## 14. Zmiany Core, GDExtension i Godot

- Core:
  - `wbudowany_prorok`, zdarzenia klątw;
  - 0x4A2B29 – poprawa początku trasy (Bounded 50, ±26);
  - `krok_koncowy` – push celu ataku ×0,25, budzik warunkowy;
  - `punkt_podejscia` dla budynku;
  - `Gruz` / `gruz()` / `ustaw_gruz_budynku`;
  - `postaw_budynek`;
  - `wejscie_mapy()`, diagnostyka `ostatnia_poprawa_poczatku`.
- GDExtension 0.21.0: `jednostka()["trasa"]`, `gruz()`, `postaw_budynek(dict)`, klucze `gruz_typ`/`gruz_kwadrat`
  w `dodaj_budynek`, diagnostyka `astar_wywolania`, `bounded_sukces`, `poprawa_poczatku`; skrypt „Prophet”.
- Godot:
  - `ObiektyScnCore.parametry_budynku(ob, db)` – gruz z dbobjects;
  - potyczka – gruz w raporcie;
  - `odtworz_scenariusz.gd` – `--ulepszenia`, `ruch` w opisie, zapis tras, `--diag-trasy`;
  - nowy `okno_pol.gd`.
- Dane i narzędzia: `parametry_jednostek_ee.json` → `ruch_ulepszenia`; warianty e48 (`e42_warianty.json`, wzory koszar
  i wieży).

## 15. Pełna regresja

Testy syntetyczne:

| Zestaw | Etap 47 | Etap 48 |
|---|---|---|
| CTest Release / Debug | 21/21 / 21/21 | 21/21 / 21/21 (`budynki`: 24 sprawdzenia, +gruz, +postawiony budynek) |
| GDExtension | 63/63 | **65/65** |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 18 modułów osobno (108) | **108 testów w jednym procesie** |
| Narzędzia Titan | OK | OK |
| S1–S7 / mapa / scenariusze | `68b0c69ecb8b0cbc` / `c8297c16f0d48b1a` / `22b0f0cf4a1ec660` | bez zmian (CTest) |

Porównania z grą:

| Przebieg | Etap 47 | Etap 48 |
|---|---|---|
| EE 578 G1 | 986/986 | 986/986 |
| e45 578 G3 / 590 G1 | bez rozbieżności | bez rozbieżności |
| 619 / 620 | jak etap 46 | bez zmian |
| 631 / 633 / 634 / 638k / 638c | zgodne | zgodne |
| 644 sojusz ×2 | zgodne | zgodne |
| **644 pościg** | do 63817 | **4148/4148** |
| 646 | 4643/4643 | 4643/4643 |
| **648 prorok** | do 48170 | **do 63510** |
| e48_prorok / kontakt3 / widzi / widzi_ruch | – | pełna zgodność |
| **651 dom 1v1** | – | do śmierci domu |
| 650 dom 3v1 / koszary | – | HP i takt śmierci zgodne |
| potyczka_e47 | wygrana w takcie 1593 | wygrana w takcie 986 (gwardie podchodzą do krawędzi); gruz, restart – 2 przebiegi |

Wzorców nie zmieniano. W testach syntetycznych zmieniły się wartości diagnostyczne bez asercji (`budynki`: śmierć
w takcie 353 zamiast 355 – miejsce podejścia).

## 16. Pierwsze pozostałe rozbieżności

| Przebieg | Pierwsza różnica |
|---|---|
| 648 prorok | t = 63510 – odepchnięcie od muru (kontakt z budynkiem) |
| 650 dom 3v1 | t = 47386 – pozycja gwardii 1 przy dojściu (0,02) |
| 650 koszary | t = 73295 – pozycja gwardii 2 przy dojściu |
| 651 / 650 – zapadanie budynku | drganie x/y – losowania RNG spoza Core |
| 619 / 620 0x1000858 | 124254 / 109423 (EEUGLocation przed celem ataku) |
| 646 RNG | t = 10260 – losowanie spoza jednostek |

## 17. Wydajność grafu

`wydajnosc_grafu.gd` (10 zmian, Core Release):

| Mapa | Budowa | Przyrostowa / zmianę | Pełna / zmianę | Zapytanie grafu przed / po | Etap 47 (przyr. / pełna) |
|---|---|---|---|---|---|
| e35_a | 26 ms | 6,2 ms | 15,6 ms | 0,11 / 0,13 ms | 5,7 / 13,0 ms |
| e13_para | 14 ms | 3,2 ms | 7,8 ms | 0,05 / 0,06 ms | 3,6 / 8,1 ms |
| koszary 2×2 (e48, 1 zmiana) | 22 ms | 5,2 ms | – | – | – |

Różnice ±10% między etapami mieszczą się w rozrzucie pomiaru na współdzielonym komputerze (gra działała równolegle).
Podział pól identyczny w obu trybach.

## 18. Problemy nierozwiązane

1. Kontakty z budynkami (flaga +0x2D8, mur w 648) [N].
2. Miejsca podejścia na pozostałych bokach budynku i przy innych rozmiarach – reguła [H].
3. Źródło mnożnika ×10/9 parametrów proroka (premia cywilizacji/ulepszenie) [N].
4. Pomiar stawiania budynku w grze (E) – zablokowany przez brak sterowania budową.
5. Harmonogram losowań AI gracza komputera i eksperyment bez AI [N].
6. Gałęzie 0x4A2214 i n < 5 w 0x4A2B29 [N].
7. 619/620 – późny cel EEUGLocation 0x1000858.
8. Godot – model gruzu.

## 19. Propozycja etapu 49

1. Kontakty z budynkami: odczyt +0x2D8 dla muru, domu i koszar; rejestrator kontaktów z listą obiektów; potem 648 do końca.
2. Miejsca podejścia przy budynku z innych stron i dla 3×3/4×4 (pomiar MCP, warianty z atakującymi z czterech stron).
3. Źródło mnożnika ulepszenia proroka (odczyt gracza/cywilizacji w scenariuszu) i parametry ulepszeń w potyczce.
4. Stawianie budynku przez obywatela (rozszerzenie MCP o rozkaz budowy) – dodanie przeszkody w grze.
5. Losowania AI komputera: scenariusz z graczem 5 jako człowiekiem.
