# OpenEE — raport etapu 52: produkcja jednostek w Titan i strategia badawcza AoC → EE

Najważniejsze wyniki:
- **Wersja dotychczasowych pomiarów ustalona.** 121 ze 125 nagrań (etapy 29–51) powstało w EE (`Empire Earth.exe`
  e352d7ae…, kopia testowa 846350a8…), 4 w AoC. Atlas od etapu 29 opisuje więc głównie EE.
- **Produkcja jednostek rozpoznana w AoC i EE** (analiza statyczna obu kompilacji):
  - `EEMBuildUnit` to rozkaz postawienia budynku, nie produkcja;
  - produkcję wydaje komunikat „Research Technology”, a dalej działa kolejka budynku: dopisanie z opłatą, start,
    odliczanie −34 ms na takt, utworzenie jednostki.
- **Pomiar produkcji obywatela w AoC i kontrolny w EE.** Core odtwarza oba przebiegi w całości:
  - AoC 1898/1898 i 3101/3101, EE 2996/2996 próbek;
  - nowe jednostki mają czas, typ, pozycję i kurs jak w grze.
- **Pierwsze potwierdzone różnice silnika EE/AoC:**
  - pozycja kolejki produkcji ma 4 B w EE i 8 B w AoC;
  - utworzenie jednostki zużywa 3 losowania w EE i 1 w AoC;
  - przesunięcia pól gracza są inne.

  Różnicę losowań Core obsługuje jawnym, jednym parametrem wariantu.
- **`dbtechtree` odczytana:** koszt, czas, obiekt i budujący. Wartości domu i koszar z etapu 51 potwierdzone w bazie.
  Importery zasilają Core kosztem i czasem produkcji.
- **Populacja:** licznik gracza i limit (1 + a + b + globalny 100) rozpoznane i zmierzone. Liczniki +0xB0C i +0xB14 z
  etapu 51 dotyczą czego innego.
- Regresja bez zmian względem etapu 51. Rozbieżności D1–D3 i 673 pozostają otwarte.

## 1. HEAD i commit

- Początkowy HEAD: `b63886e` (etap 51, zgodny z podanym zdalnym `main` `b63886eabb66…`).
- Końcowy: jeden lokalny commit etapu 52 („Etap 52: produkcja jednostek…”). Hash podaje `git log -1`.
- Bez `push`, `pull`, `fetch`, `clone`, `reset`, `rebase` i `clean`.
- Pliki użytkownika poza zakresem bez zmian: `godot/project.godot`, pliki `.uid`, `konfiguracja/uzytkownik.cfg.przed_etapem11`.

## 2. Zmienione pliki

| Obszar | Pliki |
|---|---|
| Core | `cpp/core/include/openee/{jednostka,symulacja,wariant}.hpp`, `cpp/core/src/symulacja.cpp` |
| GDExtension | `cpp/gdextension/src/openee_symulacja.{cpp,hpp}` – wersja `0.25.0 (etap 52` |
| Testy | `cpp/tests/testy_core.cpp` (grupa `produkcja`), `cpp/tests/CMakeLists.txt`, `godot/testy/testy_gdextension.gd` |
| Importery i narzędzia | `godot/silnik/importery/epoki_db.gd`, `narzedzia/eeformaty/epoki.py` (koszt, czas, „Is object?”), `narzedzia/titan/odtworzenie_nagrania.py` (`opis_produkcji`, `porownaj_produkcje`) |
| Godot | `godot/sceny/potyczka.gd` (`demo_e52`), `godot/testy/eksperymenty/odtworz_scenariusz.gd` (`--wariant`, rozkaz `produkcja`) |
| Dane | `dane/testy_walki/{e42_warianty,parametry_jednostek_ee}.json`, `dane/titan/struktury_titan.json` (10 par funkcji), `dane/potyczka/potyczka_e52_produkcja.json` |
| Dokumentacja | nowe `docs/titan/produkcja.md`, `docs/titan/EE_AOC_POROWNANIE.md`; `docs/titan/{POSTEP_REKONSTRUKCJI,budowa,dziennik_eksperymentow,README}.md`, `docs/{HISTORIA,ARCHITEKTURA_OPENEE}.md`, `README.md`, `raporty/README.md`, `dane/launcher/aktualnosci.json`; `RAPORT_ETAP_51.md` → `raporty/archiwum/` |

## 3. Wersje i pliki wykonywalne

