# OpenEE – etap 8: epoki, warianty wizualne i przezroczystość budynków

Data: 2026-11-06. Gałąź lokalna `main`, wychodząc od `2ef322d` (etap 7). Bez pusha.
Kopia przed zmianami: `kopie_OpenEE/OpenEE_przed_etapem8_2ef322d.bundle` (zweryfikowana).

Oznaczenia źródeł: **[D]** – dane gry (tabele, scenariusze), **[K]** – analiza kodu `EE-AOC.exe` (wersja GOG/NeoEE,
sha256 `db8fc5ce…`; tylko odczyt, bez kopiowania kodu), **[E]** – eksperyment w oryginalnej grze (sesja testowa MCP),
**[H]** – hipoteza robocza OpenEE.

## 0. Najważniejsze wnioski

* Różnice fortu (dachówka a strzecha) i obywatela (toga a nagi tors) **nie były błędem importu tekstur**. OpenEE
  pokazywało grafiki bazowe z `dbobjects`, a gra – warianty epoki gracza. Porównywano różne warianty:
  * oryginał: `Fortress - Bronze` / `Citizen Bronze`;
  * OpenEE przed etapem 8: `Fortress - Copper` / `Citizen Paleo`.
* Zmiana epoki podmienia **cały wiersz `dbgraphics`**: inny model CEM, inna tekstura SST i inne sekwencje animacji.
  To nie jest podmiana samej tekstury.
* Wygląd wynika z łańcucha danych:

  `blok EE gracza w scenariuszu → technologia epoki → dbtechtree → dbevents → dbeffects (kod 6) → dbgraphics`

  OpenEE odtwarza ten łańcuch bez list nazw.
* Przezroczystość budynków to **trzy tryby przełączane klawiszem F5**. Domyślny jest „standardowy”: obiekt staje się
  przezroczysty, gdy za nim stoi jednostka. Przezroczyste mogą być tylko obiekty z flagą `dbobjects` „Unknown#52”
  (budynki, drzewa, mury, cuda). Alfa wynosi 0,35. OpenEE odtwarza to jako osobną warstwę rysowania, nie ruszając
  materiałów źródłowych.
* Testy: **207/207** (punkt odniesienia 180). MCP: 18/18 (kamera 7, diagnostyka 8, przezroczystość 3).

## 1. Mechanizmy ustalone w oryginalnym EE

### 1.1 Grafika wg epoki

| Ogniwo | Ustalenie | Źródło |
|---|---|---|
| `dbobjects` | Jeden obiekt na typ, np. `Citizen` 32, `b Fortress` 672, `b House` 37. „Graphic ID” to grafika bazowa (np. 742 `Fortress - Copper`, 54 `Citizen Paleo`). | [D] |
| Scenariusz, kawałek 5 | Za częścią RTS każdego gracza stoi **blok EE**: `u32 ?, u8 1, u32 15\|14, u32 1\|2, u32 n, n × (u32 ID technologii, 3 × u8 flagi), i32 epoka, i32, i32 …`. Flaga 0 = zbadana. Pole „epoka” to ID technologii bieżącej epoki. | [D]: 63 scenariusze kampanii EE+AoC, 1071 graczy, 100 % spójności (epoka = jedyna zbadana technologia epoki z listy) + 31 innych plików |
| `dbtechtree` | Brak globalnego licznika. Plik to 15 grup „i32 liczba dzieci, rekord epoki, dzieci”. Rekord = 272 B + 4 B × „Num of tech builders”. Głowy grup to technologie epok: ID 0–14, „Epoch number” 1–15, „Event ID”. Plik zużyty co do bajta (4494 rekordy). | [D] |
| `dbevents` | Bez licznika. Rekord = nazwa (100 B), i32, i32 n, n × ID efektu. Indeks rekordu = „Event ID”, np. 62 „Epoch Paleo”, 59 „Epoch Dark”. | [D] |
| `dbeffects` | Bez licznika, 88 B na rekord. Kod 6 = zmiana grafiki: „Object 1” → „New graphic”. „Unit set ID” dla kodu 6 to zawsze 0 albo −1 (brak filtra zestawu). | [D] |
| Reguła | Grafika obiektu gracza w epoce E = grafika bazowa po nałożeniu zmian z **wszystkich** epok ≤ E, rosnąco. Scenariusz zapisuje jako zbadaną tylko bieżącą epokę, więc gra musi nakładać epoki wcześniejsze. | [D] + [E]: gracz 1 w Rzymie jest w epoce mrocznej, której zdarzenie zmienia wyłącznie dom, a fort i obywatel mają warianty brązu |
| Zmiana grafiki | Cały wiersz `dbgraphics`: model, tekstura i gniazda animacji, np. `bld_fortress_03`→`04`, `men_citizenone_01`→`04` (8 gniazd sekwencji). | [D] |
| Cywilizacja | `dbcivilization` nie ma pól grafiki. Warianty regionalne (np. `x House - Asian`, `x House - Dark`) to **osobne obiekty** umieszczane w scenariuszu (bez efektów epok, więc statyczne). | [D] |
| Ulepszenia | Poza epokami grafikę zmieniają tylko 2 zdarzenia: 662 „Robotic Farm Upgrade Research” i 663 „Nano Citizen Upgrade Research”. | [D] |
| EE a AoC | Tabele AoC (`data.ssa` AoC) nadpisują EE. AoC dodaje epokę kosmiczną (zdarzenie 628) i modele `_15` (np. `men_citizen_15`, `bld_house_15`). Schemat `dbobjects` EE 1.x jest inny (nie dekoduje się układem AoC). OpenEE używa tabel AoC dla obu gier (jak instalacja Gold); scenariusze EE (wersja 231) mają ten sam blok EE gracza. | [D] |

