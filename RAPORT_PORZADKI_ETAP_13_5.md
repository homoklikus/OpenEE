# OpenEE – raport etapu 13.5: porządkowanie projektu przed dalszą rekonstrukcją silnika Titan

Etap techniczny: audyt, usunięcie martwego kodu, uporządkowanie katalogów i dokumentacji. Nie dodano nowych mechanik
gry, nie zmieniono algorytmów ruchu, kamery, wyszukiwania tras ani renderowania.

## 1. Stan przed porządkowaniem

| | OpenEE | Riverlands_MCP |
|---|---|---|
| Commit | `61fe318` (`main`) | `69cf113` (lokalne repozytorium, bez `origin`) |
| Testy | Godot 322/322 | 64/64 |
| Zmiany lokalne | `godot/project.godot` (wtyczka Godot MCP) – nie ruszana; nieśledzony `konfiguracja/uzytkownik.cfg.przed_etapem11` (kopia z migracji etapu 11) – pozostawiony | brak |
| Pliki tymczasowe | 7 paczek synchronizacji `cache/oe7_*.tgz` (ignorowane) | 72 paczki wdrożeniowe `mcp_*.tgz` (ignorowane) |
| Rozmiar | 295 plików w repozytorium; lokalnie `wyniki/` 895 MB, `cache/` 193 MB (poza repozytorium) | 31 modułów, ok. 8400 linii |

## 2. Najważniejsze wykryte problemy

**OpenEE:**
1. `narzedzia/` był płaskim katalogiem z 38 plikami. Biblioteka formatów i narzędzia danych lokalnych leżały obok
   jednorazowych analiz z etapów 1–13 (ok. 15 skryptów). Trzy skrypty nie miały żadnego odwołania.
2. `uruchom_openee.sh rts` przekazywał tytuł `--scenariusz=trojan war`. W polskiej instalacji tytuł brzmi
   „Wojna Trojańska”, więc filtr nie pasował; to ten sam problem językowy, który etap 13 usunął w scenach. Opis trybu
   `scenariusz` podawał nieaktualny domyślny scenariusz.
3. Martwy kod: `test_scenariusz.gd: _mnoz` (prywatna, nieużywana) i `SekwencjeAnimacji.z_wartosci` (pomocnik
   „dla testów”, którego żaden test nie wywołuje).
4. Powtórzony test: E12 „tempo czasu gry EE = AoC” sprawdzał podzbiór warunków testu E13 „MNOZNIK_PREDKOSCI = tempo
   zegara gry”.
5. Dokumentacja:
   - `README` miał nieaktualne liczby i ograniczenia (150 testów, „brak formacji i zaznaczania grupowego”);
   - `HISTORIA` nie obejmowała etapów 6–10 i 13;
   - `MAPA_DROGOWA` wymieniała jako przyszłe rzeczy zrobione w etapach 6–13;
   - `ARCHITEKTURA.md` pokazywała strukturę z etapów 1–5;
   - wnioski obalone w etapie 13 (mnożnik 1,706, prędkość proroka, niejasne unikanie w EE) nie miały adnotacji
     w raportach etapów 5, 9 i 12 ani w `FORMATY_ETAP5.md`.
6. Architektura, do późniejszej przebudowy (§ 7): `silnik/symulacja/` łączy symulację, wejście i prezentację;
   kamera produkcyjna leży w `sceny/`; kilka bardzo dużych plików.

**Riverlands_MCP:**
1. **Błąd kolejki zadań.** Każde zadanie dostawało wątek czekający na wspólną blokadę, a `threading.Lock` nie
   gwarantuje kolejności. Zadania mogły się wykonać w innej kolejności niż numery. W wynikach tego nie zaobserwowano,
   ale przy zadaniu z kopią scenariusza i osobnym zadaniu sprzątającym groziło to złym stanem gry.