| Gra | Plik | SHA-256 | Pomiary |
|---|---|---|---|
| EE (GOG + NeoEE, Lutris) | `Empire Earth.exe` | `e352d7ae…a2b5` (kopia bez filmów `846350a8…`) | 121 nagrań (29–51), 679 |
| AoC (GOG + NeoEE, Lutris) | `EE-AOC.exe` | `db8fc5ce…7f52` (kopia `c636a2ab…`) | 4 nagrania (30–32), 675–679 |
| EE / AoC bez NeoEE (`Empire Earth Gold`) | `Empire Earth.exe` / `EE-AOC.exe` | `957e35d7…` / `632246d2…` | nieużywane |

Riverlands_MCP rozpoznaje grę po procesie i przypisuje adresy do kompilacji (SHA-256). Każdy wynik zadania zawiera krok
`wariant` z kompilacją. Szczegóły i statystyka: `docs/titan/EE_AOC_POROWNANIE.md` § 1.

## 4. EEMBuildUnit i mechanizm produkcji

- `EEMBuildUnit` („Build Unit”, AoC vtable 0x838AB4 / EE 0x824B40) – wykonanie AoC 0x4BBCC4:
  - fundament budynku w punkcie (+0x10, +0x14);
  - przydział zaznaczonej grupie (+0x9AC);
  - Shift (+0x1C) [W].

  To rozkaz budowy, nie produkcja.
- **„Research Technology”** (`EEMResearchTechnology`, AoC vt[10] 0x4C49B7, EE 0x4BBE02):
  - jednostka to technologia z „Is object?” = 1;
  - komunikat dopisuje pozycję do kolejki każdego zaznaczonego, ukończonego budynku;
  - dla części typów technologii trafia do budynku o najkrótszej kolejce [W].
- Kolejność (AoC = EE):
  - dopisanie z opłatą od razu;
  - start, gdy budynek jest wolny, z warunkiem populacji, czas = Build time × m;
  - odliczanie −34 ms na takt;
  - utworzenie jednostki na krawędzi budynku i od razu start następnej pozycji;
  - przy braku miejsca ponowna próba po 5000 ms [W].

## 5. Funkcje, adresy i struktury

| Funkcja / pole | AoC | EE |
|---|---|---|
| dopisanie do kolejki | 0x5F5F97 | 0x5E8908 |
| start pozycji | 0x5FDC58 | 0x5EF9FF |
| bieżąca pozycja (setter) | 0x5FEA99 | 0x5F077C |
| odliczanie / utworzenie | 0x6394CD / 0x631B55 | 0x624DF8 (utworzenie w funkcji) |
| anulowanie bieżącej / pozycji / całej kolejki | 0x5FD8F3 / 0x5FD984 / 0x5FCE47 | [N] |
| EEPlayer vt+0xB4, +0x44, +0x50, +0x54, +0x7C | 0x56B09E, 0x5628CB, 0x564223, 0x563A25, 0x56528B | 0x55BE2C, 0x5546F5, 0x555E93, 0x55574D, 0x556EBC |
| kolejka budynku | +0x48 (+0x4C/+0x50), pozycja 8 B | +0x48 (+0x4C/+0x50), pozycja 4 B |
| bieżąca / licznik ms / ukończony | +0x260 / +0x280 / +0x34C | +0x25C / +0x27C / +0x340 |
| zasoby / populacja | +0xAFC… / +0xB14 | +0xAF8… / +0xB10 |
| limit: a, b, globalny | +0xB20, +0xB24, 0x930E14 | +0xB1C, +0xB20, 0x9183D4 |

Źródła:
- adresy: RTTI (`narzedzia/titan/rtti_titan.py`), te same wzorce instrukcji w obu plikach (liniowy deasembler capstone),
  zrzut diagnostyczny pól jednostki AoC 0x5F9486 („Blg Queue Count” = +0x48, „Cit Build Que Size” = +0x68) [W];
- Ghidra (REA) zamykała sesję między wywołaniami, a ponowna analiza 12 MB trwała minuty, dlatego większość statyki
  wykonałem deasemblerem;
- pełna tabela: `docs/titan/produkcja.md` § 1.2.

Indeksy metod `EEPlayer` i komunikatów są takie same w obu grach. Indeksy klas jednostek (`EEUC*`) nie są: metoda 46
`EEUCBuilding` to różne funkcje w AoC i EE.

## 6. Pomiary kolejki, kosztów, czasu i populacji

