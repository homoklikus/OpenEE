# Dwie gry na jednym silniku – Empire Earth i The Art of Conquest

Etap 11 (uzupełnienie). OpenEE obsługuje **Empire Earth** (`ee`) i **Empire Earth: The Art of Conquest** (`aoc`)
jako dwie odrębne gry na wspólnym silniku, a nie jedną grę z opcjonalnym dodatkiem. Dokument opisuje organizację
instalacji, wyniki audytu obu gier, model konfiguracji i podział na kod wspólny i definicje gier.

Oznaczenia pewności: **[P]** potwierdzone pomiarem lub danymi, **[W]** wniosek z danych, **[H]** hipoteza.
Zakres ustalenia: **(EE)** tylko Empire Earth, **(AoC)** tylko The Art of Conquest, **(obie)** obie gry,
**(obie?)** wspólność jest jedynie hipotezą.

Narzędzie audytu: `narzedzia/audyt_ee_aoc.py <instalacja> <wynik.json>` (tylko odczyt; wynik – liczby, nazwy i skróty,
bez treści zasobów, w `cache/`, poza repozytorium). Pomiar plików otwieranych przez oryginał: kroki MCP
`uruchom_ee_podstawowe`, `pliki_otwarte`, `zamknij_ee_podstawowe` (Riverlands_MCP, `ee_wariant.py`).

## 1. Organizacja instalacji [P]

Instalacja GOG „Empire Earth Gold” (referencyjna) i instalacja społecznościowa mają ten sam układ: dwa katalogi gier.

| | Empire Earth | Empire Earth – The Art of Conquest |
|---|---|---|
| plik wykonywalny | `Empire Earth.exe` | `EE-AOC.exe` |
| `Data/data.ssa` | 3739 wpisów, 163 MB | 826 wpisów, 45 MB |
| kampanie (`Data/Campaigns`) | EETheGreeks, EETheBritish, EETheGermans, EETheFuture, EELearningCampaign | AOCRoman, AOCAsian, AOCPacific, EELearningCampaign (inny plik niż w EE) |
| `Language.dll` | 3398 napisów | 3707 napisów |
| skrypty `.rmv` (luźne pliki) | 55 | 94 |
| plików w katalogu | 295 | 299 |

Pliki o tej samej nazwie nie zawsze są takie same: 234 pliki są identyczne (głównie WONLobby, redist, ddraw.dll,
Mss32.dll, binkw32.dll, sxlrt233.dll), 17 różni się treścią (m.in. `data.ssa`, `Language.dll`,
`Low-Level Engine.dll`, `Default.dll`, `DX7HR*Display.dll`, `EELearningCampaign.ssa`,
`Tournament Islands Medium.rmv`).

## 2. Jak oryginał korzysta z plików [P]

Pomiar `/proc/<pid>/fd` i `/proc/<pid>/maps` działających procesów (instalacja społecznościowa uruchamiana przez Lutris,
zadania MCP 164 i 165, 6 listopada 2026):

* **`Empire Earth.exe` (EE)** otwiera wyłącznie `Empire Earth/Data/data.ssa`, `Empire Earth/Language.dll`,
  `Empire Earth/Low-Level Engine.dll` i pozostałe biblioteki z katalogu `Empire Earth`. **Nie sięga do żadnego pliku AoC.**
  Gra dochodzi do menu głównego.
* **`EE-AOC.exe` (AoC)** trzyma otwarte **oba** archiwa: `Empire Earth - The Art of Conquest/Data/data.ssa` oraz
  `Empire Earth/Data/data.ssa`. `Language.dll`, `Low-Level Engine.dll` i biblioteki wyświetlania ładuje tylko z
  własnego katalogu.

Wniosek: AoC w oryginale jest nakładką na dane EE. Archiwum AoC nie zawiera 3614 kluczy EE, m.in. 725 modeli,
2095 tekstur i 757 dźwięków [P]. Pierwszeństwo archiwum AoC przed EE jest wnioskiem [W]: tabele bazy w pamięci AoC
mają układ i liczność AoC (848 obiektów, typy 724–847 w scenariuszach AoC), a archiwum AoC zawiera pełny komplet
39 tabel `db`. Kolejność odczytu pojedynczego pliku nie została zmierzona bezpośrednio (wymagałaby śledzenia odczytów).

## 3. Różnice danych – audyt

### 3.1. Archiwa `data.ssa` [P]