2. Zdublowany start i zamknięcie EE: kroki `uruchom_ee_podstawowe` / `zamknij_ee_podstawowe` (etap 11, ostatnio
   zad. 165) z własną sesją procesu. Od etapu 12 obie gry uruchamia ee_api. Nazwa exe EE była też zdefiniowana
   drugi raz poza `ee_warianty`.
3. Brak narzędzia do sprzątania po przerwanych testach. W etapie 13 pozostawiona kopia scenariusza zablokowała kilka
   zadań, bo „Wczytaj” bierze pierwszy plik alfabetycznie.
4. Kruchy test `test_ee_wariant`: zależał od atrap ładowanych przez inne testy i przy innej kolejności lub braku
   pakietów (`.venv` w VM bez numpy/PIL) zgłaszał błąd.

## 3. Usunięte duplikaty i nieużywane elementy

| Element | Powód | Weryfikacja przed usunięciem |
|---|---|---|
| `godot/sceny/test_scenariusz.gd: _mnoz()` | nieużywana | brak odwołań w GDScript, scenach i MCP |
| `SekwencjeAnimacji.z_wartosci()` | nieużywana | jw. (w tym testy) |
| test E12 „tempo czasu gry takie samo w EE i AoC” | warunek zawarty w teście E13 | porównanie warunków; w kodzie zostawiony komentarz ze wskazaniem testu E13 |
| MCP: kroki `uruchom_ee_podstawowe`, `zamknij_ee_podstawowe` i funkcje `ee_wariant.uruchom_podstawowe`, `zamknij_podstawowe`, `_katalog_ee`, `_cwd`, `_SESJA`, `EXE_EE` | zastąpione w etapie 12 przez `uruchom(wariant=…)`, `start_testowy`, `zamknij` | historia zadań (ostatnie użycie: zad. 165); `zamknij` działał z EE w całym etapie 13; zadanie 351 – start i zamknięcie obu gier po zmianie |
| MCP: 3 testy usuniętych kroków | testowały usuniętą funkcję | – |
| `cache/oe7_*.tgz` (7), `Riverlands_MCP/mcp_*.tgz` (72) | paczki synchronizacji z sesji, ignorowane przez git | zawartość jest w historii git; drzewa robocze bez zmian (`git status`) |

Bez usuwania zostały funkcje publiczne bez odwołań: `Symulacja.rozkaz_stop`, `usun_jednostke`,
`Zdarzenia.emituj_lokalne`, `ImporterDzwiekow.info_wav`. To API przyszłych systemów, a nie pozostałości.

## 4. Zmiany strukturalne

- **`narzedzia/eksperymenty/`** – przeniesiono tam 15 jednorazowych analiz, które pozwalają odtworzyć pomiary:
  - diagnostyka modeli 0.5.1;
  - izolowana sesja Wine z etapu 5;
  - warianty epok;
  - scenariusze testowe ruchu i kolizji;
  - analiza trajektorii;
  - audyt EE/AoC;
  - sondy czytników.

  Ścieżki importu dopasowano (dostęp do `narzedzia/eeformaty` i do skryptów obok siebie), a odwołania w 18 plikach
  dokumentacji i kodu (komentarze, komunikaty) zaktualizowano. W `narzedzia/` zostały narzędzia używane regularnie:
  `eeformaty`, skrypty `przygotuj_dane_lokalne.sh`, wzorce testów porównawczych, testy wizualne GPU oraz
  `analiza_animacji.py` i `klasyfikuj_warstwy*.py` (wykorzystywane przez dane lokalne i testy E2).
  Opis z kategoriami: **`narzedzia/README.md`**.
- **`narzedzia/eeformaty/` celowo pozostaje** w miejscu, bo Riverlands_MCP importuje go z tej ścieżki.
- `uruchom_openee.sh`:
  - tryb `rts` bez tytułu scenariusza (domyślna kampania gry, numer z listy);
  - tryb `scenariusz` przekazuje argumenty (`--gra=`, `--scenariusz-nr=`).
