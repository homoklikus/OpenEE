# Bazy danych db*.dat – Empire Earth 1.0 a The Art of Conquest

Etap 11 OpenEE. Dokument porównuje formaty tabel `db/*.dat` gry podstawowej (EE 1.0, archiwum
`Empire Earth/Data/data.ssa`) i dodatku (AoC, `Empire Earth - The Art of Conquest/Data/data.ssa`). Opisuje też
przyczynę błędu profilu `vanilla_ee`. Dokument zawiera wyłącznie opis struktury: rozmiary, liczby rekordów, przesunięcia
i nazwy pól ze schematu EE DB Editor (GPLv3). Zawartości rekordów gry nie publikuje.

**Oznaczenia:**
- **[P]** potwierdzone pomiarem lub jednoznaczną analizą danych;
- **[W]** wniosek z ograniczonych dowodów;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Zbadane pliki i metoda

- **Pliki:**
  - wszystkie 39 tabel `db/*.dat` z obu archiwów, w dwóch instalacjach (referencyjna – EE Gold, społecznościowa – GOG);
  - archiwa obu instalacji zawierają **identyczne** tabele (39/39 bajt w bajt dla EE i dla AoC). [P]
- **Narzędzia:**
  - wypakowanie przez `ArchiwumSSA` OpenEE do lokalnego katalogu `cache/e11/raw` (poza repozytorium);
  - dekoder kontrolny w Pythonie z układem `dane/uklad_db.json`;
  - porównanie rekordów EE i AoC o tej samej nazwie (dopasowanie przesunięć pól);
  - arytmetyka rozmiarów.
- Nie było potrzeby badania pamięci procesu gry: struktura wynika jednoznacznie z danych.

## 2. Odtworzenie błędu `vanilla_ee` (stan przed etapem 11)

Profil `vanilla_ee` (konfiguracja odseparowana: `[zrodlo] gra="referencyjna", profil="ee"`, warstwy `vanilla`),
scenariusz kampanii EE „Wojna trojańska”:

- Komunikat: `SCRIPT ERROR: Out of bounds get index '1411204' (on base: 'PackedByteArray')`.
  - Miejsce: `baza_db.gd:33` (`dekoduj`), wywołane z `zasoby.gd:322` (`tabela`) ← `test_scenariusz.gd:95` oraz
    `warianty_grafiki.gd:39`.
  - Następnie `Invalid access to property or key 'rekordy'` w `zasoby.gd:327`.
- Tabela: `db/dbobjects.dat` z archiwum EE. Rozmiar 1 410 356 B, nagłówek N = 724.
- **406 dalszych błędów** `decode_s32` (`baza_db.gd:43`): odczyty poza danymi w tym samym przebiegu.
- `EpokiDB`: „Tabele epok nieczytelne (dbeffects: długość 136000)”, więc warianty grafik wg epok są wyłączone.
- **Skutek:** `dbobjects` jest puste, a scena ma 5368 obiektów w pliku i **0 modeli**: bez jednostek i budynków.
  Epoki graczy bez nazw.
- Ten sam scenariusz w profilu `vanilla_aoc`: 0 błędów, modele i epoki poprawne.

## 3. Przyczyna [P]

Dekoder `BazaDB` ma jeden układ pól na tabelę (`dane/uklad_db.json`), wygenerowany ze schematu EE DB Editor
**dla AoC**. `EpokiDB` ma na stałe wpisane rozmiary rekordów AoC. Tabele EE 1.0 mają w czterech miejscach inny
układ, więc dekodowanie EE układem AoC wychodzi poza dane. Przy `dbobjects` dzieje się to w rekordzie 719 z 724:
1960 B na rekord zamiast 1948 B.

## 4. Porównanie struktur

### 4.1. Wspólne cechy [P]

- **Tabele z nagłówkiem:** `u32 N` + N rekordów, bez dodatkowych sekcji, wskaźników ani przesunięć.
- **Typy pól:**
  - INTEGER/LINK/ENUM/LANGUAGE – 4 B, ze znakiem, little endian;
  - FLOAT – 4 B IEEE;
  - BOOLEAN – 1 B;
  - STRING – stała długość, wypełnienie 0x00 lub 0xCC;
  - DYNAMIC_STRING – długość w polu wcześniejszym, kodowanie cp1250.
- **Tabele bez nagłówka:** `dbtechtree` (grupy z licznikiem), `dbevents` (rekordy o zmiennej długości), `dbeffects`
  (stały rekord, bez nagłówka).
- **Numeracja identyfikatorów jest wspólna.** AoC dopisuje nowe identyfikatory na końcu przestrzeni EE:
  - `dbobjects` EE ma ID 0…723, AoC 0…847; 721 obiektów o tej samej nazwie ma to samo ID;
  - `dbgraphics`: 855 z 858 rekordów EE ma w AoC to samo ID i tę samą nazwę;
  - w obu wersjach istnieją rekordy z ID −1 (nieużywane).
- **Referencje między bazami są spójne w EE.** Każde `Graphic ID` obiektu EE wskazuje istniejący rekord
  `dbgraphics` EE (0 błędnych odwołań).