| Przypadek | Gra | Wynik [P] |
|---|---|---|
| 1 obywatel | AoC 677, EE 679 | koszt 50 żywności w takcie kliknięcia; w tej samej próbce start z licznikiem 28000; −34 ms/takt (także w taktach 35 ms); po 824 taktach jednostka, populacja +1, bieżąca = brak |
| 2 w kolejce | AoC 677, EE 679 | drugi koszt przy drugim kliknięciu (kolejka 1); w takcie zakończenia pierwszej start drugiej z 28000 |
| miejsce wyjścia | AoC 4 jednostki, EE 2 | (X + r + k·2r; Y − r), r = 0,15; kurs −y (m01 = 0, m11 = −1); stan 5000 |
| brak zasobów | AoC 678 (`e42_e52_brak`, po 20) | odmowa, kolejka pusta, zasoby bez zmian |
| limit | AoC 678, EE 679 | globalny 100, a = b = 0 → limit 101 (panel „x/100”) |
| losowania | AoC / EE | start +1 w obu; utworzenie: AoC +1, EE +3; kliknięcie bez losowania |
| płeć obywatela | AoC / EE | AoC 1451, 1451, 1074, 1074, 1074; EE 1074, 1074 – reguła [N] |
| anulowanie | AoC 679 | klik lewy i prawy w ikonę kolejki (40, 1400) bez skutku – miejsce w interfejsie nieznalezione [N] |
| limit osiągnięty, zajęte miejsce wyjścia | – | niewykonane: limitu (100) nie da się osiągnąć w scenariuszu bez zmiany ustawień gry; zajęcie miejsca wymaga kolejnego eksperymentu |

Populacja:
- licznik gracza AoC +0xB14 / EE +0xB10 [P + W];
- składniki limitu +0xB20/+0xB24 (AoC) [W]. Wpływ domów na te pola jest niezmierzony;
- liczniki +0xB28/+0xB2C/+0xAE0 (AoC) dotyczą kategorii klas 0x1B z limitem 1 (prawdopodobnie bohaterów [H]) i przy
  obywatelach się nie zmieniają [P];
- AoC +0xB18 (EE +0xB14) rośnie przy każdej nowej jednostce i przy ukończeniu koszar. Znaczenie (liczba obiektów
  gracza?) jest nieustalone [N]. Pole „b0c” z etapu 51 to w AoC +0xB10 = 390, znaczenie [N].

## 7. dbtechtree

- Schemat EE DB Editor (`dane/schemat_db_eedbeditor/AOC/dbtechtree.dats`):
  - pola 7 Wood, 8 Stone, 10 Gold, 12 Iron, 13 Food cost, 14 Build time, 19 Object ID, 21 Is object?;
  - przesunięcia wspólne EE i AoC (pola 0–36).
- Odczyt obu baz [P]:
  - Citizen 1074 i Female Citizen 1451: 50 żywności, 28000 ms, budują 35/41/721;
  - b House 1069: 50 drewna, 40 kamienia, 35000;
  - b Barracks 1071: 225 drewna, 45000;
  - EE i AoC różnią się tylko „Ending epoch” (14/15).
- Wartości z bazy, przeliczane w kodzie i z pomiaru:
  - z bazy: koszt i czas;
  - w kodzie: czas × ulepszenie +0x94 [W]; opłata z mnożnikiem 1,0 [W];
  - z pomiaru: licznik 28000 = baza × 1,0.
- Modyfikatory cywilizacji i technologii kosztów: nieodczytane [N].
- Importery Godot i Pythona zwracają `koszt`, `czas_ms` i `czy_obiekt`. Odtworzenie i potyczka biorą koszt i czas
  produkcji z bazy. W danych zostały tylko mnożnik i koszt populacji.

## 8. Implementacja Core

- Nowe elementy:
  - `ParametryProdukcji`;
  - `rozkaz_produkcji`, `anuluj_produkcje`, `ustaw_populacje`, `populacja`, `limit_populacji`, `nowe_jednostki`;
  - kolejka i licznik w `Jednostka`;
  - `krok_produkcji` – osobny przebieg po pętli fizyki, bez osobnego zegara (34 ms takt).
- Wszystkie elementy pochodzą z rozpoznanych zasad:
  - opłata przy rozkazie, start, czas × m, odliczanie, limit populacji przy starcie, zwrot przy anulowaniu [W],
    ponowienie po 5000 ms [W];
  - miejsce wyjścia [P: 6 jednostek; reguła wolnego miejsca H].
