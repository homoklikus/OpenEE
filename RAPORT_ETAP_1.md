# OpenEE – RAPORT ETAPU 1: fundament projektu i separacja zasobów Empire Earth

Data: 2026-11-05. Katalog: `<katalog instalacji> AI/EE Projekt/OpenEE/`.
Oznaczenia: **[D]** potwierdzone (test, porównanie bajtowe, dowód w pliku), **[K]** częściowo potwierdzone /
wniosek pośredni, **[H]** hipoteza, **[?]** nierozpoznane.

## Podsumowanie

| Priorytet | Wynik |
|---|---|
| 1. Nie naruszyć instalacji EE | **spełniony** – ponowny audyt: 2297/2297 plików z identycznym SHA-256 i datą; gra nie była uruchamiana; zapis wyłącznie w `OpenEE/` [D] |
| 2. Oddzielić vanilla od dreXmoda i NeoEE | **częściowo** – NeoEE i dreXmod potwierdzone dowodami w plikach; lokalizacja PL potwierdzona; vanilla/AoC tylko „średnio” (brak sum referencyjnych); **czystej wersji vanilla w instalacji nie ma** [D] |
| 3. Uruchamialny projekt OpenEE | **spełniony** – Godot 4.7.2, 17/17 testów automatycznych [D] |
| 4. Autentyczne zasoby EE w Godocie | **spełniony dla testu** – teren ze scenariusza kampanii, oryginalne tekstury i model budynku wczytane z archiwów przez importery GDScript [D] |

Najważniejsze odkrycie: instalacja **nie pochodzi z GOG**, lecz z instalatora społeczności
„NeoEE v2.0.0.5 – Setup v1.7.2 (Empire Earth Community & NeoEE)” z komponentami: gra, AoC, pakiety HD,
dreXmod v3, cywilizacje społeczności, polska lokalizacja.

## 1. Rozpoznanie środowiska

* Instalacja: `…/drive_c/GOG Games/Empire Earth Gold Edition/` – katalogi `Empire Earth/` (594 MB),
  `Empire Earth - The Art of Conquest/` (300 MB), `A24FCC7A-…/EEStatsSetup.dll`, deinstalator `unins000.*`.
  Pliki NeoEE i dreXmoda występują w **obu** katalogach gry (osobne kopie).
* Wersje: `Empire Earth.exe` (nagłówek PE 2002-09-23, 11,98 MB, sekcja `.neoee`), `EE-AOC.exe` (PE 2002-08-21,
  sekcja `.neoee`); NeoEE 2.0.0.5 (rejestr), `zzWONVersion.cfg` AoC: „Version: 2.0.0.5”.
* Godot: **4.7.2-stable** (`…/SpaceGame-Godot/Godot_v4.7.2-stable_linux.x86_64`, kopia także w `EmpireEarth test/`).
  Używany wyłącznie do odczytu/uruchamiania – SpaceGame nie był modyfikowany. Skrypt `uruchom_openee.sh` szuka Godota
  w zmiennej `GODOT`, w PATH i w tych lokalizacjach.
* **MCP Godota nie był dostępny w tej sesji** (Claude Desktop zgłaszał tylko serwery `rea` i `riverlands-ee`).
  Zamiast niego użyto Godota z linii poleceń (`--headless --script` dla testów, Xvfb + llvmpipe dla zrzutów).
  Nowego serwera MCP nie budowano.
* Narzędzia w środowisku roboczym: Python 3.10 (numpy, Pillow, pefile), Xvfb, Mesa llvmpipe; sieć do GOG/empireearth.eu
  zablokowana (referencję GOG pozyskano przez stronę gogdb.org).
* Katalog `OpenEE/` był pusty – nie było plików do zabezpieczenia kopią; stan końcowy opisuje `SUMY_SHA256.txt`.

## 2. Audyt i separacja warstw

Szczegóły i pełna lista dowodów: **`audyt/RAPORT_SEPARACJI_WARSTW.md`**; manifest: `audyt/manifest_zasobow.json`
(+ `.csv`), wpisy archiwów: `audyt/manifest_archiwow.json`.