* Ten sam format archiwum (`rass`, wersja 1) w obu grach (obie).
* Wspólne klucze: 125, w tym 55 identycznych (4 tabele `db`, 47 skryptów TAI, 2 tekstury, 1 model, 1 dźwięk) i 70 różnych
  (34 tabele `db`, 21 cywilizacji `.civ`, 11 skryptów TAI, 4 modele: `amb_fishies`, `bld_barracks_06`,
  `bld_thetempleofzeus_04`, `bld_tower_08`).
* Tylko w AoC: 701 wpisów (131 modeli, 403 tekstury TGA, 22 SST, 128 dźwięków, 14 skryptów TAI, 2 cywilizacje,
  tabela `dbcivpowers`).
* Tylko w EE: 3614 wpisów (pełny zestaw zasobów bazowych oraz pliki robocze: `copy of dbgamevariant.dat`,
  dzienniki konwertera, `vssver.scc`).

Skutek dla OpenEE: ten sam klucz (np. `models/bld_barracks_06.cem`) może mieć w każdej grze inną treść, więc
pamięć podręczna nie może być współdzielona między grami (§ 5.3).

### 3.2. Bazy `db` [P]

Szczegóły formatu: `docs/FORMATY_DB_EE_VS_AOC.md`. W skrócie:

* Układ rekordu różni się w `dbobjects` (EE 1948 B / AoC 1960 B), `dbcivilization` (416 / 600 B),
  `dbtechtree` (268 / 272 B) i `dbeffects` (68 / 88 B). Pozostałe tabele mają wspólny układ i różnią się
  liczbą rekordów (obie).
* `dbobjects`: EE 724 rekordy (ID −1…723), AoC 848 (−1…847). Wszystkie identyfikatory EE istnieją w AoC.
  AoC dodaje 126 identyfikatorów. Przy wspólnych ID 3 nazwy, 1 grafika i 2 zestawy statystyk są różne, a wiele
  pól ruchu ma inne wartości (np. „Idle turning speed” w 414 rekordach) – AoC zmieniło balans (AoC).
* Powiązania `dbobjects → dbgraphics` są kompletne w obrębie każdej gry (0 brakujących grafik w EE i w AoC).
  `dbgraphics`: EE 858, AoC 991 rekordów, 836 wspólnych ID, z czego 3 mają inny model.
* Epoki (`dbtechtree`): EE 0–14, AoC 0–15 (AoC dodaje epokę 15). Technologie: EE 4426, AoC 4494 rekordów.
* Tylko AoC: `dbcivpowers` (moce cywilizacji). Tylko EE: `copy of dbgamevariant.dat` (plik roboczy).

### 3.3. Scenariusze i kampanie [P]

* Kampanie EE: wszystkie scenariusze w wersji formatu 231. Kampanie AoC: wersja 250.
  `EELearningCampaign.ssa` w katalogu AoC jest innym plikiem niż w EE i zawiera wersje 231, 248 i 249.
* AoC wczytuje scenariusze EE w wersji 231: kampania EE „wojna trojańska”, skopiowana do `Scenarios`, uruchomiona
  w AoC, dała 5370 obiektów w pamięci gry wobec 5327 w pliku (etap 11, faza D).
* [P] Podstawowe EE nie wczytuje scenariuszy w wersji 250: komunikat „Plik z zapisaną grą jest nieprawidłowy” (etap 12).
  OpenEE zgłasza taki przypadek jako błąd, ale nie przerywa wczytywania.
* [P] Scenariusz EE w wersji 231 („wojna trojańska”) daje w pamięci podstawowego EE i AoC po 7 graczy i 5368 obiektów
  (etap 12).

### 3.4. Identyfikacja jednostek, budynków i efektów [P]

Obie gry identyfikują obiekty liczbowym ID z `dbobjects` i grafiką przez `Graphic ID` → `dbgraphics`. Efekty
identyfikują przez ID w `dbeffects`, a zdarzenia przez `dbevents`. Identyfikatory EE mają w AoC to samo znaczenie
(ten sam obiekt), ale nie zawsze te same wartości pól. ID 724–847 istnieją tylko w AoC: scenariusz AoC wczytany w trybie
EE daje obiekty spoza bazy, zgłaszane jako `typy_spoza_bazy` (215 obiektów w „Żołnierzach dla Rzymu”).

### 3.5. `Language.dll` [P]

3226 napisów jest identycznych, 126 ma ten sam ID i inny tekst, 46 występuje tylko w EE (ID 32068–32113), a 355 tylko
w AoC. Każda gra ładuje własną bibliotekę (§ 2). OpenEE czyta `Language.dll` wybranej gry.

### 3.6. Skrypty map `.rmv` [P]