- Wariant: `WariantTitan::losowania_utworzenia` (EE 3, AoC 1) – pierwszy przypadek z etapu 52, w którym różnica kodu
  wymaga parametru. Nie powstała osobna ogólna warstwa wariantów (rozszerzono istniejącą strukturę).
- Nieodtworzone [N/H]: wybór płci, wybór budynku o najkrótszej kolejce, limit kategorii 0x1B, punkt zbiórki,
  technologie bez obiektu.

## 9. Porównanie EE/AoC

Ten sam scenariusz logiczny (`e42_e51_zbieranie`, SCN 231), te same zasoby i rejestrator. Przesunięcia pól są osobne dla
każdej gry.

| Element | AoC | EE | Status |
|---|---|---|---|
| koszt, chwila opłaty | 50 żywności przy rozkazie | to samo | WSPÓLNY |
| czas, odliczanie | 28000, −34/takt, 824 takty | to samo | WSPÓLNY |
| kolejka, start następnej | bez przerwy | to samo | WSPÓLNY |
| miejsce i kurs nowej jednostki | (X + r + k·2r; Y − r), −y | to samo | WSPÓLNY |
| populacja, limit | +0xB14, limit 101 | +0xB10, limit 101 | WSPÓLNY (zachowanie), ZMIENIONY (przesunięcia) |
| pozycja kolejki | 8 B | 4 B | ZMIENIONY |
| losowania przy utworzeniu | 1 | 3 | ZMIENIONY |
| płeć pierwszego obywatela | 1451 | 1074 | NIEZWERYFIKOWANY (reguła [N] – nie klasyfikuję jako różnicy silnika) |

Mapowanie: 10 par funkcji w `struktury_titan.json` (kryterium, pewność, zachowanie). `struktury.py porownaj`: 14
niespójności przesunięć, z czego 8 w parach produkcji (EE tworzy jednostkę w funkcji odliczania). Macierz 38 podsystemów
i lista eksperymentów do powtórzenia: `EE_AOC_POROWNANIE.md` § 5 i § 7.

## 10. Regresja

| Zestaw | Etap 51 | Etap 52 |
|---|---|---|
| CTest Release / Debug | 21/21 / 21/21 | **22/22 / 22/22** (nowa grupa `produkcja`, 4 sprawdzenia) |
| GDExtension | 73/73 | **77/77** |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 108/108 | 108/108 |
| narzędzia Titan (`test_titan_narzedzia`) / `test_formatow` | – | 20/20 / OK |

Nagrania (pierwsza rozbieżność):

| Nagranie | Wynik |
|---|---|
| czyste (631/633/634/638k/638c), e46 (644 ×4, 646), e48 a | w całości |
| 648 | prorok 3585/3585; gwardie od 6136 (D3) |
| 649 dom1/dom3, 651 koszary | zapadanie 74215 / 79432 / 76909 |
| 652 mur_rog / dom_* / kosz_* | 75034 (D1) / gwardie 5318–6204 |
| 654 | 5 w całości; NE 42477, koszary W 50727 |
| 619 / 620 | 124254 / 109423 |
| 658_1 / 658_2 / 659 / 660 / 674 | w całości (obywatel 2650 / 2649 / 3013 / 2411 / 3803; fundament 1277 / 1269 / 1813 / 1806 / 2335) |
| 663 | A do 77216, B do 58465 (kurs) |
| 673 od t = 80000 (`--od-startu=0`) | 5069/5069 obu jednostek, zasoby/ładunek/drzewo 5069/5069; od początku – 46534 (nie przedstawiam jako zgodnego) |
| **677 jeden / dwa (AoC), 679 (EE)** | **w całości 1898/1898, 3101/3101, 2996/2996**; ruch jednostek bez rozbieżności |
| potyczka_e47 (restart) | 898 / 896 taktów (rozrzut 895–897 wcześniej – czas klatek), gruz i znacznik po 1 |
| potyczka_e50_budowa / e51_koszary | HP 500 / 1500, ukończone |

- Determinizm: dwa odtworzenia 677 identyczne.
- Kurs w próbkach nieaktualnych i rozdartych porównuje się jak w etapie 50.
- Godot: pierwsze uruchomienie dało 322/325. Trzy testy E3 porównują czytnik z lokalnym wzorcem
  `wyniki/test_scenariuszy_ee_aoc.json` (poza repozytorium). Wzorzec nadpisałem zerami, uruchamiając
  `narzedzia/test_scenariuszy_ee.py` bez ścieżki instalacji. Po odtworzeniu poleceniem z `przygotuj_dane_lokalne.sh`:
  325/325, bez zmian w kodzie i testach.