- MCP:
  - **kolejka zadań w kolejności numerów** (`ee_blokada.KOLEJKA`, sortowanie liczbowe: 29 przed 299). Pliki `.w_toku`
    po awarii serwera nie blokują kolejki, a zadanie z usuniętym plikiem zwalnia kolejkę;
  - **krok `sprzataj_scenariusze`**: kopie `000_EETEST_*` w folderze bieżącej gry, przez istniejące zabezpieczenia
    usuwania (rejestr, SHA-256, bez wzorców i dowiązań); pliki obce i zmienione tylko zgłasza, podgląd bez usuwania;
  - nazwy exe w `ee_wariant.pliki_otwarte` z `ee_warianty.WARIANTY` (jedno źródło definicji gier).

Formaty pozostałych wywołań MCP są bez zmian.

## 5. Elementy celowo zachowane

- Sceny diagnostyczne (`diag_modelu`, `diag_animacji`, `diagnostyka`, `test_teren`) i kamera diagnostyczna. Używają
  ich launcher, `uruchom_openee.sh`, `oe_render` i testy.
- `godot/narzedzia/*.gd` – narzędzia wiersza poleceń, opisane w `narzedzia/README.md`.
- Jednorazowe skrypty Pythona – przeniesione, a nie usunięte (kategoria „do odtworzenia pomiarów”).
- Raporty etapów w katalogu głównym. Inne dokumenty i komentarze w kodzie oraz w MCP odwołują się do nich po nazwie;
  przeniesienie dałoby dużo zmian i niewiele zysku. Indeks raportów jest w `docs/ARCHITEKTURA_OPENEE.md` § 9.
- MCP:
  - `ee_async` (`test_start`…) i narzędzia `kam_*` z etapów 7–8 – udostępnione jako narzędzia MCP;
  - `profil_zapisz`;
  - kopia exe bez intra i pomijanie przerywników przez Esc – bez zmian.
- Pomocnik `_json` w `launcher.gd` i `uruchom_testy.gd` (5 linii, dwa miejsca) – wspólna abstrakcja nie jest
  potrzebna.
- `konfiguracja/uzytkownik.cfg.przed_etapem11` (nieśledzona kopia użytkownika) i lokalna zmiana
  `godot/project.godot` – nie ruszane.

## 6. Zaktualizowana dokumentacja

| Dokument | Zmiana |
|---|---|
| **`docs/ARCHITEKTURA_OPENEE.md`** (nowy) | dokument orientacyjny: moduły, punkty wejścia, przepływ danych EE/AoC, podsystemy, podział Godot ↔ MCP, mechaniki rozpoznane i nierozpoznane, znane problemy architektoniczne, indeks dokumentów |
| **`docs/titan/README.md`** (nowy) | zasady atlasu funkcji Titan: warianty exe z SHA-256, szablon wpisu (adresy EE/AoC, przeznaczenie, wejścia i wyjścia, struktury, zależności, algorytm, pewność, weryfikacja, odpowiednik w OpenEE), już ustalone miejsca w kodzie; bez pustych dokumentów podsystemów |
| **`narzedzia/README.md`** (nowy) | kategorie narzędzi i kto z nich korzysta |
| `README.md` | stan funkcji (dwie gry, mechaniki etapów 6–13, 321 testów), ograniczenia ruchu, odsyłacze |
| `docs/ARCHITEKTURA.md` | adnotacja: dokument historyczny, aktualny opis w `ARCHITEKTURA_OPENEE.md` |
| `docs/HISTORIA.md` | etapy 6–10, 13 i 13.5; lista hipotez obalonych w etapach 6–13 |
| `docs/MAPA_DROGOWA.md` | „Zrobione w etapach 6–13”; „Najbliżej” bez pozycji już zrobionych |
| `RAPORT_ETAP_5.md`, `RAPORT_RUCH_GRUPOWY_EE.md`, `RAPORT_ETAP_12_EE_AOC.md`, `docs/FORMATY_ETAP5.md`, `docs/MECHANIKA_RUCHU_EE.md`, `docs/POROWNANIE_MECHANIK_EE_AOC.md` | adnotacje **„[Etap 13.5 – zastąpione]”** przy wnioskach obalonych lub uzupełnionych: 1,706, prorok 0,853/0,96, brak unikania i formacji, `Speed` jako pola/s; pierwotne obserwacje pozostały |
| MCP `README.md`, `RAPORT_ROZBUDOWA_EE_MCP.md` § 19 | kolejka, sprzątanie, usunięte kroki, wyniki audytu MCP |