### 4.2. Tabele o identycznym układzie rekordu (różna tylko liczba rekordów) [P]

Kryterium: dekodowanie układem OpenEE zużywa dane co do bajta albo ten sam stały rozmiar rekordu w obu wersjach.

- **Z układem w OpenEE:** `dbgraphics`, `dbsounds`, `dbterrain`, `dbterraintype`, `dbcliffterrain`, `dbfamily`,
  `dbunitset`, `dbmusic`, `dbbuttons`, `dbcolortable`.
- **Bez układu w OpenEE, ten sam rozmiar rekordu:** `dbambientsounds`, `dbanimals`, `dbareaeffect`, `dbcalamity`,
  `dbcpbehavior`, `dbgfxeffects`, `dbpremadecivs`, `dbstartingresources`, `dbterraingraytextures`, `dbui*`,
  `dbunitbehavior`, `dbupgrade`, `dbweapontohit`, `dbworld`, `dbaiunittargeting`, `dbgamevariant`, `dbrandommap`
  (rozmiar rekordu tej samej średniej długości).
- **`dbevents`:** ten sam format (dekoder `EpokiDB.zdarzenia` czyta obie wersje), 1500 rekordów w obu.
- **`copy of dbgamevariant.dat`:** tylko w EE (pozostałość, nieużywana przez OpenEE).

### 4.3. Tabele o różnym układzie rekordu [P]

| Tabela | EE 1.0 | AoC | Różnica |
|---|---|---|---|
| `dbobjects` | 451 pól, **1948 B** | 454 pola, 1960 B | AoC dodaje `Never used#22`, `Never used#23` (zaraz po `Unknown string#2`, przesunięcie AoC 1148–1155) oraz `Unknown#55` (ostatnie pole, 1956). |
| `dbcivilization` | 80 pól, **416 B** | 126 pól, 600 B | AoC dodaje na końcu 46 pól `Never used` (416–599). |
| `dbtechtree` | rekord **268 B** + 4 B × liczba budowniczych; 14 grup | rekord 272 B + 4 B × liczba; 15 grup | Patrz niżej. |
| `dbeffects` | **68 B** (17 pól); 2000 rekordów | 88 B (22 pola); 2000 rekordów | AoC dodaje na końcu 5 pól (17–21: `@UNKNOWN_INT4` i 4 × `@UNUSED_INT4`). |

#### Dowody dla każdej tabeli

**`dbobjects`:**
- Przy dopasowaniu 609 obiektów o tej samej nazwie pola 0–250 EE są pod tymi samymi przesunięciami co w AoC.
- Lista „Can build tech” (200 pól) w EE zgadza się z AoC przy przesunięciu −8 B: 605–609/609 zgodnych, wobec ~546 przy
  0 i −4.
- Rekord EE kończy się dokładnie na 200. wpisie listy, więc `Unknown#55` w EE nie występuje.
- W AoC oba pola `Never used#22/#23` mają w każdym z 848 rekordów wartość 0.

**`dbcivilization`:**
- 24 z 25 cywilizacji o tej samej nazwie ma identyczne pierwsze 416 B.
- Dodatkowe 184 B AoC są we wszystkich 29 rekordach identyczne (wypełnienie).

**`dbtechtree`:**
- Rekord EE o długości 268 B (liczba budowniczych pod +264) to jedyna długość z zakresu 200–300 B, przy której cały
  plik EE dzieli się co do bajta: 14 grup, 4426 rekordów.
- Mapa przesunięć z 658 par technologii o tej samej nazwie:

| Pole (schemat AoC) | AoC | EE |
|---|---|---|
| Pola 0–36 (nazwa … `@UNKNOWN_FLOAT`) | 0–243 | 0–243 |
| BOOLEAN 37, 38 (`Researchable in editor trigger`, `Only in scenario`) | 244, 245 | 244, 245 |
| BOOLEAN 39, 40 | 246, 247 | **brak** – bajty 246–247 to wypełnienie o niestałej zawartości [W] |
| `@UNUSED_INT4` (41) | 248 | **brak** |
| `Epoch number` (42) | 252 | **248** |
| `Buildings to advance epoch` (43) | 256 | **252** |
| `Epoch IDs` (44) | 260 | **256** |
| `Last build object` (45) | 264 | **260** |
| `Num of tech builders` (46) | 268 | **264** |

  Potwierdzenie: 13 rekordów epok mają w EE pod +248 kolejne numery epok (1, 3, 4…14), a pod +256 identyfikatory
  1000…14000, tak jak AoC pod +252 i +260.

**`dbeffects`:**
- 136 000 B / 2000 = 68 B.
- Przy 1042 rekordach o tym samym ID pola 0–16 EE są równe polom 0–16 AoC (1020–1042/1042). Pola 17–21 AoC nie mają
  odpowiedników.

### 4.4. Rozszerzenie czy osobne warianty? [P]