Liczby zmian grafiki w zdarzeniach epok:

| Epoka | Zmian | Epoka | Zmian |
|---|---|---|---|
| kamienna | 5 | renesans | 5 |
| miedzi | 11 | imperialna | 9 |
| brązu | 22 | przemysłowa | 7 |
| mroczna | 1 | atomowa WW1 | 17 |
| średniowiecze | 21 | cyfrowa | 22 |
| nano | 5 | kosmiczna | 2 |

Paleolit, atomowa WW2 i atomowa współczesna: 0 zmian.

### 1.2 Fort i obywatel – przypadki z poprzednich porównań

| | Scenariusz „Żołnierze dla Rzymu”, gracz 1 (epoka mroczna, tech 4) |
|---|---|
| Fort (672) | Bazowa 742 `Fortress - Copper` (`bld_fortress_03`, strzecha) → zdarzenie „Epoch Bronze” → 746 `Fortress - Bronze` (`bld_fortress_04`, `bld_fortress_04T.sst`, czerwona dachówka). [D] + [E: zrzut fortu] |
| Obywatel (32) | Bazowa 54 `Citizen Paleo` (`men_citizenone_01`, nagi tors) → „Epoch Stone” 55 → „Epoch Bronze” 283 `Citizen Bronze` (`men_citizenone_04`, `men_citizen_04T.sst`, toga). [D] + [E: zrzut obywateli] |
| Wniosek | W stagach 6–7 porównywano wariant epoki brązu (gra) z wariantem bazowym (OpenEE). Import tekstur jest poprawny. |

Obywatel w kilku epokach [D; render OpenEE `--epoka`]:

| Epoka | Grafika | Model | Wygląd |
|---|---|---|---|
| 1 | 54 | `men_citizenone_01` | nagi tors |
| 2–3 | 55 | `men_citizenone_02` | przepaska; potwierdzone [E] u Argos, epoka miedzi |
| 4–5 | 283 | `men_citizenone_04` | toga; potwierdzone [E] |
| 6–9 | 282 | `men_citizenone_06` | tunika |
| 10–13 | 56 | `men_citizenone_10` | koszula i spodnie |
| 14–15 | 871 | `men_citizen_15` | AoC |

Obywatelka (480) i dziecko (222) mają własne łańcuchy (tabela w docs).

### 1.3 Tabela `epoka → obiekt → wariant → model → tekstura → animacja`

Pełna tabela (156 wierszy, 15 epok, wszystkie obiekty ze zmianami grafiki) jest wygenerowana z danych gry:
**`docs/WARIANTY_EPOK.md`** (`narzedzia/warianty_epok.py`). Kolumna „Gniazda” podaje liczbę sekwencji animacji wiersza
`dbgraphics`; animacje zmieniają się razem z grafiką. Wybrane wiersze:

| Epoka | Obiekt | Wariant | Model | Tekstura | Źródło |
|---|---|---|---|---|---|
| 0 (bazowa) | b Fortress | 742 Fortress - Copper | bld_fortress_03 | bld_fortress_03T | [D] |
| 4 brąz | b Fortress | 746 Fortress - Bronze | bld_fortress_04 | bld_fortress_04T | [D][E] |
| 6 średniowiecze | b Fortress | 748 Fortress - Middle | bld_fortress_06 | bld_fortress_06T | [D] |
| 8 / 10 / 13 | b Fortress | 763 / 745 / 747 | bld_fortress_08 / 10 / 12 | …T | [D] |
| 3 miedź | b House | 170 House - Copper | bld_house_03 | bld_house_03T | [D][E: Argos] |
| 5 mroczna | b House | 171 House - Dark | bld_house_05 | bld_house_05T | [D] |
| 3 miedź | b Barracks | 35 Barracks - 03 | bld_barracks_03 | bld_barracks_03T | [D] |
| 4 brąz | b Stable | 512 Stable - Bronze | bld_stable_05 | bld_stable_05T | [D] (render OpenEE Troja; w EE – mgła wojny) |
| 3 miedź | b Settlement | 800 Settlement - Copper | bld_settlement_03 | bld_towncenter_03T | [D] |

### 1.4 Porównanie z oryginałem (sesje MCP, ta sama kamera)

Rzym (AoC) i Troja (EE):
* **Fort** – gracz 1, epoka mroczna: dachówka ✔.
* **Obywatele** – toga ✔.
* **Domy `x House - Dark/Bronze/Copper`** – obiekty scenariusza, bez efektów ✔.
* **Argos** (Troja, epoka miedzi): `House - Copper` ✔ (dachówki, niebieskie flagi) i `Citizen Stone` ✔.
* **Troja** (epoka brązu): widok w oryginale zasłonięty mgłą wojny (obszar nieodkryty), więc porównanie
  niemożliwe. Wariant brązu (`Stable - Bronze`) potwierdzają tylko dane.

## 2. Przezroczystość budynków w oryginale

| Pytanie | Ustalenie | Źródło |
|---|---|---|
| 1. Gdzie jest opcja, stan domyślny | Brak pozycji w menu opcji i w rejestrze. Klawisz **F5** („Określa tryb przezroczystości obiektów (F5)”, tekst 31552) przełącza zmienną `0x9308c8` cyklicznie **1 → 2 → 0 → 1** i pokazuje komunikat: 1 „Standardowy sposób ukrywania jednostek” (8618), 2 „Budynki zawsze przezroczyste” (8619), 0 „Budynki zawsze nieprzezroczyste” (8620). Po starcie gry wartość to **1**; tuż po uruchomieniu procesu jest 0, potem gra ustawia 1. | [K] + [E: odczyt pamięci w menu i w grze] |
| 2. Które obiekty | Tylko obiekty z bajtem `dbobjects` +0x3AE = **„Unknown#52”** (kopiowany do obiektu gry +0x316): 199 z 848 obiektów, m.in. budynki, drzewa, mury, palisady, wieże i cuda. Jednostki – nie. | [K] (zapis +0x316 ← rekord +0x3AE) + [D] + [E: domy, forty, palmy, cyprys] |
| 3. Aktywacja | Automatycznie w trybie 1 (sytuacja na ekranie). Tryb 2 – wszystkie obiekty z flagą. Tryb 0 – żaden. | [K][E] |
| 4. Obecność czy zaznaczenie | Wystarczy obecność. Niezaznaczone legionisty za domami odsłaniają je. | [E] |
| 5. Czyje jednostki | Odsłaniają jednostki gracza lokalnego. Jednostki innych graczy – tylko gdy wpis tablicy relacji gracza (`+0x9dc + 4·indeks`) jest równy 0; znaczenie tej tablicy (sojusz/wrogość) **nieustalone**. | [K]; eksperyment z obcą jednostką nie został wykonany |
| 6. Cały budynek czy części | Cały model (wszystkie części, także potomne). Znacznik obiektu jest przenoszony na części potomne. Czerwony pierścień gracza na ziemi pozostaje nieprzezroczysty. | [K][E] |
| 7. Alfa | **0,35** (stała w funkcji rysowania obiektu; obraz zgodny). | [K][E] |
| 8. Natychmiast czy płynnie | Natychmiast (brak interpolacji alfy w kodzie). Znacznik wygasa po ~1–2 s bez odświeżenia (numer 1-sekundowego okna czasu w 2 bitach znacznika). | [K]; kadry co ~4 s nie pokazują przejścia |
| 9. Wiele budynków i jednostek | Każda jednostka oznacza obiekty z flagą w **swoim polu i w polach (x, y−1), (x+1, y−1), (x+1, y)**, czyli między nią a kamerą EE (azymut 135°). Kilka budynków może być przezroczystych naraz, każdy niezależnie (dwa domy za szeregiem legionistów). | [K][E] |
| 10. Drzewa, mury | Tak, jeśli mają flagę (drzewa i palisady mają). W trybie 1 drzewo staje się przezroczyste tylko z jednostką za nim. | [D][E: tryb 2 – palmy i cyprys przezroczyste] |

