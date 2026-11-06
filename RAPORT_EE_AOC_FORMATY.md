# Raport etapu 11 – bazy Empire Earth 1.0 i The Art of Conquest, dwie gry na jednym silniku, wersjonowanie MCP

Data: 6 listopada 2026. Stan wyjściowy: commit `33619fa`, Godot 247/247, MCP 35/35.
Dokumenty szczegółowe: `docs/FORMATY_DB_EE_VS_AOC.md` (formaty baz), `docs/WARIANTY_GRY.md` (audyt obu gier
i architektura). Oznaczenia: [P] potwierdzone, [W] wniosek, [H] hipoteza, [N] niezbadane.
Zakres: (EE) tylko Empire Earth, (AoC) tylko The Art of Conquest, (obie), (obie?) wspólność hipotetyczna.

## 1. Przyczyna błędu `vanilla_ee` [P]

OpenEE dekodował bazy jednym układem rekordów – układem AoC. Baza EE 1.0 ma krótsze rekordy w czterech tabelach:

| tabela | EE | AoC |
|---|---|---|
| `dbobjects` | 1948 B | 1960 B |
| `dbcivilization` | 416 B | 600 B |
| `dbtechtree` | 268 B | 272 B |
| `dbeffects` | 68 B | 88 B |

Skutki: odczyt poza danymi (`Out of bounds get index 1411204` w `baza_db.gd:33`, 406 błędów `decode_s32`), puste
tabele epok („Tabele epok nieczytelne (dbeffects: długość 136000)”), zero modeli i puste nazwy epok. Profil AoC działał
poprawnie. Drugi, ukryty problem: w trybie EE `Zasoby.teksty()` domyślnie czytał `Language.dll` AoC, a pamięć podręczna
modeli i zestawów tekstur nie była czyszczona przy zmianie źródeł.

## 2. Różnice formatów

* **Bazy [P]:** 39 tabel. Układ rekordu różni się w 4 tabelach, pozostałe mają wspólny układ i różną liczbę
  rekordów. Identyfikatory EE (0–723) są podzbiorem AoC (0–847) o tym samym znaczeniu, ale wartości pól mogą być
  inne (balans). Tylko AoC: `dbcivpowers`, epoka 15.
* **Archiwa [P]:** ten sam format SSA. `data.ssa` AoC (826 wpisów) jest nakładką na `data.ssa` EE (3739 wpisów) i nie zawiera
  3614 kluczy EE. 70 wspólnych kluczy ma różną treść, m.in. 4 modele i 34 tabele.
* **Scenariusze [P]:** EE w wersji 231, AoC w wersji 250, nauka AoC w wersjach 231/248/249. Jeden parser obsługuje wszystkie.
* **`Language.dll` [P]:** EE 3398, AoC 3707 napisów (126 wspólnych ID z innym tekstem).
* **`.rmv` [P]:** AoC ⊃ EE (+39 skryptów planetarnych, 1 różny).
* **`Low-Level Engine.dll` [P]:** AoC ma 19 dodatkowych eksportów, m.in. dotyczących siatki terenu z klifami i wodą.

Szczegóły: `docs/FORMATY_DB_EE_VS_AOC.md` § 4, `docs/WARIANTY_GRY.md` § 3.

## 3. Zmiany importerów i architektury

**Formaty baz (fazy B–C):**

* `dane/uklad_db_warianty.json` – pola nieobecne w EE (`pomin`) i rozmiary rekordów.
* `BazaDB`:
  - wariant rozpoznawany ze struktury (4 + N × R) i pasujący do **dokładnie jednego** wariantu;
  - kontrola zakresu każdego odczytu;
  - czytelny błąd zamiast „spróbuj jako AoC, a przy błędzie pomiń”.
* `EpokiDB`: formaty `dbtechtree` i `dbeffects` obu wersji; niejednoznaczny rozmiar jest błędem.
* Narzędzia Python (`narzedzia/eeformaty/db.py`, `epoki.py`) działają według tych samych reguł.

**Dwie gry (uzupełnienie):**