- Tolerancji i przypadków nie zmieniałem. W teście GDExtension etapu 51 tylko napis wersji akceptuje teraz „etap 5”,
  tak jak zrobiono z testem etapu 50.

## 11. Status rozbieżności z wcześniejszych etapów

| Pozycja | Status |
|---|---|
| 652 prorok – obrót końcowy (75034) | otwarte; przyczyna (przyciągnięcie przed fizyką + krok ω/2) z etapu 51, poprawka niewykonana |
| 654 NE – FaceEnemy przy π (42477) | otwarte |
| 654 koszary od W (50727) | otwarte |
| faza przeładowania gwardii (648, 652) | otwarte; nowego nagrania nie wykonano |
| kontakt z niszczonym budynkiem, RNG zapadania (649/651) | otwarte |
| 619/620 | otwarte |
| 673 – zatrzymanie w 9006 przy v ≠ 0 (46534) | otwarte |

Czas etapu poszedł na produkcję, identyfikację wersji i porównanie EE/AoC. Żadnej z tych pozycji nie usunąłem z
dokumentacji.

## 12. MCP i Godot

**Riverlands_MCP** (lokalnie, bez commitu, repozytorium bez origin):
- `ee_ekonomia.py` (obserwacyjne): `produkcja_odczyt`, czyli bieżąca pozycja, licznik, kolejka, populacja i limit.
  Przesunięcia są osobne dla AoC i EE (`PRODUKCJA`) [W + P];
- `ee_budowa.py` (sterujące):
  - `produkcja_rozkaz` – weryfikowany wybór budynku, zrzut panelu, N kliknięć przycisku, czas gry kliknięć,
    opcjonalny rejestrator przed pierwszym kliknięciem;
  - `klik_okna` – klik w piksel okna;
- identyfikacja wersji – istniejący krok `wariant` (SHA-256 kompilacji).

Do powtórzenia pomiarów potrzebne są:
- zadania `Testy_MCP/ee_zadania/675…679`;
- mapy `Testy_MCP/mapy/e42_e51_zbieranie.scn` i `e42_e52_brak.scn` (generator: `scenariusze_czyste.py <mapy> e52_brak`);
- nagrania `Testy_MCP/ee_obserwacja/e52_677_jeden`, `e52_677_dwa`, `e52_678_anuluj`, `e52_679_anuluj`, `e52_679_ee`;
- opisy `Testy_MCP/e52/opis_*.json`.

Dane gry nie trafiają do OpenEE. Wcześniejsze lokalne zmiany MCP z etapu 51 (`ee_ekonomia`, `ee_budowa`,
`ee_obserwacja`, `ee_walka`, `ee_diag`, `gra.py`) pozostają.

**Godot:**
- `potyczka_e52_produkcja.json` (`demo_e52`): Centrum Miasta produkuje Female Citizen i Citizen. Koszt i czas pochodzą
  z `dbtechtree`. Jednostki z modelem powstają w taktach 824 i 1648 na (167,15; 113,85) i (167,45; 113,85), populacja
  kończy na 3, limit 101;
- `odtworz_scenariusz.gd`: `--wariant`, produkcja z bazy, próbki produkcji;
- istniejące potyczki, budowanie i restart działają.

## 13. Mapa postępu rekonstrukcji Titan A/B/C i zgodność EE/AoC

Pełna tabela: `docs/titan/POSTEP_REKONSTRUKCJI.md` (stan po etapie 52, nowa kolumna „Dowody (wersja)”).

| Podsystem | Zmiana | Dowody |
|---|---|---|
| 18 Produkcja jednostek | 0/0/0 → **3/3/3** | EE+AoC |
| 17 Ekonomia | 2/1/1 → **3/2/2** | EE+AoC |
| 19 Technologie, epoki | A 1 → **2** | EE+AoC (bazy) |

| Wskaźnik (38 podsystemów) | Etap 51 | Etap 52 |
|---|---|---|
| A ≥ 3 / B ≥ 3 / C ≥ 3 | 19 / 18 / 16 | **21 / 19 / 17** |
| A = 0 | 6 | **5** (transport, lotnictwo, zwycięstwo/wyzwalacze, zapis gry, edytor) |
| ocena 5 | brak | brak |
| kod Core | 5348 wierszy | 5478 |