Źródła dowodów: rejestr Wine (wpis deinstalatora + wybrane komponenty), dziennik deinstalacji `unins000.dat`
(2732 ścieżek), SHA-256 i metadane PE 2297 plików, sekcje `.neoee`, napisy (PDB, konfiguracje, teksty PL),
zawartość archiwów SSA, porównanie luźnych plików z wpisami archiwów, lista plików GOG 2.0.0.2974 v3 z gogdb.org
(nazwy + zaokrąglone rozmiary, bez sum). Sama nazwa/data/lokalizacja nie była dowodem.

| Warstwa | Plików | Najważniejsze | Pewność |
|---|---|---|---|
| neoee | 43 | oba EXE i `TCP Protocol.dll` (sekcja `.neoee`), `neoee.dll`, `NeoEE.cfg`, Updater, `_NeoEEResource.cfg` | wysoka [D] |
| drexmod | 940 | `dreXmod.dll/.config`, `Data/dxm/**` (motywy yukon/energycube – średnia) | wysoka/średnia [D] |
| localization | 33 | `Language.dll` ×2 (teksty PL), 8 archiwów kampanii (polskie scenariusze), `data.ssa` AoC (PL), `Languages/*` | wysoka [D] |
| vanilla | 408 | DLL silnika, muzyka, część filmów, RMS, lobby – zgodność nazwy i zaokrąglonego rozmiaru z GOG | średnia/niska [K] |
| aoc | 369 | analogicznie dla AoC | średnia/niska [K] |
| nieustalone | 457 | **`data.ssa` EE (171,3 MB vs 163 MB GOG)**, 252 luźne nadpisania (HD tekstury, MP3, db), `DX7HRGame.dll` (UCyborg), film intro HD, cywilizacje społeczności | – [?] |
| dane_użytkownika | 47 | zapisy gry, scenariusze testowe Riverlands/REF, `Polska.civ` | wysoka [D] |

**Ograniczenie zasadnicze:** oryginalne angielskie `Language.dll`, kampanie, `data.ssa` AoC oraz niezmodyfikowane
EXE nie istnieją w instalacji; `data.ssa` EE zostało zmienione w nieustalony sposób. Odtworzenie vanilla wymaga
zewnętrznego legalnego źródła (np. instalator offline GOG użytkownika) i odrębnej zgody. Nic nie zostało
przywrócone, przeniesione ani usunięte.

## 3. System warstw OpenEE

* Identyfikatory: `vanilla`, `aoc`, `localization`, `neoee`, `drexmod`, `user_mods` (+ pseudo-warstwy
  `nieustalone`, `nieustalone_nadpisania`) – `dane/warstwy.json`.
* VFS (`godot/silnik/zasoby/zasoby.gd`): źródła luźne AoC → `data.ssa` AoC → luźne EE → `data.ssa` EE; każde źródło
  ma warstwę z manifestu; nieaktywne warstwy są pomijane. Domyślnie aktywne: `vanilla, aoc, localization, nieustalone`
  (bez luźnych nadpisań HD – bliżej oryginału). Test potwierdza przełączanie: ta sama tekstura pochodzi z archiwum
  lub – po włączeniu `nieustalone_nadpisania` – z luźnego pliku HD [D].
* Niezależna aktywacja: możliwa dla dreXmoda (osobne katalogi), luźnych nadpisań HD i danych użytkownika.
  Lokalizacja i NeoEE **zastąpiły** oryginały, więc nie da się ich wyłączyć bez utraty zasobów.
* Wersje pośrednie wyłącznie w `OpenEE/cache/` (odtwarzalne skryptami z `narzedzia/`).

## 4. Rozpoznane formaty (szczegóły: `docs/FORMATY.md`)

| Format | Stan | Weryfikacja |
|---|---|---|
| SSA (`rass`) | [D] | EE 3739 + AoC 826 wpisów; Python = GDScript (liczba wpisów, SHA-256 próbki 48/48); poprawiono opis pola 0x0C z dokumentacji laboratorium |
| PK01 / DCL | [D] | rozpakowane SHA-256 Python = GDScript (76 tekstur + model) |
| SST / TGA | [D] | 2095/2095 SST EE, 22/22 SST AoC, 140 TGA AoC bez błędu; układ: 14 B nagłówka + N × (bajt znacznika + TGA) |
| CEM 2.0 | [D] | 719/730 EE, 136/136 AoC; 11 modeli EE w wersji 1.3 – nieobsługiwane [?] |
| SCN – kawałki | [D] | 6/6 scenariuszy kampanii AoC; nagłówek zawiera 7 napisów ANSI (raport SCN mówił „wstr”) |
| EEMap – teren | [D] | wysokości, tereny, flagi, klasy; narożniki pola potwierdzone: `f10 = min(narożników)` w 31 477/31 500 pól |
| `dbterrain.dat` | [D] | rekordy ID → tekstura bazowa; ID zgodne z danymi Riverlands; AoC dodaje ID 79–92 |
| Animacje CEM, skala modeli, przejścia tekstur, klify, kolor gracza | [?] | opisane jako przeszkody/nierozpoznane |