* `dane/gry.json` + `GryEE` – definicje gier: katalogi danych w kolejności wyszukiwania, kampanie, `Language.dll`,
  format bazy, wersje SCN, warstwy bazowe, dowody z pomiaru oryginału.
* `Konfiguracja.gra` (`[gra] wariant`, argument `--gra=`):
  - gra jest niezależna od profilu (instalacja + mody) i języków;
  - pierwszeństwo wyboru zachowuje dotychczasowy wybór użytkownika ze starego klucza `[zrodlo] profil`;
  - warstwy bazowe są dopasowywane do gry.
* `Zasoby`:
  - tylko katalogi wybranej gry; w AoC katalog EE jako drugi – jawne współdzielenie zmierzone na `EE-AOC.exe`;
  - `Language.dll` i kampanie wybranej gry;
  - pamięć podręczna kluczowana grą, instalacją, warstwami i językami (`klucz_zrodel`);
  - przy zmianie czyszczone są tabele, obrazy, zestawy tekstur i modele CEM;
  - format tabeli niezgodny z grą jest błędem.
* Launcher:
  - karta **Gra** (Empire Earth / Empire Earth: The Art of Conquest);
  - profile bez pola gry;
  - migracja `vanilla_aoc`/`vanilla_ee` → `vanilla` + gra z kopią `uzytkownik.cfg.przed_etapem11`, bez usuwania kluczy;
  - w trybie testów migracja nie wykonuje żadnych operacji na plikach.
* `test_scenariusz`:
  - kampania wybierana według gry; kampania AoC w EE daje błąd, kampania EE w AoC jest jawnie współdzielona z uwagą;
  - kontrola wersji SCN;
  - licznik obiektów spoza bazy;
  - `--raport=<plik.json>`: pełny raport i wyjście; błąd wczytania kończy też render wsadowy.
* `--konfiguracja-uzytkownika=` / `OPENEE_KONFIGURACJA_UZYTKOWNIKA` – testy profili na odseparowanych konfiguracjach.

## 4. Wyniki testów obu gier

| Ścieżka | Wynik |
|---|---|
| EE: Troja („the trojan war”, EETheGreeks), `--gra=ee` | baza `ee`, 5327 obiektów (335 w oknie + 4992 poza), 0 bez modelu/grafiki, 0 spoza bazy, 84 animowane instancje (4 modele), źródła tylko z katalogu EE |
| EE: kampania AOCRoman w trybie EE | błąd „Kampania AOCRoman.ssa nie należy do gry Empire Earth” – brak cichego użycia AoC |
| AoC: „Żołnierze dla Rzymu” (AOCRoman), `--gra=aoc` | baza `aoc`, 9487 obiektów, wersja SCN 250, 0 bez modelu/grafiki, 0 spoza bazy |
| AoC: Troja (kampania EE w AoC) | 5327 obiektów, kampania oznaczona jako współdzielona (uwaga w dzienniku) |
| Przełączanie EE → AoC → EE (jedna sesja launchera, test automatyczny) | EE: 724 obiekty `ee`, źródła bez AoC, zasób tylko-AoC zgłoszony jako brak, `Language.dll` EE (3398); AoC: 848 `aoc`, zasób z AoC, `Language.dll` AoC (3707); powrót do EE bez rekordów AoC; `models/bld_barracks_06.cem` (różna treść w obu grach) każdorazowo z archiwum właściwej gry, bez starej kopii w pamięci podręcznej |
| Migracja konfiguracji (kopie plików) | kopia obecnego `uzytkownik.cfg`: dopisane `[gra] wariant="aoc"`, profil `spolecznosciowa` bez zmian; stara konfiguracja `vanilla_ee` → `vanilla` + `ee`; drugie uruchomienie czyta nowy klucz; oryginalny `uzytkownik.cfg` niezmieniony (SHA1 `428712d1…`) |
| Python `test_db.py` | 24/24 tabel (12 w każdej grze) |

## 5. Porównanie z oryginałem