Skrypty AoC są nadzbiorem skryptów EE: 54 identyczne, 1 różny (`Tournament Islands Medium.rmv`) i 39 nowych
(Mars, Earth, Small, Large i Tournament Planets wraz z `Common/Planet*` i `Mars Terrain Painting`). Skrypty leżą jako luźne pliki,
nie w `data.ssa`. Generator map OpenEE (poza zakresem etapu 11) musi brać katalog skryptów wybranej gry.

### 3.7. Biblioteki `Low-Level Engine.dll` i pozostałe PE [P]

* `Low-Level Engine.dll`: EE 1 118 295 B (znacznik czasu 2002-09-11, patch 1.0.4.0), AoC 1 138 762 B (2002-08-16).
  Eksporty: EE 4432, AoC 4446. 19 symboli tylko w AoC, m.in. budowa siatki terenu z klifami i wodą
  (`GETerrainMesh::AddCliffPolys`, `AddTilePolys`, `AddWaterPolys`, `GetCliffRenderVertices`). 5 symboli tylko w EE.
  Importowane biblioteki są takie same.
* [H] Dodatkowe funkcje siatki terenu w AoC mogą oznaczać inny sposób budowy klifów i wody w renderingu (obie?).
  Renderer terenu OpenEE był weryfikowany na AoC. Zgodność z EE na danych EE wymaga osobnego porównania z oryginałem EE.
* `DX7HRDisplay.dll`, `DX7HRTnLDisplay.dll`, `Default.dll`, `TCP Protocol.dll`, `Miles Sound System Mixer.dll` różnią się
  kompilacją (inne znaczniki czasu, te same liczby eksportów). `Mss32.dll`, `binkw32.dll`, `sxlrt233.dll` i `ddraw.dll`
  są identyczne.
* Pliki wykonywalne w instalacji GOG są zmodyfikowane względem wydań z 2001–2002 roku: `Empire Earth.exe` ma znacznik
  czasu z 2017 roku, `EE-AOC.exe` – zerowy. Instalacja społecznościowa ładuje dodatkowo `dreXmod.dll` (NeoEE).

## 4. Co jest wspólne, a co specyficzne

| Obszar | Status | Uwagi |
|---|---|---|
| format archiwum SSA, PK01/DCL, CEM, SST | wspólny (obie) [P] | ten sam importer |
| format SCN, kawałki i teren | wspólny (obie) [P] | wersje 231 / 248–250 obsługiwane jednym parserem |
| układ rekordów 4 tabel `db` | specyficzny [P] | warianty `ee`/`aoc` (dane/uklad_db_warianty.json, EpokiDB.TECH/EFEKT) |
| zawartość baz (obiekty, statystyki, epoki) | specyficzna [P] | każda gra czyta własne tabele |
| `Language.dll` | specyficzna [P] | |
| kampanie | specyficzne [P] | menu kampanii gry – własny katalog |
| skrypty `.rmv` | specyficzne (AoC ⊃ EE) [P] | |
| kamera RTS (MECHANIKA_KAMERY_EE.md) | wspólna (obie) [P] – etap 12 | zmierzona w EE i AoC na tym samym scenariuszu; narastanie przewijania krawędzią tylko w AoC [W], niezaimplementowane |
| zaznaczanie, ruch grupowy, szyk (MECHANIKA_RUCHU_EE.md) | wspólne (obie) [P] – etap 12 | prędkość = `Speed` z bazy wybranej gry × mnożnik zależny od scenariusza, ten sam w obu grach; unikanie przy grupach naprzeciw w EE [N] |
| przezroczystość budynków, warianty epok | zmierzone w AoC; (obie?) [H] | epoka 15 tylko w AoC |
| renderer terenu | weryfikowany w AoC; (obie?) [H] | patrz § 3.7 |

## 5. Architektura OpenEE

### 5.1. Wspólny silnik, osobne definicje gier

Kod silnika (importery, renderowanie, animacje, teren, kamera, symulacja, UI, nawigacja) jest wspólny. Różnice gier
opisują dane, a nie rozgałęzienia kodu:

* `dane/gry.json` – dla każdej gry: katalog, plik exe, **katalogi danych w kolejności wyszukiwania**, katalogi kampanii,
  `Language.dll`, format bazy, wersje SCN, warstwy bazowe, zakres epok i dowód z pomiaru;
* `godot/silnik/rdzen/gry_ee.gd` (`GryEE`) – odczyt definicji, lista kampanii, położenie archiwum kampanii, dostępność gry
  w instalacji;
* `dane/uklad_db_warianty.json`, `BazaDB`, `EpokiDB` – warianty formatu bazy rozpoznawane ze struktury danych.