Wykorzystane prace laboratorium zostały zweryfikowane na nowych przykładach; wykryte nieścisłości: pole 0x0C SSA,
typ 7 napisów nagłówka SCN. Z Riverlands nie kopiowano kodu – OpenEE ma własne, mniejsze moduły
(`narzedzia/eeformaty`: dcl, ssa, sst, cem, scn).

## 5. Fundament w Godocie (`godot/`)

* `project.godot` (Godot 4.7, GL Compatibility), autoloady: `Dziennik`, `Konfiguracja`, `Zdarzenia`, `Zasoby`.
* `konfiguracja/openee.cfg` – lista kandydatów ścieżki instalacji (+ `OPENEE_EE_PATH`), warstwy, cache, skala.
* Importery: interfejs `ImporterEE`; `DCL`, `ArchiwumSSA`, `ImporterTekstur` (SST/TGA → Image), `ImporterModeli`
  (CEM → ArrayMesh). Importery nie otwierają plików – dostają bajty od systemu zasobów.
* `Zdarzenia`: kanał symulacyjny (kolejka tick+sekwencja, deterministyczna kolejność) i lokalny (sygnały).
* `silnik/api/api_modow.gd` – projekt punktów wejścia API modów z podziałem SYM/LOK; **bez interpretera Lua**.
* Ekran startowy `sceny/diagnostyka.tscn` (instalacja, warstwy, źródła, dziennik); dziennik w `user://logi/`.
* Architektura: `docs/ARCHITEKTURA.md`.

## 6. Testy

| Test | Wynik |
|---|---|
| Godot `testy/uruchom_testy.gd` (konfiguracja, SSA vs Python, DCL vs Python, CEM, SST, warstwy, zdarzenia) | **17/17** (`wyniki/testy_godot.json`) |
| Python – pełny test archiwum EE (`wyniki/test_formatow_ee_pelny.json`) | SST 2095/2095, TGA 31/31, CEM 719/730 (11 × v1.3), DB 39/39 |
| Python – próbka AoC (`wyniki/test_formatow_aoc_probka.json`) | CEM 136/136, SST 22/22, TGA 140/140, DB 39/39 |
| Kontrola nienaruszenia instalacji (`wyniki/kontrola_nienaruszenia_instalacji.json`) | 0 zmienionych, 0 nowych, 0 usuniętych |

## 7. Pierwszy test graficzny (`wyniki/test_graficzny/`)

* **Teren:** fragment 64×64 pól scenariusza kampanii AoC „Żołnierze dla Rzymu” (mapa 125×125; wysokości −2,45…+4,49;
  19 typów terenu, m.in. trawy, plaże, dno, klify, piaski, tereny „Mars”). Wysokości i ID terenu z kawałka 4
  (eksport Python → `cache/test_graficzny/teren.json`).
* **Tekstury:** 76 oryginalnych tekstur (19 terenów × 4 warianty) i tekstura wody wczytane **bezpośrednio z
  `data.ssa`** przez importery GDScript; 0 pól bez tekstury.
* **Model:** `models/bld_barracks_05.cem` (koszary; 386 wierzchołków, 253 trójkąty, 2 materiały) z oryginalną teksturą.
* Zrzuty (Xvfb, llvmpipe, 1280×720): `teren_archiwum.png` (warstwy domyślne), `teren_hd_nadpisania.png`
  (z luźnymi teksturami HD), `model_bld_barracks_05.png` (zbliżenie). Raporty JSON obok zrzutów (źródło każdej tekstury).
* Hipotezy użyte w teście [H]: wariant tekstury `_1.._4` z parzystości (r,c), UV 0..1 na pole, skala pionowa 1:1,
  skala modelu ×3, kolor gracza jako stały odcień.
