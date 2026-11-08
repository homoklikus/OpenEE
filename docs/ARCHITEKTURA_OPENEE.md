# OpenEE – architektura i stan wiedzy (dokument orientacyjny)

Stan: etap 13.5 (porządki po etapach 1–13). Ten dokument jest punktem wejścia dla kolejnych etapów. Opisuje, co
jest w projekcie, jak płyną dane i co o oryginalnym silniku już wiadomo. Szczegóły zawierają dokumenty, do których
prowadzą odsyłacze. Raporty etapów pozostają historią badań; tam, gdzie późniejszy etap obalił wniosek, raport ma
odpowiednią adnotację.

**Oznaczenia pewności** (jak w całej dokumentacji):
- **[P]** potwierdzone pomiarem albo testem;
- **[W]** wniosek z ograniczonego pomiaru;
- **[H]** hipoteza lub przybliżenie;
- **[N]** nieustalone.

## 1. Cel i zasady

- OpenEE to niezależna reimplementacja silnika Empire Earth (Titan) w Godot 4.7, na licencji GPLv3.
- Zasoby gry są czytane wyłącznie z legalnej instalacji użytkownika, tylko do odczytu.
- Repozytorium nie zawiera zasobów gry (`docs/ZASOBY_ORYGINALNE.md`).
- Dwie gry na jednym silniku: **Empire Earth** (`ee`, scenariusze w wersji 231) i **The Art of Conquest** (`aoc`,
  wersje 231/248–250). Różnice gier opisują dane, a nie rozgałęzienia kodu (`docs/WARIANTY_GRY.md`). Docelowo
  OpenEE ma być jedną grą z połączoną zawartością; na razie obie gry są wybierane i testowane osobno.
- Mechaniki odtwarza się według kolejności: oryginał → pomiar → dokumentacja → implementacja → porównanie → testy.
  Bez dowodu z oryginału mechanika nie jest wprowadzana.
- Raporty: w katalogu głównym tylko najnowszy `RAPORT_*.md`; poprzednie trafiają do `raporty/archiwum/`
  (`raporty/README.md`, `CLAUDE.md`).

## 2. Moduły (`godot/`)

| Katalog | Odpowiedzialność | Główne klasy |
|---|---|---|
| `silnik/rdzen/` | konfiguracja (gra, instalacje, języki, warstwy), dziennik, zdarzenia, definicje gier | autoload `Konfiguracja`, `Dziennik`, `Zdarzenia`; `GryEE` |
| `silnik/zasoby/` | wirtualny system plików: warstwy, kolejność źródeł, archiwa SSA, pamięć podręczna kluczowana grą | autoload `Zasoby` |
| `silnik/importery/` | formaty EE/AoC | `ArchiwumSSA`, `DCL`, `ImporterTekstur` (SST/TGA), `ModelCEM` + `ImporterModeli` (CEM 1.3/2.0), `BazaDB` (db*.dat, warianty EE/AoC), `EpokiDB`, `ScenariuszEE` (SCN), `TekstyDLL` (Language.dll), `TekstEE`, `ImporterDzwiekow` |
| `silnik/render/` | teren według reguł EE (mieszanie narożników, woda, klify), przezroczystość budynków | `TerenEE`, `PrzezroczystoscBudynkow` |
| `silnik/animacja/` | animacje CEM: sekwencje z `dbgraphics`, klatki w teksturze (VAT), odtwarzacz | `SekwencjeAnimacji`, `AnimacjaVAT`, `OdtwarzaczAnimacji` |
| `silnik/kamera/` | model kamery EE (orientacja, poziomy zoomu, krawędź, ograniczenie do mapy) | `ModelKameryEE` |
| `silnik/symulacja/` | deterministyczna symulacja ruchu ze stałym krokiem i jej warstwa sterowania i prezentacji – szczegóły niżej | `Symulacja`, `JednostkaSym`, `MapaNawigacji`, `Sciezki`, `PolitykaRuchu`, `FormacjaEE`, `ZegarSymulacji`, `UkladEE`; `ZaznaczenieEE` (reguły zaznaczania), `Zaznaczanie` (promień myszy → jednostka/teren), `SterowanieRTS` (wejście → rozkazy), `WidokJednostek`, `WariantyGrafiki` (grafika zależna od epoki) |
| `silnik/diagnostyka/` | analiza geometrii modeli (pary współpłaszczyznowe, duplikaty) | `DiagnostykaModelu` |
| `silnik/api/` | opis przyszłego API modów (bez interpretera) | `ApiModow` |
| `sceny/` | sceny uruchamiane z launchera, wiersza poleceń i MCP | `test_scenariusz`, `rts_test`, `test_teren`, `diag_modelu`, `diag_animacji`, `diagnostyka`; kamery `kamera_rts.gd` (produkcyjna, wierna EE) i `kamera_diagnostyczna.gd` (wolna) |
| `launcher/` | launcher PL/EN: instalacje, profil, gra, język, nakładki, sceny | `launcher.gd`, `StanLaunchera`, `MotywLaunchera`, `TekstyUI` |
| `testy/` | testy bez okna (`uruchom_testy.gd`) | `TestyEtapu4…13`, `TestyKamery`, `TestyRuchuEE`, `TestyGierEeAoc`… |
| `narzedzia/` | narzędzia GDScript z wiersza poleceń | `obiekty_scenariusza.gd`, `porownanie_ruchu_ee.gd`, `statystyka_geometrii.gd` |