* **Pliki otwierane przez oryginał** (MCP, `/proc/<pid>/fd`, `/proc/<pid>/maps`) [P]:
  - `Empire Earth.exe` – wyłącznie własny katalog; gra dochodzi do menu głównego;
  - `EE-AOC.exe` – oba archiwa `data.ssa` (AoC i EE), `Language.dll` i `Low-Level Engine.dll` tylko z AoC.
  To podstawa reguł izolacji.
* **Obiekty scenariuszy** (gra AoC, pamięć procesu vs OpenEE, faza D) [P]:
  - Troja: 5370 w pamięci / 5327 w OpenEE. Wszystkie 5327 ID odnalezione z tym samym typem i graczem, pozycja pola zgodna
    w 5296. Różnicę tworzą obiekty tworzone w trakcie gry (43, typy 223 i 327), a ruch jednostek w czasie gry przesuwa część pozycji.
  - Rzym: 9537 / 9487, 9466 wspólnych ID z typem i graczem, XY zgodne w 9455. 21 obiektów typu 370 dostało nowe ID,
    50 obiektów typu 223 powstało w trakcie gry.
  Wyniki są identyczne dla obu gier w OpenEE (te same dane scenariusza).
* **Podstawowe EE:** porównania obiektów w pamięci **nie wykonano**. Narzędzia pamięci MCP znają tylko układ `EE-AOC.exe` [N].

## 6. Testy RTX 5090 (Vulkan 1.4.357, Forward+, NVIDIA GeForce RTX 5090)

| Render | Gra | Warstwy | Błędy |
|---|---|---|---|
| `e11_gra_ee_troja` (kamera EE) | ee | vanilla | 0 |
| `e11_gra_ee_przyszlosc` – „Novaya Russia”, EETheFuture (późne epoki, wiele modeli i materiałów) | ee | vanilla | 0 |
| `e11_gra_aoc_rzym` (kamera EE) | aoc | vanilla, aoc | 0 |
| `e11_gra_ee_rts` (scena RTS: kamera, zaznaczanie, ruch) | ee | vanilla | 0 |

Wcześniejsze rendery fazy D (`e11_troja_vanilla_ee`, `e11_troja_vanilla_aoc`, `e11_rzym_vanilla_aoc`,
`e11_rts_troja_vanilla_ee`) również miały 0 błędów. Zrzuty pozostają lokalnie w `Testy_MCP/oe_render/` (nie są publikowane).

## 7. Stan MCP i wersjonowanie

* `Riverlands_MCP` nie był repozytorium i nie leży w innym repozytorium. Utworzone lokalne repozytorium (`main`),
  **bez zdalnego `origin`**, bez publikacji na GitHubie.
* Pierwszy commit `83e64d7`: 33 pliki tekstowe – kod `riverlands_mcp/*.py` (20 plików), `serwer.py`, `instaluj.sh`,
  `requirements.txt`, `README.md`, `RAPORT_ROZBUDOWA_EE_MCP.md`, `konfiguracja.przyklad.json`, `.gitignore`, testy
  (6 plików).
* Poza historią (`.gitignore`): `.venv` (145 MB), `__pycache__`, 28 paczek wdrożeniowych `*.tgz`, `konfiguracja.json`,
  wyniki, dzienniki, zrzuty, zapisy pamięci i pliki gry.
* Przegląd przed commitem:
  - brak poświadczeń i tokenów;
  - brak danych gry i zrzutów;
  - ścieżki lokalne użytkownika: domyślna `_GRA_PREFIX` w `konfiguracja.py`, przykład w README i
    `konfiguracja.przyklad.json` – zostawione, bo repozytorium jest lokalne, a ich zmiana zmieniłaby działanie
    klienta; do usunięcia przed ewentualną publikacją;
  - brak pliku licencji – decyzja należy do użytkownika.
* Zgodność:
  - Claude widzi narzędzia (przeładowanie serwera i zadania 164–165 działały po zmianach);
  - konfiguracja klienta MCP i ścieżki lokalne bez zmian;
  - wyniki testów w `Testy_MCP` nietknięte;
  - MCP nie zostało przeniesione do repozytorium OpenEE.