* Widoczne braki: brak mieszania tekstur na granicach pól, klify jako płaskie pola z teksturą skały, powierzchnie
  „player color” rysowane jako czerwone płaszczyzny, orientacja części ścian modelu niezweryfikowana (rysowanie obustronne).

## 8. Bezpieczeństwo

Instalacja EE i prefiks Wine – tylko odczyt (potwierdzone ponownym audytem). Nie modyfikowano EXE/DLL, Riverlands,
Riverlands_MCP, SpaceGame, TerraHex; nie uruchamiano gry; nie tworzono Git ani Dockera; nie pobierano komercyjnych
zasobów (z sieci odczytano wyłącznie listę plików GOG z gogdb.org, publiczną dokumentację formatu CEM oraz strony informacyjne Lutris i empireearth.eu). Kod OpenEE nie
zawiera zdekompilowanego kodu gry. Pliki tymczasowe synchronizacji pozostały w `cache/_sync/` (usuwanie w podłączonym
katalogu jest zablokowane – można je bezpiecznie skasować).

## 9. Sumy kontrolne

`SUMY_SHA256.txt` – 66 plików OpenEE (bez `cache/` i `godot/.godot/`); SHA-256 tego pliku:
`b4f5ef4ebfc2ed635fdd7f7e780cc2cb3a9e649d509336b380bdbc4c2f7689b1`. Wybrane:

| Plik | SHA-256 |
|---|---|
| `audyt/manifest_zasobow.json` | `8d1a924bd18dd2874c8483351e8198827398e46797cf62a7a18aec835bf75f14` |
| `audyt/manifest_archiwow.json` | `c355e3b1cf19d0a088f7f391ccad6b6757a9822bf482c1e8ac9787bbaf2ebdbd` |
| `audyt/surowe/inwentarz_instalacji.json` | `e936c800ce072770250aa7c1a0c4d882c3ee579d03b427b5f8ea7a4f518a3ac0` |
| `wyniki/testy_godot.json` | `3a124e95ba6443ac69efa9e83b8966a7498b4ff70c966ee9d6c0a9cc8f82a0c4` |
| `Empire Earth/Data/data.ssa` (instalacja) | `17a09f43ee5e640eae593eb35a20ea0c0fb5bdbd88c578f4bb49119e5234d7e1` |

## 10. Ograniczenia

1. Brak referencyjnych sum SHA-256 dla vanilla/AoC → klasyfikacja tych warstw najwyżej „średnia”.
2. Brak manifestu komponentów instalatora społeczności → pakiety HD, filmy, cywilizacje pozostają nieustalone.
3. Brak w instalacji angielskich wersji zlokalizowanych plików i niezmodyfikowanych EXE.
4. Obiekty przypięte do pól EEMap (`n_obj>0`) i CEM 1.3 – nieodtworzone.
5. DCL w GDScript jest wolne dla dużych danych (np. 2 MB terenu) – teren w teście pochodzi z eksportu Python.
6. Renderowanie terenu EE (mieszanie, klify, woda, oświetlenie) odtworzone tylko poglądowo.

## 11. Propozycja etapu 2

1. **Referencja vanilla:** jeśli użytkownik posiada instalator offline GOG – odczyt (bez instalacji) przez
   `innoextract --list`/rozpakowanie do katalogu tymczasowego OpenEE i porównanie SHA-256 per plik i per wpis
   `data.ssa`; warstwa `vanilla` z pewnością wysoką. Wymaga zgody użytkownika.
2. **Wydajność:** DCL + SSA jako GDExtension (C++) lub cache konwersji przy pierwszym starcie.
3. **Teren w Godocie:** natywny import SCN (bez Pythona), mieszanie tekstur, klify z `dbcliffterrain`, woda,
   pełna mapa z podziałem na fragmenty, kamera RTS.
4. **Dane gry:** dekodery `dbobjects`, `dbgraphics` (skala/modele), `dbtechtree`, `dbunitset` → zasoby danych OpenEE
   oddzielone od kodu; wykorzystanie zweryfikowanych wyników `EmpireEarth test/analysis`.
5. **Modele:** animacje (klatki CEM), kolor gracza (drugi obraz SST 't'?), orientacja ścian, CEM 1.3.
6. **Mody:** format `mody/<id>/mod.json`, warstwa `user_mods`, specyfikacja API Lua (bez wdrożenia interpretera
   przed decyzją o technologii).