Poza `godot/` znajdują się:
- `dane/` – własne dane projektu: definicje gier `gry.json`, układy tabel db, warstwy, gramatyka rekordu jednostki,
  pomiary mechanik `mechaniki_ee_aoc.json`, launcher;
- `narzedzia/` – Python (+C): biblioteka `eeformaty` i narzędzia pomocnicze;
  `narzedzia/eksperymenty/` – analizy do odtwarzania pomiarów (`narzedzia/README.md`);
- `docs/` – dokumentacja;
- `konfiguracja/` – `openee.cfg` (szablon) oraz `uzytkownik.cfg` (lokalnie, poza repozytorium);
- `cache/`, `wyniki/`, `audyt/`, `kopie/` – dane lokalne, poza repozytorium.

**Podział symulacja ↔ prezentacja.**
- Deterministyczne, bez węzłów sceny, testowane bez okna: `Symulacja`, `JednostkaSym`, `MapaNawigacji`, `Sciezki`,
  `PolitykaRuchu`, `FormacjaEE`, `ZegarSymulacji`, `UkladEE`.
- Warstwa wejścia: `SterowanieRTS`, `Zaznaczanie`, `ZaznaczenieEE`.
- Prezentacja: `WidokJednostek`, `WariantyGrafiki`.

Wszystkie te klasy leżą dziś w jednym katalogu `silnik/symulacja/` (§ 8, zadanie na przyszłość).

## 3. Punkty wejścia

| Wejście | Co uruchamia |
|---|---|
| `./uruchom_openee.sh` | launcher (`res://launcher/launcher.tscn` – scena główna projektu) |
| `./uruchom_openee.sh scenariusz [--gra=ee\|aoc] [--kampania=… --scenariusz-nr=N]` | `test_scenariusz` – podgląd scenariusza; domyślnie kampania testowa gry z `dane/gry.json` (EE: Wojna trojańska, AoC: Żołnierze dla Rzymu), wybierana numerem, a nie tytułem |
| `./uruchom_openee.sh rts [opcje]` | `rts_test` – ruch, zaznaczanie, rozkazy, kamera produkcyjna |
| `./uruchom_openee.sh model …`, `animacje …`, `test`, `diag` | sceny diagnostyczne modeli, animacji, terenu, zasobów |
| `./uruchom_openee.sh testy` | `godot --headless --script res://testy/uruchom_testy.gd` – komplet testów → `wyniki/testy_godot.json` |
| Riverlands_MCP `oe_render` | te same sceny na GPU z argumentem `--zrzut=` (scena `model` = `diag_modelu`, `scenariusz`, `animacje`, `rts`, `teren`) |

Zwykłe uruchomienie nie wymaga Pythona, narzędzi ani MCP. Pełny zestaw testów porównawczych wymaga danych lokalnych
z `narzedzia/przygotuj_dane_lokalne.sh`; bez nich testy są jawnie pomijane.

## 4. Przepływ danych EE / AoC

1. **Wybór gry.** Kolejność: `--gra=` → `uzytkownik.cfg [gra] wariant` → klucze sprzed etapu 11 → `aoc`. Profil
   launchera (instalacja + nakładki) nie wybiera gry (`docs/WARIANTY_GRY.md` § 5.2).