**Test z jedną jednostką** (zaznaczenie i rozkazy ruchu przez MCP, kadry stałą kamerą):
* Fort z jednostką poza jego obszarem: nieprzezroczysty w trybie 1 ✔.
* Domy z jednostkami za nimi: przezroczyste w trybach 1 i 2, nieprzezroczyste w trybie 0 ✔.
* Seria „przed → za → poza” jednym legionistą wyszła niejednoznacznie:
  * kadry robione co ~4 s;
  * kliknięcia rzutowane z modelu kamery trafiały obok celu;
  * w kadrze stały inne jednostki.

  Zachowanie w czasie (wygaśnięcie znacznika) opiera się więc na kodzie [K], nie na kadrach.

## 3. Zmiany w OpenEE

### 3.1 Importery i dane

* `godot/silnik/importery/epoki_db.gd` (`EpokiDB`) – dekodery `dbtechtree` (grupy epok), `dbevents` i `dbeffects`.
  Kontrola długości danych. Odpowiednik w Pythonie: `narzedzia/eeformaty/epoki.py`.
* `godot/silnik/importery/scenariusz.gd`:
  * `blok_ee()` – odczyt bloku EE gracza (epoka i zbadane technologie);
  * wyszukiwanie bloku za graczem odczytanym częściowo;
  * `epoka_gracza(g)`.

  Python: `gracze.blok_ee`.
* `narzedzia/warianty_epok.py` – generator tabeli `docs/WARIANTY_EPOK.md` i raportu wariantów dla scenariuszy.

### 3.2 Logika wizualna

* `godot/silnik/symulacja/warianty_grafiki.gd` (`WariantyGrafiki`):
  * `grafika(obiekt, tech_epoki, zbadane)`, `mapa_grafik`, `numer_epoki`, `tech_epoki_nr`;
  * mapy liczone i buforowane dla każdego stanu gracza;
  * bez tabel – grafika bazowa (zachowanie sprzed etapu).
* `test_scenariusz.gd`:
  * grafika obiektu = `grafika_obiektu(typ, gracz)`;
  * epoki graczy pochodzą ze scenariusza;
  * `--epoka=N` albo `--epoka=gracz:N` – nadpisanie epoki do porównań;
  * `--bez-wariantow` – stan sprzed etapu;
  * `zmien_epoke(g, tech)` – przebudowa obiektów statycznych;
  * raport z liczbą wariantów i epokami graczy.
* `rts_test.gd`: `zmien_epoke` przełącza też jednostki symulacji przez `WidokJednostek.zmien_grafike`.
* `widok_jednostek.gd`:
  * przeniesienie jednostki do grupy innego modelu;
  * przebudowa wyłącznie zmienionych MultiMeshy;
  * kanały animacji zachowane: `OdtwarzaczAnimacji.przypisz`;
  * bieżący stan animacji zapamiętany.
* Simulation state (pozycja, trasa, rozkazy) się nie zmienia; potwierdza to test hasha stanu.

### 3.3 Renderer – przezroczystość

`godot/silnik/render/przezroczystosc_budynkow.gd` (`PrzezroczystoscBudynkow`):