Wersja dowodów:
- dotychczasowe oceny nie zostały zmienione;
- ich dowody pochodzą prawie wyłącznie z EE. Dowody AoC mają tylko: bazy i SCN, pathfinding w zmierzonych przypadkach,
  część walki, kamerę i interfejs, ekonomię oraz produkcję;
- statusy: produkcja WSPÓLNY/ZMIENIONY, walka ZMIENIONY (przeładowanie), kolizje ZMIENIONY [W], losowość ZMIENIONY.
  Większość pozostałych podsystemów to NIEZWERYFIKOWANY.

### Postęp rekonstrukcji Titan – ile zostało do końca?

Procentu nie podaję: ani średnia ocen (A 2,26, B 2,00, C 1,89), ani liczba adresów (ok. 940) nie mierzą wielkości
silnika. Opis jakościowy:

**Rozpoznane i odtworzone:**
- symulacja pojedynczych jednostek lądowych: ruch, trasy, kolizje, stany, walka wręcz, śmierć;
- budynki jako cele i przeszkody;
- od etapów 50–52 podstawowa pętla obywatela i budynku: budowa dwóch typów budynków, zbieranie drewna, produkcja
  obywatela, zasoby, populacja i limit.

**Niebadane (A = 0):** transport, lotnictwo, warunki zwycięstwa i wyzwalacze, zapis gry, edytor.

**Prawie nietknięte (A ≤ 1):** AI komputera (ponad 120 klas `EEAI*`/`EECP*`), dyplomacja, widoczność, świat i zwierzęta,
kalamity, multiplayer.

**Wersja AoC:**
- tylko produkcja, ekonomia i część walki mają już dowody z AoC;
- ruch, kolizje, budowa i zbieranie wymagają powtórzenia pomiarów w AoC. Tę część rekonstrukcji „głównej wersji
  badawczej” trzeba w dużej mierze potwierdzić od nowa (`EE_AOC_POROWNANIE.md` § 7).

**Minimalna grywalna wersja OpenEE a pełne odtworzenie:**
- Dla pętli „zbierz → zbuduj → wyprodukuj” Core ma już wszystkie mechanizmy, ale tylko dla:
  - jednego surowca (drewno);
  - jednego budynku produkcyjnego (Centrum Miasta);
  - jednego typu jednostki (obywatel).
- Do pierwszej samodzielnej rozgrywki brakuje:
  - produkcji jednostek wojskowych w koszarach;
  - pozostałych surowców (kamień, złoto, żelazo, żywność z farm i zwierząt);
  - wpływu domów na limit populacji;
  - interfejsu budowy i produkcji w OpenEE;
  - prostego warunku zwycięstwa.
- Pełne odtworzenie wymaga ponadto:
  - technologii i epok;
  - AI komputera;
  - transportu, lotnictwa, kalamit;
  - multiplayera i zapisu gry;
  - potwierdzenia całości w AoC.

  To największa część pracy i nie ma dla niej danych o tempie.

**Największe blokery:**
- AI komputera (rozmiar);
- technologie i epoki (efekty `dbeffects` na jednostkach);
- brak pomiarów AoC dla etapów 29–51;
- niestabilna sesja Ghidry przy dużych plikach (obejście: deasembler).

## 14. Największe braki i propozycja etapu 53

1. **Produkcja w koszarach** (jednostka wojskowa): ten sam mechanizm, inny budynek i typ. Do tego anulowanie (szukanie
   miejsca w interfejsie albo skrót), zajęte miejsce wyjścia i punkt zbiórki – w AoC, z kontrolą w EE.
2. **Budowa i zbieranie w AoC:** powtórzenie 660/674/673 w AoC (wspólność wzoru 0x60BF56, punktów pracy, kosztów).
   Pierwsze przeniesienie dowodów etapów 50–51 na główną wersję.
3. **Dom a limit populacji:** pomiar +0xB20/+0xB24 (AoC) po ukończeniu domu i po jego zniszczeniu, śmierć jednostki
   (populacja −1).
4. **Budowa z bazy:** odtworzenia budowy biorą K i koszt z `dbtechtree` zamiast z `budowa_typow`.
5. Jedna z rozbieżności: D1 (obrót proroka 652) albo 673 (zatrzymanie 9006). Najpierw przyczyna w kodzie AoC i EE.