2. **Źródła.** `GryEE.definicja(gra)` podaje katalogi danych w kolejności wyszukiwania:
   - EE: tylko `Empire Earth`;
   - AoC: `Empire Earth - The Art of Conquest`, potem `Empire Earth`, jak `EE-AOC.exe` [P].

   `Zasoby` składają z tego listę źródeł (luźne pliki, potem `data.ssa`) i nakładają warstwy: `vanilla`, `aoc`,
   lokalizacja, mody.
3. **Rozwiązywanie zasobu.** `Zasoby.znajdz(klucz)` zwraca pierwsze trafienie z aktywnej warstwy wraz ze źródłem.
   Brak zasobu w trybie EE jest brakiem i nie jest zastępowany zasobem AoC. Fallback istnieje tylko w obrębie
   kolejności źródeł danej gry.
4. **Tabele `db`.** `BazaDB` rozpoznaje wariant formatu (EE 1.0 / AoC) ze struktury
   (`dane/uklad_db_warianty.json`). Identyfikatory obiektów pozostają oryginalne. Tabela niezgodna z grą daje błąd.
5. **Scenariusz.** `ScenariuszEE` czyta teren, graczy i obiekty; wersja spoza listy gry daje błąd. Kampanie są w
   `campaigns/*.ssa`, a ich listy w `*_scenariolist.txt` (`GryEE.scenariusze_kampanii` – numery niezależne od języka).
6. **Scena.** Z danych powstają teren (`TerenEE`), obiekty (`ImporterModeli`, MultiMesh, animacje), mapa nawigacji
   (`MapaNawigacji` – woda, klify, przeszkody z flag `dbobjects`) i symulacja jednostek.
7. **Pamięć podręczna** jest kluczowana grą, instalacją, warstwami i językami (`Zasoby.klucz_zrodel`); zmiana gry
   czyści ją w całości.

## 5. Godot a Riverlands_MCP

| | OpenEE (Godot) | Riverlands_MCP (lokalne repozytorium, bez `origin`) |
|---|---|---|
| Rola | silnik i gra | narzędzie badawcze: oryginalne EE/AoC pod Wine oraz renderowanie OpenEE na GPU |
| Dane gry | tylko odczyt instalacji | tylko odczyt instalacji i **pamięci procesu**; kopie scenariuszy testowych `000_EETEST_*` w folderze gry, z rejestrem i SHA-256; kopia testowa exe bez intra w osobnym katalogu |
| Zależności | żadnych od MCP | korzysta z OpenEE: `narzedzia/eeformaty` (import), nazwy scen dla `oe_render`, dokumentacja wyników |
| Testy | `godot/testy` (bez okna) | `testy/` (unittest, bez gry) + zadania na żywej grze (`Testy_MCP/ee_zadania`) |

Z OpenEE nie należy przenosić bez zmiany MCP: `narzedzia/eeformaty/`, nazw scen `test_scenariusz`, `rts_test`,
`diag_modelu`, `diag_animacji`, `test_teren` i argumentu `--zrzut=`. Opis MCP: `Riverlands_MCP/README.md`,
historia rozbudowy: `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md`.

## 6. Co działa (podsystemy)

| Podsystem | Stan | Dokument |
|---|---|---|
| Formaty: SSA, DCL/PK01, SST/TGA, CEM 1.3/2.0, db (EE i AoC), SCN 231/248–250, Language.dll | [P] – testy porównawcze z czytnikami Pythona | `docs/FORMATY*.md`, `docs/FORMATY_DB_EE_VS_AOC.md` |
| Warstwy zasobów i lokalizacja PL/EN (teksty, głosy, kampanie niezależnie) | [P] | `docs/LOKALIZACJA.md`, `docs/WARIANTY_GRY.md` |
| Teren według reguł EE, woda animowana | [P] dla reguł mieszania; tabela faz wody 33×33 – [N] | `docs/FORMATY_ETAP3.md`, `docs/FORMATY_ETAP4.md` |
| Modele: materiały, kolor gracza, alfa, odrzucanie ścian, billboardy | [P] | `docs/FORMATY_NAPRAWA_GRAFIKI.md`, `docs/FORMATY_DIAGNOSTYKA_051.md` |
| Animacje CEM i hierarchia części | [P] dane; tempo i interpolacja – [H] | `docs/FORMATY_ETAP4.md` |
| Układ współrzędnych (bez odbicia lustrzanego) | [P] | `raporty/archiwum/RAPORT_UKLAD_WSPOLRZEDNYCH_OPENEE.md` |
| Grafika zależna od epoki (warianty), przezroczystość budynków (F5) | [P] w AoC; w EE – [H] (obie?) | `docs/WARIANTY_EPOK.md`, `raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md` |
| Kamera produkcyjna wierna EE | [P] w EE i AoC | `docs/MECHANIKA_KAMERY_EE.md` |
| Zaznaczanie (klik, Shift/Ctrl, ramka) | [P] | `docs/MECHANIKA_RUCHU_EE.md` § 2 |
| Rozkaz grupy i szyk, trasy oktylowe A*, prędkość, przenikanie, objazd stojących | [P] (szczegóły z poziomami pewności w dokumentach) | `docs/MECHANIKA_RUCHU_EE.md`, `docs/MECHANIKA_PREDKOSCI_EE.md`, `docs/KOLIZJE_JEDNOSTEK_EE.md` |
| Launcher | działa; ocena wizualna tylko na GPU | `raporty/archiwum/RAPORT_LAUNCHER_UI.md` |