## 7. Problemy odłożone na później

1. **Podział `silnik/symulacja/`** na symulację (`Symulacja`, `JednostkaSym`, `MapaNawigacji`, `Sciezki`, `PolitykaRuchu`,
   `FormacjaEE`, `ZegarSymulacji`, `UkladEE`), wejście (`SterowanieRTS`, `Zaznaczanie`, `ZaznaczenieEE`) i prezentację
   (`WidokJednostek`, `WariantyGrafiki`). Wymaga zmian ścieżek w scenach, testach i nazwach plików `.uid`; warto to
   zrobić przy budowie interfejsu gry.
2. **`sceny/kamera_rts.gd` → `silnik/kamera/`** (kod produkcyjny w katalogu scen; 5 odwołań `load()`).
3. **Duże pliki:** `launcher/launcher.gd` (1363 linie), `sceny/test_scenariusz.gd` (ok. 700), MCP `ee_api.py`
   (ok. 1580). Podział przy najbliższej większej zmianie tych plików.
4. **Testy etapowe** (`testy_etapu4/5/12/13.gd`) grupują testy według etapu; nowe testy lepiej dopisywać do plików
   podsystemów. Pliki pomocnicze testów (budowa mapy i jednostki) powtarzają się w kilku plikach testów.
5. Komunikat silnika w logu testów: „Cannot set a buffer on a Multimesh that is a different size…” oraz „1 resources
   still in use at exit”. Występował już przed porządkami, wyniku testów nie zmienia; źródła nie szukano.
6. MCP: brak sposobu przerwania **trwającego** zadania z zewnątrz; czekające zadania wstrzymuje się zmianą nazwy pliku.
7. MCP: gra uruchomiona z katalogu testowego (dowiązania do instalacji) zapisuje `0_Error.log` i profile w `Users/`
   instalacji, tak samo jak przy zwykłym starcie. Plików gry nie zmienia.
8. MCP w środowisku VM: `.venv` nie ma numpy i Pillow; testy MCP uruchamia się tam systemowym `python3`.
9. `godot/narzedzia/obiekty_scenariusza.gd` wybiera scenariusz tytułem (`--scenariusz=`). To narzędzie diagnostyczne;
   w polskiej instalacji trzeba podać polski tytuł albo `--plik-scn=`.

## 8. Wyniki testów

**Testy automatyczne:**

| Zestaw | Przed | Po | Uwagi |
|---|---|---|---|
| Godot (`--headless`, `res://testy/uruchom_testy.gd`) | 322/322 | **321/321**, 0 pominiętych | −1: usunięty powtórzony test E12 (§ 3) |
| MCP (`python3 -m unittest discover -s testy`) | 64/64 | **64/64** | −3 testy usuniętych kroków, +3: sprzątanie kopii, kolejność zadań, zwolnienie kolejki |
| `git diff --check` | – | czysto w obu repozytoriach (od stanu wyjściowego) | – |
| Ścieżki `res://` i UID | – | bez brakujących ścieżek; brak osieroconych i zdublowanych `.uid`; każdy `.gd` ma `.uid`; import Godota bez błędów | sprawdzone skryptem |

**Integracja – RTX 5090** (`oe_render`, Vulkan Forward+, „NVIDIA GeForce RTX 5090”), 0 błędów w logu w każdej scenie:

| Scena | Argumenty | Wynik |
|---|---|---|
| `rts_test` | `--kamera=blisko` (jak `uruchom_openee.sh rts` po zmianie) | „Wojna trojańska”, 85 jednostek |
| `rts_test` | `--gra=aoc` | „Żołnierze dla Rzymu”, 11 jednostek |
| `test_scenariusz` | brak | „Wojna trojańska”, 335 obiektów |
| `diag_modelu` | `--model=Stable - Copper` | 364 trójkąty, oba materiały |
| `diag_animacji` | `--model=Phalanx --sekwencja=atak` | sekwencje z `dbgraphics` |
| `test_teren` | brak | fragment kampanii AoC |

**Oryginalne gry** – kod ich obsługi zmieniono, więc kontrola była konieczna:
- zad. 350/351 – zadania wykonane w kolejności numerów;
- `sprzataj_scenariusze` w trybie podglądu w EE i AoC – katalogi czyste;
- `start_testowy` EE: menu po 23,5 s, z kopii bez intra, proces nie otwiera plików `.bik`;
- `start_testowy` AoC: menu po 23,4 s;
- zamknięcie obu gier poprawne.

Eksperymentów z etapów 9–13 nie powtarzano, bo kod pomiarów (`ee_czas`, `ee_kolizje`, `ee_ruch`, `ee_kamera`) nie
zmienił się.

Przeniesione skrypty: wszystkie się kompilują i importują bez błędów. Na danych uruchomiono `scenariusz_testowy_kolizji.py
zbadaj` i `analiza_ruchu_ee.py`.

## 9. Commity

**OpenEE** (`main`, lokalnie; autor homoklikus; `godot/project.godot` poza commitami):

| Commit | Opis |
|---|---|
| `4f7b47b` | jednorazowe analizy do `narzedzia/eksperymenty` (ścieżki importu i odwołania), `narzedzia/README.md` |
| `3fbc96a` | usunięcie nieużywanych funkcji i powtórzonego testu |
| `2e56c70` | `uruchom_openee.sh`: scena RTS bez tytułu scenariusza, argumenty trybu scenariusz |
| `3e14afa` | `docs/ARCHITEKTURA_OPENEE.md` i `docs/titan/README.md` |
| `2494a36` | README, historia, mapa drogowa, adnotacje przy zastąpionych wnioskach |
| (ten raport) | `RAPORT_PORZADKI_ETAP_13_5.md` |

Publikacja z komputera użytkownika (sesja nie ma poświadczeń GitHub):
```
cd "/media/precell/Inne/Projekty AI/EE Projekt/OpenEE"
git push origin main
```

**Riverlands_MCP** (lokalne, bez `origin`, niepublikowane):

| Commit | Opis |
|---|---|
| `54082f7` | kolejka zadań w kolejności numerów, krok `sprzataj_scenariusze` |
| `732e031` | usunięcie kroków zastąpionych w etapie 12, dokumentacja (§ 19) |
| `0dedd38` | test `ee_wariant` niezależny od atrap innych testów (oraz brakująca końcowa linia w `ee_wariant.py`) |

## 10. Gotowość do dalszego reverse engineeringu

Projekt jest gotowy na kolejne etapy:

1. **Orientacja bez czytania 13 raportów.** `docs/ARCHITEKTURA_OPENEE.md` podaje aktualny stan, a dokumenty
   mechanik zawierają poprawione wartości i adnotacje przy obalonych wnioskach.
2. **Miejsce i forma analiz kodu.** `docs/titan/README.md` określa szablon wpisu z wariantem exe i SHA-256 obu gier
   oraz zbiera już znane adresy.
3. **Narzędzia pomiarowe działają i są opisane:**
   - MCP – start bez intra, przerywniki, zegar gry, trajektorie, kolizje, sprzątanie, uporządkowana kolejka zadań;
   - skrypty scenariuszy testowych w `narzedzia/eksperymenty/`.
4. **Podstawowe sceny działają w obu grach na RTX 5090**, testy przechodzą.

Największe ryzyko przy rozbudowie to struktura `silnik/symulacja/` (§ 7.1). Przed dodaniem interfejsu gry i walki
warto ją podzielić w osobnym, krótkim etapie.