* **Tryby i przełączanie.** Tryby 0/1/2, domyślnie 1. **F5** w scenach: cykl jak w EE. Argument `--przezroczystosc=N`.
* **Które obiekty.** Rejestrowane są tylko obiekty z flagą „Unknown#52” – brak przezroczystości globalnej.
* **Wykrywanie (tryb 1).** Według reguły pól EE. Jednostki gracza lokalnego (`--gracz-lokalny`, domyślnie 1) oznaczają
  pole swoje i trzy pola ku kamerze. Znacznik trzyma 1,5 s.
* **Koszt.** Przeliczane są tylko jednostki, które zmieniły pole, oraz odświeżenie co 0,5 s; `krok()` sprawdza wyłącznie
  obiekty aktywne. Test: ≤ 4 sprawdzenia na 2000 obiektów.
* **Rysowanie.** Materiały źródłowe nie są zmieniane. Obiekt przezroczysty rysuje kopia MultiMeshu z siatką o materiałach
  pochodnych, a egzemplarz nieprzezroczysty dostaje zerową skalę. Obiekty-węzły dostają nadpisanie materiału powierzchni.
* **Shader pochodny.** Powstaje z kodu shadera modelu (`blend_mix, depth_draw_never`, `ALPHA = 0,35`). Zachowane są:
  * ręczne odrzucanie tylnych ścian (lustrzana baza);
  * kolor gracza;
  * wycinanie alfa tekstur;
  * przesunięcie głębi.
* **Kolizje i przechodniość** bez zmian.
* **Jednostki odsłaniające** muszą być ruchome i stać na mapie. Jednostki w garnizonie (X = Y = −10000) są pomijane.
* **Pola obiektu [H].** Koło o promieniu „Size of collider” − 0,5 na środkach pól; fort na wierzchołku siatki daje 2×2
  pola, dom i drzewo 1 pole. Dobrane do kadrów EE:
  * „Size of collider” działa jak promień koła (dyplomata stoi 2,09 od środka fortu o promieniu 2);
  * legionista na skos za domem przy forcie nie czyni fortu przezroczystym.

  Przy pierwszej wersji (kwadrat 4×4) fort w OpenEE robił się przezroczysty, a w EE nie – poprawione.

### 3.4 MCP (minimalna rozbudowa istniejącego serwera)

`Riverlands_MCP/riverlands_mcp/ee_przezroczystosc.py`, rejestrowany w `ee_diag.rejestruj`. Kopia przed zmianą:
`kopie_OpenEE/ee_diag_przed_etapem8.py`.

* `ee_przezroczystosc` – odczyt trybu z pamięci (tylko odczyt). Zmiana trybu wyłącznie klawiszem F5, bez zapisu pamięci.
* Funkcje zadań:
  * `przezr_tryb`, `przezr_ustaw`;
  * `kursor_ostroznie` – pętla zamknięta z adaptacyjnym wzmocnieniem i marginesem krawędzi (stary `kursor`
    przestrzeliwał na krawędź okna i przewijał kamerę EE);
  * `klik_ostroznie`;
  * `klik_mapa` – klik w punkt mapy przez model kamery.
* Testy: `testy/test_ee_przezroczystosc.py` (3).

## 4. Wyniki porównań (Vulkan, RTX 5090, 3440×1440, kamera etapu 6, układ etapu 7)

Zestawienie: `cache/etap8/porownanie_EE_OpenEE.png` (lokalnie, bez publikacji). Zrzuty EE i OpenEE: `Testy_MCP/zrzuty`,
`Testy_MCP/oe_render/*_e8_*`.

| Widok (EE ↔ OpenEE) | Wynik |
|---|---|
| Domy + legionisty, tryb 1 | zgodne: dwa domy przezroczyste, fort i palmy nieprzezroczyste |
| Ten sam widok, tryb 2 | zgodne: forty, domy i palmy przezroczyste, jednostki nie |
| Ten sam widok, tryb 0 | zgodne: wszystko nieprzezroczyste |
| Forty gracza 1 | zgodne: `Fortress - Bronze` (dachówka); przed etapem – strzecha |
| Obywatele gracza 1 | zgodne: toga; przed etapem – nagi tors |
| Troja, Argos (miedź) | zgodne: `House - Copper`, `Citizen Stone`; przed etapem – chaty paleolitu |
| Troja, miasto Troja (brąz) | w EE mgła wojny – brak porównania; OpenEE: `Stable - Bronze` wg danych |