Rozgrywki jeszcze nie ma: brak ekonomii, walki, SI, interfejsu gry i wyzwalaczy.

## 7. Mechaniki oryginału

### 7.1. Rozpoznane

| Mechanika | Najważniejsze ustalenie | Pewność | Dokument |
|---|---|---|---|
| Kamera | azymut stały 135°, pochylenie 35°, 21 poziomów zoomu (krok 1,49 pola), przesuwanie krawędzią i strzałkami; przewijanie krawędzią w AoC rozpędza się przez ~1 s, w EE ma od razu stałą prędkość | [P] | `docs/MECHANIKA_KAMERY_EE.md`, `docs/POROWNANIE_MECHANIK_EE_AOC.md` |
| Zaznaczanie | reguły klik / Shift / Ctrl / ramka, ramka testuje punkt jednostki | [P] (dokładny punkt – [W]) | `docs/MECHANIKA_RUCHU_EE.md` § 2 |
| Grupy ruchu (kod) | `EEMPathTo::Execute` dzieli zaznaczenie na grupy `EEActiveGroup` według środowiska (powietrze, ląd + budynki, nawodne, podwodne; AoC: + kosmos) z flag typu liczonych z `Unit type`; jednostki nieruchome usuwane (poza lotniskiem); wspólny cel `EEUGLocation`; Shift = flaga grupy +0xB5; kod stanu 8000 → przydział celów jednostek (0x5DB641) | [P] | `docs/titan/grupy_ruchu.md` |
| Cele jednostek (kod) | stan 8000: szyk `EEFShortLine` – kolumny [0, −1, +1, −2, +2] × największe „Size in formation”, rzędy za celem, obrót o kąt rozkazu; przydział w ścieżce dalekiej przez sortowanie pozycji i jednostek według klucza poprzecznego (BO-2), cel `EEUGLocation` na jednostkę | [P] | `docs/titan/cele_jednostek.md` |
| Przydział bliski (kod) | cel przy grupie: jednostki po kolei (prędkość ↑, „Size of collider” ↓, numer w grupie ↑/↓ według flagi z osi +y mapy – BO-3) biorą najbliższą wolną pozycję szyku (kwadrat odległości); EE = AoC | [P] | `docs/titan/przydzial_bliski.md` |
| Gałąź specjalna przydziału (kod) | rozkaz PPM z przeciągnięciem → grupa +0xB6 („ruch w szyku”); gdy maks. „Size of collider” < 1,0 i średnia prędkość grupy +0x70 > 0,5, przydział bliski/daleki pominięty – jednostka k → pozycja k; EE = AoC | [P] | `docs/titan/przydzial_specjalny.md` |
| Kolejka rozkazów (kod) | kolejka dwustronna celów jednostki (+0x90, poziom 0), pierwszy element = cel bieżący +0x1F0; Shift dopisuje na koniec jednostkom z celem; zwykły PPM czyści kolejkę (BO-4); wejście w stan „Idle” zdejmuje cel i aktywuje następny; punkty trasy (+0x32) na początku; EE = AoC | [P] | `docs/titan/kolejka_rozkazow.md` |
| Wejście do nawigacji (kod) | dwa poziomy tras: grupowa (`EEPathManager`, lista pól → cele `EEUGLocation` +0x32 na początku kolejki, od razu albo w kolejnych taktach) i jednostki („PrepareToMove”, lokalna, poza kolejką celów); znaczniki celu +0x34 = 1–4; EE ≈ AoC | [P]/[W] | `docs/titan/nawigacja_wejscie.md`, `docs/titan/architektura_nawigacji.md`, `docs/titan/astar_pola.md`, `docs/titan/astar_wyniki.md` |
| Architektura tras (kod) | `EEPathManager` + `EEAIContinentManager`: sektory (siatka), podsektory (graf), obszary (test „ten sam obszar”); prośba jednostki: A* po grafie → punkty +0x32 → szybka próba `Bounded` → A* po polach; budżety w iteracjach (limit na wywołanie / całkowity, 0xF i −1 z etapu 22), kolejki odroczeń +0x5C / +0x70, ok. 32 iteracji na takt; przebudowa po zmianie mapy; EE ≈ AoC (AoC: ruch kosmiczny) | [W]/[P] | `docs/titan/architektura_nawigacji.md` |
| A* po polach (kod) | koszt 10/14, H = 10·Manhattan, F = G + H (całkowite); 8 sąsiadów w stałej kolejności z regułą narożników; lista otwarta: posortowana lista + 53 kubełki, uzupełnianie po 15, remis LIFO; koniec = najbliższy dostępny węzeł przy braku drogi, niedostępnym celu albo limicie; trasa pole po polu bez wygładzania → kolejka +0x7C jednostki; `Bounded` przed pełnym A*; pomiary A–E zgodne z niezależnym modelem (EE, AoC); przypadek F nierozpoznany (BO-6) | [P]/[W] | `docs/titan/astar_pola.md`, `docs/titan/astar_wyniki.md` |
| Ruch jednostki (kod) | maszyna stanów `EEUnitAction` (≤ 1 przejście na takt, przejścia ze skryptów `.tai`; zmierzone 2015 → 10003 → 9000 → 2015 → … → 9006 → 5001 → 5000) + tryby fizyki `EEPMLand` (0 jazda, 3 spoczynek, 4 stop, 5 obrót); stały krok dt; v ± a·dt (a = 2,0), hamowanie przy pozostałej drodze ≤ dyskretnej drodze hamowania, hamowanie przy błędzie kursu > 45° i na stoku; obrót trapezowy (α, ωmax z parametrów +0x34, w szyku z grupy); punkt pośredni zaliczony przy d ≤ rozmiar kolizji na polu punktu, ostatni przy d < 0,05; przeszkoda po 3–5 s ciągłego odpychania; cele +0x32 przełączane przy ≤ N punktach; EE = AoC; model zgodny z pomiarami | [P]/[W] | `docs/titan/ruch_jednostki.md`, `docs/titan/ruch_trasa_przeszkody.md` |
| Teren, kolizje, skrypty stanów (kod) | z = GetMeshZ (dwa trójkąty pola, siatka wierzchołków EEMap); nachylenie asin(Δz/1,3) z punktów ±0,65 wzdłuż osi, reguła stoku v > vmax·(1 − s·typ+0x488) tylko pod górę; test kroku: punkt końcowy, ślizg po osiach, stop na komórce ze środkiem jednostki; kontakty symetryczne, odpychanie jednostronne wg rozmiarów; +0x248 > T (losowane co takt z globalnego LCG) → objazd 9002 (A* w oknie ±50 pól); skrypty `.tai` (tekst w `data.ssa`): pierwsze pasujące przejście, jedno na takt; szyk: średnie parametry grupy; obliczenia x87 53/64 bity; model całego przebiegu EE 0,011 pola | [P]/[W] | `docs/titan/fizyka_terenu.md`, `docs/titan/kolizje_objazdy.md`, `docs/titan/skrypty_stanow.md` |
| Precyzja i testy ruchu (kod) | kurs = UMArcTan2(−m01, m11) z macierzy z tablicowych cos/sin (`Low-Level Engine.dll`, tablice 16385 / 32769 f32, niegenerowalne wzorem); FPU PC_53 = f64, zapisy f32 w ustalonych miejscach; obrót AoC (0x554F56) inny niż EE; odpychanie 0x549179 zgodne dokładnie z pomiarem; reguła „cel zajęty”; RNG z ziarnem z `TMGetTime`, deterministyczny; k szyku = 2,0; model v4: EE 517 bitowo, AoC 505 koniec w tym samym takcie; syntetyczne testy referencyjne i specyfikacja modułów Godota | [P]/[W] | `docs/titan/precyzja_numeryczna.md`, `docs/titan/walidacja_kolizji.md`, `docs/titan/testy_referencyjne_ruchu.md`, `docs/titan/specyfikacja_ruchu_godot.md` |
| Szyk grupy | siatka 5 kolumn, pierwszy rząd w punkcie rozkazu, odstęp `Size in formation`, każda jednostka z własną prędkością i trasą | [P] (przydział miejsc poza pierwszym rozkazem – [W]) | `docs/MECHANIKA_RUCHU_EE.md` § 3 |
| Trasy | najpierw przekątna, potem prosto (oktylowo) | [P] | `docs/MECHANIKA_RUCHU_EE.md` § 5 |
| Prędkość | `Speed` = pola na sekundę czasu gry; czas gry = 1,461 × rzeczywisty | [P] | `docs/MECHANIKA_PREDKOSCI_EE.md` |
| Zegar gry | obiekt `EEPhysics` (`A_GRA`): ms czasu gry `+0xD0` = suma kroków 1000·G/n (n = 44 takty/s, szybkość gry G = 1,5 → 34,09 ms); takty przydziela serwer lockstep `NESynchronousServer` (także w grze jednoosobowej): 15 taktów co 350 ms = 42,857/s, stąd tempo 1,461; n = 44 to przepełnienie bajtu (300 − 256); pauza F3 = porcje 0 taktów; algorytm identyczny w EE i AoC | [P] | `docs/titan/zegar_symulacji.md`, `docs/titan/przydzial_taktow.md`, `docs/MECHANIKA_PREDKOSCI_EE.md` § 2 |
| Kolizje | jednostki w ruchu przenikają się; pole jednostki stojącej jest omijane | [P] | `docs/KOLIZJE_JEDNOSTEK_EE.md` |
| Rozkazy | nowy PPM zastępuje rozkaz [P]; Shift+PPM dopisuje do kolejki [W]. Droga w kodzie (etap 16): `EEMPathTo` (typ 0x4D, x/y celu, bez listy jednostek – działa na zaznaczenie w symulacji z wersją) → `ProcessLocalUserInput` → kolejka serwera → takt komunikacji co 350 ms → wykonanie w `EEPhysics` przed taktami porcji | [P]/[W] | `docs/MECHANIKA_RUCHU_EE.md` § 7, `docs/titan/rozkazy_gracza.md` |
| Grafika epok | wariant modelu zależny od epoki gracza (łańcuch `dbtechtree` → `dbevents`) | [P] | `docs/WARIANTY_EPOK.md` |
| Przezroczystość budynków | tryb F5 | [P] (AoC) | `raporty/archiwum/RAPORT_EPOKI_WARIANTY_PRZEZROCZYSTOSC.md` |
| Pliki czytane przez oba exe | EE: tylko własny katalog; AoC: własny, potem EE | [P] | `docs/WARIANTY_GRY.md` § 2 |
| Intro startowe | jedna funkcja inicjalizacji (EE 0x538867, AoC 0x5439B5) | [P] | `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 17 |

### 7.2. Nierozpoznane lub częściowo rozpoznane

- Ruch:
  - przydział miejsc w szyku przy kolejnych rozkazach;
  - formacje z przycisków;
  - tryb Szybko/Sprytnie;
  - dokładny algorytm wyszukiwania tras oryginału i reguła ponownego wyznaczania trasy (objazd ok. 1,5 pola przed
    przeszkodą);
  - wspólny cel dla więcej niż 2 jednostek;
  - rozpędzanie (ok. 0,3 s, [W]);
  - dodatek +0,15 pola/s gry w scenariuszu z „Blitzkriegu” [N];
  - grupa mieszana (EE o ~20% wolniej).
- Animacje: tempo, interpolacja, sterowanie proceduralne części (wieżyczki, koła, `orbital_*`).
- Teren i mapa: tabela faz wody 33×33, nawierzchnie lądu a flagi przechodniości, ściany brzegowe mapy, mapy
  kosmiczne.
- Rozgrywka – w całości [N]: walka, ekonomia i zbieranie, budowanie, epoki (awans), cywilizacje i premie, wyzwalacze
  scenariuszy, mgła wojny i pole widzenia, SI, morale, kalamity proroków, transport.
- Scenariusze: polimorficzna lista celów jednostki (3 scenariusze EE czytane częściowo), zapis cywilizacji gracza
  w scenariuszu.
- Synchronizacja lockstep: warstwa sieci, domyślne ustawienia przydziału taktów (`docs/titan/przydzial_taktow.md` –
  zależności); dodatkowe polecenie po rozkazie ruchu i znaczenie flag `EEMPathTo` (`docs/titan/rozkazy_gracza.md`).
- EE ↔ AoC: przezroczystość budynków i renderer terenu w EE (hipoteza wspólności).

## 8. Znane problemy architektoniczne (na przyszłość)

1. **`silnik/symulacja/` łączy trzy warstwy:** symulację, wejście (`SterowanieRTS`, `Zaznaczanie`) i prezentację
   (`WidokJednostek`, `WariantyGrafiki`). Podział na osobne katalogi wymaga zmiany ścieżek w scenach, testach i MCP;
   do zrobienia przy rozbudowie interfejsu gry.
2. **Kamery w `sceny/`:** `kamera_rts.gd` jest kodem produkcyjnym, ale leży obok scen testowych. Jej miejsce to
   `silnik/kamera/`; wymaga to zmiany 5 odwołań `load()`.
3. **Duże pliki:**
   - `launcher/launcher.gd` – 1363 linie (UI, stan, uruchamianie scen);
   - `sceny/test_scenariusz.gd` – ok. 700 linii (wczytywanie, scena, kamera, raport);
   - w MCP `ee_api.py` – ok. 1580 linii.

   Podział ma sens dopiero przy kolejnych zmianach tych plików.
4. **Testy etapowe** (`testy_etapu4/5/12/13.gd`) grupują testy według etapu, a nie podsystemu. Nowe testy lepiej
   dopisywać do plików podsystemów (`testy_ruchu.gd`, `testy_kamery.gd`…).
5. Nazwy `Zaznaczanie` i `ZaznaczenieEE` są do siebie podobne, ale odpowiadają różnym rzeczom (geometria wskazania
   myszą a reguły zaznaczania). Przy zmianie nazw trzeba też zmienić testy.

## 9. Dokumenty

| Temat | Dokument |
|---|---|
| Historia wersji i obalone hipotezy | `docs/HISTORIA.md` |
| Plan | `docs/MAPA_DROGOWA.md` |
| Struktura i zasady z etapów 1–11 (historyczne) | `docs/ARCHITEKTURA.md` |
| Dwie gry: audyt i architektura | `docs/WARIANTY_GRY.md`, `docs/FORMATY_DB_EE_VS_AOC.md` |
| Formaty plików | `docs/FORMATY.md`, `docs/FORMATY_ETAP2–5.md`, `docs/FORMATY_NAPRAWA_GRAFIKI.md`, `docs/FORMATY_DIAGNOSTYKA_051.md` |
| Mechaniki | `docs/MECHANIKA_KAMERY_EE.md`, `docs/MECHANIKA_RUCHU_EE.md`, `docs/MECHANIKA_PREDKOSCI_EE.md`, `docs/KOLIZJE_JEDNOSTEK_EE.md`, `docs/WARIANTY_EPOK.md`, `docs/POROWNANIE_MECHANIK_EE_AOC.md` |
| Lokalizacja, zasoby | `docs/LOKALIZACJA.md`, `docs/ZASOBY_ORYGINALNE.md` |
| Atlas funkcji silnika Titan (zasady dokumentowania, wpisy) | `docs/titan/README.md`, `docs/titan/zegar_symulacji.md`, `docs/titan/przydzial_taktow.md`, `docs/titan/rozkazy_gracza.md`, `docs/titan/grupy_ruchu.md`, `docs/titan/cele_jednostek.md`, `docs/titan/przydzial_bliski.md`, `docs/titan/przydzial_specjalny.md`, `docs/titan/kolejka_rozkazow.md`, `docs/titan/nawigacja_wejscie.md` |
| Rejestr błędów oryginału (odtwarzanych wiernie) | `docs/titan/BLEDY_ORYGINALU.md` |
| Narzędzia | `narzedzia/README.md` |
| Raporty etapów | aktualny: `RAPORT_ETAP_27.md` (katalog główny); archiwum z opisami i zasadą archiwizacji: `raporty/README.md` |