### 5.2. Konfiguracja – gra niezależna od profilu

* `[gra] wariant = "ee" | "aoc"` – wybór gry. Pierwszeństwo: argument `--gra=` → `uzytkownik.cfg [gra] wariant` →
  `uzytkownik.cfg [zrodlo] profil` (klucz sprzed etapu 11) → `openee.cfg [gra] wariant` → `openee.cfg [zrodlo] profil` → `aoc`.
* Profil launchera: instalacja bazowa i mody (nakładki). **Nie zawiera gry.** Ten sam profil, np. instalacja
  społecznościowa z nakładką HD i polską lokalizacją, działa z obiema grami. Języki tekstów, głosów i kampanii są
  niezależne od gry i profilu.
* Warstwy bazowe wynikają z gry (`ee` → `vanilla`, `aoc` → `vanilla`, `aoc`), a mody profilu są do nich doklejane.
* **Migracja:** profile `vanilla_aoc` i `vanilla_ee` są aliasami profilu `vanilla` z grą `aoc` lub `ee`. Przy pierwszym
  uruchomieniu launcher dopisuje do `uzytkownik.cfg` klucz `[gra] wariant` (z dotychczasowego wyboru) i zamienia
  `launcher/profil`. Niczego nie usuwa, a `[zrodlo] profil` jest dalej zapisywany dla zgodności. Kopia sprzed migracji:
  `konfiguracja/uzytkownik.cfg.przed_etapem11`. Pole `gra` w profilach użytkownika jest ignorowane i pozostaje w pliku.

### 5.3. Izolacja danych

* Tryb EE czyta wyłącznie katalog `Empire Earth`: bazę EE, archiwum EE, `Language.dll` EE i kampanie EE.
  Brak zasobu jest brakiem – nie jest zastępowany odpowiednikiem z AoC.
* Tryb AoC czyta `Empire Earth - The Art of Conquest`, a potem `Empire Earth` – to jawne, udokumentowane współdzielenie
  odpowiadające zachowaniu `EE-AOC.exe` (§ 2). Kampanie EE są w AoC dostępne jawnie, z uwagą w dzienniku. Menu
  kampanii pokazuje tylko kampanie z katalogu AoC.
* Kampania AoC w trybie EE daje błąd „Kampania … nie należy do gry Empire Earth”. Scenariusz w wersji spoza listy
  gry jest zgłaszany jako błąd.
* Pamięć podręczna Zasobów (tabele `db`, obrazy, zestawy tekstur, modele CEM) jest kluczowana grą, instalacją,
  warstwami i językami (`Zasoby.klucz_zrodel`). Każda zmiana gry lub profilu czyści ją w całości (`przebuduj_zrodla`).
  `Zasoby.tabela()` sprawdza klucz i przebudowuje źródła, jeśli konfigurację zmieniono z pominięciem przebudowy.
  Przed etapem 11 modele CEM i zestawy tekstur nie były czyszczone przy zmianie źródeł.
* Format tabeli niezgodny z grą (np. tabela AoC w trybie EE) jest błędem, nie ostrzeżeniem.

### 5.4. Launcher

Ekran główny ma kartę **Gra** z wyborem „Empire Earth” albo „Empire Earth: The Art of Conquest”. Przycisk gry jest
nieaktywny, jeśli instalacja profilu jej nie zawiera. Pod przyciskami widać liczbę kampanii wybranej gry.
Szczegóły profilu pokazują grę jako wybieraną osobno. Pozostałe elementy launchera bez zmian.

## 6. Ograniczenia

* Etap 12: narzędzia MCP znają układ pamięci obu plików wykonywalnych (osobne definicje wariantów, bez wspólnych
  offsetów niepotwierdzonych w obu grach). Obiekty „wojny trojańskiej” w pamięci podstawowego EE zgadzają się z plikiem:
  5325/5327 ID, typ i gracz 5325/5325 [P].
* Kamera i ruch grupowy są zmierzone w obu grach (etap 12, `docs/POROWNANIE_MECHANIK_EE_AOC.md`). Przezroczystość
  budynków i renderer terenu w EE nadal są tylko hipotezą wspólności (obie?) [H]; kadry EE i AoC tej samej sceny mają
  tę samą geometrię, modele i wodę [P].
* Kolejność odczytu archiwów w AoC (AoC przed EE) jest wnioskiem z zawartości baz w pamięci, a nie ze śledzenia odczytów.
* Launcher w trybie headless nie robi zrzutów ekranu, a MCP nie renderuje sceny launchera. Karta gry jest sprawdzona
  testem budowy sceny i testami modelu, bez oceny wizualnej.