AoC **rozszerza** strukturę EE: dodaje pola, głównie na końcu rekordu (`dbcivilization`, `dbeffects`,
`dbobjects.Unknown#55`) albo w środku (`dbobjects.Never used#22/23`, `dbtechtree` 246–251), oraz dopisuje nowe
rekordy (ID) na końcu. Kolejność i znaczenie pól wspólnych się nie zmieniają. Pola dodane w AoC są w danych AoC
puste lub stałe, z wyjątkiem pól `dbtechtree` 39–40 (BOOLEAN), których znaczenia schemat nie podaje [N].

## 5. Reguły rozpoznawania wariantu

Wariant ustala się **ze struktury danych**, nie metodą prób. Każda tabela ma opis wariantów; dane muszą pasować do
**dokładnie jednego** z nich, inaczej importer zgłasza błąd z rozmiarem, liczbą rekordów i oczekiwanymi wartościami.

1. **Tabele z nagłówkiem i stałym rozmiarem rekordu:** rozmiar pliku = 4 + N × R(wariant).
   - `dbobjects`: R = 1960 (AoC) albo 1948 (EE).
   - `dbcivilization`: R = 600 (AoC) albo 416 (EE).
   - Dla N > 0 oba warunki nie mogą być spełnione jednocześnie.
2. **Tabele z łańcuchami dynamicznymi** (`dbgraphics`, `dbsounds`, `dbterrain`): jeden układ wspólny. Warunek: zużycie
   co do bajta.
3. **`dbtechtree`:** rekord 272 lub 268 B. Wariant to ten, przy którym struktura grup („i32 liczba dzieci + rekordy
   o zmiennej długości”) zużywa plik co do bajta, z zachowaniem kontroli zakresów licznika budowniczych.
4. **`dbeffects`:** rozmiar jest wielokrotnością 88 B (AoC) albo 68 B (EE). Gdyby był wielokrotnością obu, wariant
   byłby niejednoznaczny i importer zgłosi błąd.
5. **Spójność z grą** (uzupełnienie etapu 11, `docs/WARIANTY_GRY.md`): oczekiwany format wynika z definicji gry
   (`dane/gry.json`, `format_db`). Gra `aoc` czyta najpierw archiwum AoC, więc oczekiwany jest format `aoc`. Gra `ee`
   czyta tylko archiwum EE, więc oczekiwany jest format `ee`. Rozbieżność jest **błędem** w dzienniku (możliwy mod
   lub zła instalacja); przed uzupełnieniem była ostrzeżeniem.

Zabronione są: dekodowanie „jak AoC, a przy błędzie pominięcie”, zerowanie pól i dopisywanie brakujących pól do
rekordów EE. Wynik dla EE zawiera tylko pola, które EE rzeczywiście ma. Kod czytający pole tylko-AoC dostaje brak
klucza (`get(...)` z wartością domyślną), a nie fałszywe zero.

## 6. Architektura importera (propozycja wdrożona w fazie C)

- **`dane/uklad_db.json`:** pozostaje układem bazowym (AoC = nadzbiór). Nowa sekcja `warianty` opisuje dla EE pola
  nieobecne (`pomin`). Nie powstaje drugi, ręcznie przepisany układ, więc kolejność pól wspólnych nie może się
  rozjechać.
- **`BazaDB.dekoduj`:**
  - wyznacza układy wariantów z tabeli bazowej;
  - wybiera wariant wg § 5;
  - dekoduje z kontrolą zakresów każdego odczytu (bez błędów silnika przy uszkodzonych danych) i zużycia co do bajta;
  - zwraca `{"rekordy", "wariant"}` albo `{"blad"}` z opisem.
- **`EpokiDB`:** zamiast stałych rozmiarów słownik formatów wariantów (`REKORD`, przesunięcia pól po +244).
  - `techtree`: wariant ze struktury;
  - `efekty`: rekord 88 lub 68 B wg § 5.4;
  - `zdarzenia`: bez zmian.
- **`Zasoby.tabela`:** zapisuje wariant tabeli (diagnostyka i testy). Ostrzega przy niezgodności z profilem.
- **Narzędzia Python** (`narzedzia/eeformaty/db.py`, `epoki.py`): te same reguły (parzystość z importerem Godota).

## 7. Niewiadome

- Znaczenie pól dodanych w AoC (`Never used#22/23`, `Unknown#55`, `dbtechtree` BOOLEAN 39–40, `dbeffects` 17–21).
  Dla odczytu EE bez znaczenia. [N]
- Układ pól tabel, których OpenEE nie dekoduje (§ 4.2, część „bez układu”). Rozmiar rekordu w obu wersjach jest ten
  sam. [W]
- Pozostałe wersje gry (EE 1.00 bez łatek, wersje regionalne) nie zostały zbadane. [N]

## 8. Uzupełnienie etapu 11 – dwie gry

Rozszerzony audyt obu instalacji (archiwa, scenariusze, `Language.dll`, `.rmv`, biblioteki PE, pliki otwierane przez
`Empire Earth.exe` i `EE-AOC.exe`) oraz architektura dwóch gier na wspólnym silniku: **`docs/WARIANTY_GRY.md`**.
Narzędzie: `narzedzia/audyt_ee_aoc.py`.