* Nowe w MCP (etap 11):
  - `riverlands_mcp/ee_wariant.py` – kroki zadań `uruchom_ee_podstawowe`, `pliki_otwarte` (tylko odczyt),
    `zamknij_ee_podstawowe` (wyłącznie własna grupa procesów);
  - testy `testy/test_ee_wariant.py`.

## 8. Liczby testów

| Zestaw | Przed | Po | Pominięte |
|---|---|---|---|
| Godot (`testy/uruchom_testy.gd`) | 247 | **297 zaliczonych / 297** | 0 |
| MCP (`python3 -m unittest discover -s testy`) | 35 | **40 zaliczonych / 40** | 0 |
| Python `narzedzia/test_db.py` (obie gry) | – | 24/24 tabel | 0 |

Nowy zestaw Godot `testy/testy_gier_ee_aoc.gd` (50 testów):

* formaty syntetyczne:
  - rozmiary rekordów;
  - przesunięcia pól za polami usuniętymi w EE;
  - baza EE czytana układem AoC → błąd (regresja `vanilla_ee`);
  - ten sam rozmiar pliku rozstrzygany licznikiem N;
  - rozmiar nieznany, ucięty, zły licznik i za krótki nagłówek → błąd;
  - `dbcivilization`, `dbtechtree` 268/272, `dbeffects` 68/88 i niejednoznaczne 1496 B;
* definicje gier i pierwszeństwo konfiguracji;
* migracja profili;
* dane rzeczywiste obu gier: formaty, liczności, powiązania `Graphic ID` → `dbgraphics`, epoki, `Language.dll`, kampanie;
* przełączanie EE → AoC → EE.

Testy wymagające instalacji pomijają się jawnie (`_pomin`) i nie są liczone jako zaliczone.

## 9. Znane ograniczenia

* Podstawowe EE zbadano na poziomie procesu (pliki, menu) – bez porównania obiektów w pamięci [N].
* Kamera, ruch grupowy, przezroczystość budynków i renderer terenu są zmierzone w AoC. Dla EE ich wspólność jest
  hipotezą (obie?) [H] – szczególnie teren (dodatkowe funkcje siatki w `Low-Level Engine.dll` AoC) i ruch (inne
  wartości pól ruchu w `dbobjects`).
* Pierwszeństwo archiwum AoC przed EE w AoC to wniosek z zawartości pamięci [W], nie ze śledzenia odczytów.
* Wczytywanie scenariuszy w wersji 250 w podstawowym EE – niesprawdzone [H]. OpenEE zgłasza błąd wersji, ale nie
  przerywa wczytywania.
* Launcher: karta gry sprawdzona testami modelu i budowy sceny – bez oceny wizualnej (brak renderu sceny launchera w MCP).
* Generator map: wybór katalogu `.rmv` według gry nie jest jeszcze podłączony (poza zakresem etapu 11).
* Znaczenie pól tylko-AoC (`Never used#22/23`, `Unknown#55`, końcowe pola `dbcivilization`, `dbeffects` 17–21) [N].
* Błędy MultiMesh „Cannot set a buffer…” w trybie headless (`przezroczystosc_budynkow.gd:101`) występują od etapu 8,
  w obu grach, tylko bez GPU.

## 10. Stan git i publikacja

* **OpenEE:** commity etapu 11 na gałęzi `main` po `33619fa` (lista: `git log --oneline 33619fa..`). Lokalna zmiana
  `godot/project.godot` (dodatek Godot MCP) **nie** jest w żadnym commicie. Katalog `godot/addons/godot_mcp/` jest
  wykluczony w `.git/info/exclude`.
* Publikacja wymaga poświadczeń na urządzeniu użytkownika:

  ```
  cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
  git log --oneline origin/main..main     # przegląd
  git push origin main
  ```

* **Riverlands_MCP:** tylko lokalnie (`83e64d7` + commit dokumentacji etapu 11). Zdalne repozytorium dopiero po decyzji
  użytkownika (`git remote add origin …`). Przed publikacją usunąć ścieżki lokalne (§ 7) i wybrać licencję.
* Nie wykonano `push --force`, `reset --hard` ani innych operacji przepisujących historię.