Pozostają różnice niezwiązane z etapem: oświetlenie i jasność terenu (EE ciemniejsze) oraz drobne przesunięcie ogniska
(tolerancja ustawiania kamery EE 0,1–0,35 pola). Pełnej zgodności nie ogłaszam (patrz §6).

## 5. Testy

* Godot: **207/207** (`wyniki/testy_godot.json`). Nowe:
  * **W8** (`testy/testy_warianty.gd`, 14 testów):
    * dekodery i odrzucanie błędnych danych;
    * wybór wariantu, kolejność epok, technologie nie-epokowe;
    * brak tabel → bazowa;
    * blok EE;
    * dane AoC (15 epok, liczby zmian);
    * Rzym: epoki graczy oraz fort i obywatel – model i tekstura;
    * Troja;
    * zmiana wariantu w trakcie symulacji (hash stanu, MultiMeshe, kanał i stan animacji, dalszy ruch do celu).
  * **P8** (`testy/testy_przezroczystosci.gd`, 13 testów):
    * pola obiektu;
    * shader pochodny i nietknięty materiał źródłowy;
    * tryby 0/1/2 i F5;
    * jednostka za, przed i w polu budynku;
    * wygaszanie znacznika;
    * brak niezamierzonej przezroczystości (obiekt bez flagi i sąsiedni budynek);
    * ograniczenie przetwarzania;
    * obiekty-węzły.
  * Dotychczasowe testy animacji, kamery, układu i RTS bez zmian (zaliczone).
* Render RTS (Troja, `--rts-demo`) bez błędów w logu. Scena scenariusza: 0 błędów w każdym przebiegu.
* MCP: kamera 7/7, diagnostyka 8/8, przezroczystość 3/3.

## 6. Niewiadome i ograniczenia

* Znaczenie dwóch i32 po epoce w bloku EE gracza oraz pierwszego u32 bloku – nieustalone. Epoka jest potwierdzona
  w 1071/1071 graczy.
* Kolejność nakładania zmian w obrębie jednej epoki: kolejność listy zdarzenia (w danych nie ma konfliktów w jednej
  epoce). Technologie nie-epokowe nakładane są po epokach [H]. W scenariuszach kampanii nie spotkano zbadanych
  ulepszeń 662/663.
* Przezroczystość – ograniczenia:
  * relacja graczy, dla której cudze jednostki odsłaniają budynki, jest nieustalona; OpenEE używa tylko gracza lokalnego;
  * zajętość pól obiektu w siatce EE jest przybliżona (§3.3 [H]);
  * obiekty animowane (VAT) z flagą przezroczystości (np. młyny) nie są jeszcze obsługiwane; dotyczy to tylko obiektów
    z sekwencją bezczynności;
  * czas wygasania przyjęto jako 1,5 s wg kodu, bez pomiaru kadrami.
* Test ruchu jednej jednostki w oryginale udał się częściowo (§2): zaznaczanie i rozkazy działają, ale serii kadrów
  „przed/za/poza” nie da się jednoznacznie odczytać.
* Zmiana epoki w trakcie gry w oryginale nie była weryfikowana eksperymentalnie (brak mechaniki epok w automatycznej
  sesji). OpenEE pozwala ją wywołać (`zmien_epoke`) i testuje ją automatycznie.
* Troja (brąz) – brak kadru porównawczego z EE (mgła wojny).

## 7. Stan Git

* Commit lokalny etapu 8 na `main` (hash w podsumowaniu sesji). `origin/main` jest w tyle o 4 lokalne commity:
  `0d7bd49`, `2ef322d` i ten etap (oraz wcześniejszy nieopublikowany).
* Bez pusha i bez zmian historii. Zasoby gry, zrzuty i tekstury nie trafiają do repozytorium (katalogi `cache/`,
  `wyniki/` są ignorowane).
* Instalacje EE: kopie scenariuszy `000_EETEST_rzym.scn` i `000_EETEST_troja.scn` usunięte po sesjach, gra zamknięta.
  Plików gry ani rejestru nie zmieniano.
