# OpenEE – architektura

> **Etap 13.5:** aktualny opis modułów, przepływu danych i stanu wiedzy zawiera `docs/ARCHITEKTURA_OPENEE.md`.
> Ten dokument zachowuje zasady i opisy dopisywane w etapach 1–11; struktura katalogów niżej odpowiada etapom 1–5
> (od tamtej pory doszły m.in. `silnik/kamera/`, `silnik/render/przezroczystosc_budynkow.gd`, `silnik/diagnostyka/`,
> `narzedzia/eksperymenty/`), a renderer scen podglądu to GL Compatibility z możliwością uruchomienia na Vulkanie.

## Struktura repozytorium
```
godot/                 projekt Godot 4.7 (otwórz ten katalog w edytorze)
  silnik/rdzen/        Konfiguracja, Dziennik, Zdarzenia (autoload)
  silnik/zasoby/       Zasoby – warstwy i źródła zasobów, wyszukiwanie plików w instalacjach (autoload)
  silnik/importery/    SSA, DCL, SST/TGA, CEM, db, SCN, Language.dll, WAV/MP3
  silnik/render/       TerenEE – teren wg reguł silnika EE (z animacją wody)
  silnik/animacja/     SekwencjeAnimacji (dbgraphics), AnimacjaVAT (klatki w teksturze), OdtwarzaczAnimacji
  silnik/symulacja/    Symulacja, JednostkaSym, MapaNawigacji, PolitykaRuchu, Sciezki (A*), ZegarSymulacji,
                       Zaznaczanie, WidokJednostek, SterowanieRTS, UkladEE
  silnik/api/          zalążek API modów
  sceny/               sceny podglądu: scenariusz, teren, diagnostyka; kamera RTS
  launcher/            launcher (UI, model, motyw, ikony, teksty PL/EN)
  testy/               testy automatyczne (headless)
narzedzia/             narzędzia Python (+ C): czytniki formatów, audyt instalacji, testy porównawcze, dane lokalne
dane/                  własne dane projektu: gramatyka rekordu jednostki, warstwy, launcher, schemat tabel (GPLv3)
docs/                  dokumentacja
konfiguracja/          openee.cfg (szablon); uzytkownik.cfg – lokalnie, niepublikowany
cache/ wyniki/ audyt/  dane lokalne z instalacji użytkownika – niepublikowane (.gitignore)
```


## 1. Zasady
1. Oryginalna instalacja EE jest **tylko czytana** (tryb `rb` / `FileAccess.READ`). OpenEE nie zapisuje,
   nie przenosi i nie „naprawia” jej plików.
2. Wersje pośrednie (PNG, JSON, przyszłe zasoby Godota) trafiają do `OpenEE/cache/` i mogą zostać w każdej chwili
   odtworzone. Cache nie jest przeznaczony do rozpowszechniania (zawiera pochodne zasobów komercyjnych).
3. Dane gry (jednostki, budynki, technologie, tereny) są **danymi**, nie kodem – silnik je wczytuje (dziś z
   `db/*.dat` EE, w przyszłości także z plików modów).
4. Wyraźny podział: *symulacja* (deterministyczna) ↔ *prezentacja/lokalne* (UI, dźwięk, kamera).

## 2. Układ katalogów
```
OpenEE/
  godot/                 projekt Godot 4.7 (GL Compatibility)
    silnik/rdzen/        Dziennik (logi), Konfiguracja, Zdarzenia (kanały SYM/LOK)
    silnik/zasoby/       Zasoby – warstwy + VFS (luźne pliki + archiwa SSA)
    silnik/importery/    ImporterEE (interfejs), DCL, ArchiwumSSA, ImporterTekstur, ImporterModeli
    silnik/api/          ApiModow – projekt API (bez interpretera)
    sceny/               diagnostyka (start), test_teren (test graficzny)
    testy/               uruchom_testy.gd – testy bez okna
  narzedzia/             referencyjne czytniki Python (eeformaty) + audyt/klasyfikacja/eksport
  konfiguracja/openee.cfg
  dane/warstwy.json      definicje warstw
  audyt/                 inwentarz, manifesty, referencje (GOG), surowe dowody
  cache/                 wersje pośrednie (odtwarzalne)
  wyniki/                wyniki testów, zrzuty
  docs/                  dokumentacja
```

## 3. System zasobów i warstw
* **Warstwy**: `vanilla`, `aoc`, `localization`, `neoee`, `drexmod`, `user_mods` oraz pseudo-warstwy
  `nieustalone` i `nieustalone_nadpisania` (dopóki pochodzenia nie da się udowodnić).
* Każdy plik instalacji ma warstwę z manifestu audytu (`audyt/manifest_zasobow.json`, dowody D-xx).
* **Profil** (`aoc` / `ee`) wyznacza kolejność źródeł: luźne AoC → data.ssa AoC → luźne EE → data.ssa EE.
* `Zasoby.znajdz(klucz)` zwraca dane z pierwszego źródła, którego warstwa jest aktywna, wraz z informacją
  o źródle i warstwie (do diagnostyki). Zmiana zestawu warstw = `Konfiguracja.aktywne_warstwy` + `przebuduj_zrodla()`.
* Granulacja: warstwa przypisana do **pliku instalacji** (archiwum jako całość albo plik luźny). Wpisy wewnątrz
  `data.ssa` EE nie mają osobnego pochodzenia (brak referencji) – patrz RAPORT_SEPARACJI_WARSTW.md.
* `user_mods` (etap kolejny): `OpenEE/mody/<id>/mod.json` (id, wersja, zależności, priorytet, kontekst skryptów)
  + katalog `dane/` o strukturze jak `Data/` EE – rozwiązywany przed warstwami bazowymi.

## 4. Importery
* Interfejs `ImporterEE`: `nazwa()`, `rozszerzenia()`, `importuj(bajty, kontekst) -> Variant`.
  Importer nie otwiera plików – dostaje bajty od `Zasoby` (już rozpakowane z PK01), zależności (np. tekstury
  modelu) pobiera przez `kontekst.zasoby`. Bezstanowy → możliwy w wątkach roboczych.
* Zaimplementowane: tekstury SST/TGA → `Image`; modele CEM 2.0 → `ArrayMesh` (LOD0, klatka 0).
* Planowane: teren SCN (dziś przez eksport Python → JSON), `db/*.dat` → zasoby danych, animacje CEM (klatki),
  dźwięki WAV/MP3, interfejs (`dbui*`), filmy BIK (poza zakresem – brak otwartego dekodera w Godocie).
* Python (`narzedzia/eeformaty`) pełni rolę implementacji referencyjnej: testy porównują wyniki bajt w bajt.
* Wydajność: DCL w GDScript ~15 ms/teksturę (76 tekstur: 1,1 s). Dla pełnych map i wszystkich zasobów przewidziane
  przeniesienie DCL/SSA do GDExtension (C++) albo prekonwersja do cache przy pierwszym uruchomieniu.

## 5. Zdarzenia i determinizm
* `Zdarzenia.kolejkuj_symulacyjne(tick, nazwa, dane)` + `przetworz_tick(tick)` – kolejność (tick, sekwencja),
  test potwierdza deterministyczne uporządkowanie.
* `Zdarzenia.emituj_lokalne()` – sygnał natychmiastowy, bez wpływu na symulację.
* Docelowo: stały krok symulacji, liczby stałoprzecinkowe lub ściśle kontrolowane float w logice, RNG symulacji
  z ziarnem, wejście graczy jako zdarzenia symulacyjne (lockstep).

## 6. Przyszłe API moderskie (Lua)
`silnik/api/api_modow.gd` zawiera listę planowanych punktów wejścia z przypisaniem do kontekstu (SYM/LOK).
Interpreter nie jest implementowany w etapie 1. Wymagania na przyszłość: piaskownica (brak I/O, brak czasu
rzeczywistego w SYM), osobne maszyny Lua dla SYM i LOK, wersjonowanie API, dane modów ładowane przez warstwę `user_mods`.

## 7. Diagnostyka
`Dziennik` – poziomy DEBUG/INFO/UWAGA/BŁĄD, plik `user://logi/openee_<data>.log`, bufor dla ekranu diagnostyki.
Ekran startowy pokazuje instalację, aktywne warstwy, źródła i ostatnie wpisy dziennika.

## Etap 2 – źródła i kolejność rozwiązywania zasobów
* `Konfiguracja.instalacje` – nazwane instalacje (`referencyjna`, `spolecznosciowa`); `zrodlo_gry` wybiera bazę.
  Warstwy (`vanilla`, `aoc`, `localization`, `hd_nieustalone`, …) są pojęciami logicznymi, niezależnymi od ścieżki.
* `Zasoby.znajdz()` – kolejność: nakładka lokalizacji (wpisy z `dane/lokalizacja/<jęz>/manifest.json`) →
  wersja EN z instalacji referencyjnej (gdy baza społ. i głosy EN) → nakładka HD (luźne zamienniki) → archiwa bazowe.
* Archiwa mieszane (oryginał + lokalizacja w jednym `data.ssa`) – nie da się ich „wyłączyć”; obsługa przez nadpisanie
  wpisów z innej instalacji. Kod nie zakłada, że każdy plik moda jest wyłączalny.
* Języki niezależne: `jezyk_tekstow`, `jezyk_glosow`, `jezyk_kampanii`; brak → EN + wpis w dzienniku.
* Importery: `BazaDB` (tabele wg `dane/uklad_db.json`), `ScenariuszEE` (teren + gracze/obiekty), `TekstyDLL`,
  `ImporterDzwiekow` (WAV/MP3 bez przekodowania), `ImporterModeli` (CEM 2.0/1.3, kolor gracza, billboard).

## Launcher (`godot/launcher/`)
* `StanLaunchera` – model bez UI: profile (`dane/launcher/profile_domyslne.json` + `konfiguracja/profile_uzytkownika.json`),
  mody = nakładki warstw, presety języka danych, ustawienia launchera. Zapis wyłącznie przez `Konfiguracja.zapisz_uzytkownika()`
  do `konfiguracja/uzytkownik.cfg` (nakładka na `openee.cfg`; testy ją ignorują).
* `launcher.gd` – widok (karty, strony), `MotywLaunchera` – styl, `IkonyLaunchera` – ikony SVG, `TekstyUI` – i18n
  (`dane/launcher/i18n/<kod>.json`; nowy język = nowy plik), `GrafikiGry` – grafiki z instalacji (cache lokalny).
* Język UI launchera jest osobnym ustawieniem (`[launcher] jezyk_ui`) – niezależnym od `[lokalizacja]` danych gry.
* Uruchamianie: `uruchom()` → `uruchom_tryb()` (sceny OpenEE) lub hak `_uruchom_oryginalna_gre()` (niepodpięty);
  `powrot.gd` dodawany do korzenia drzewa zapewnia powrót Esc.

## Etap 3 – renderer terenu i obiekty
* `silnik/render/teren_ee.gd` (`TerenEE`): logika warstw pola (`warstwy_pola` – testowalna bez renderowania),
  wariantów (`plik_wariantu`), budowa jednej siatki terenu (atrybuty CUSTOM0 = warstwy tablicy tekstur, CUSTOM1 = alfa
  narożników) i siatki wody. Reguły: `docs/FORMATY_ETAP3.md`.
* `ScenariuszEE` czyta scenariusze EE (231) i AoC (250); gramatyka rekordu z warunkami wersji w `dane/gramatyka_jednostki.json`.
* Obiekty: transformacja z macierzy rekordu; egzemplarze powtarzalnych siatek grupowane w MultiMesh.

## Etap 4 – animacje modeli i hierarchia części
Dane modelu są oddzielone od stanu instancji:

| Warstwa | Klasa | Rola |
|---|---|---|
| dane modelu | `silnik/importery/model_cem.gd` (`ModelCEM`) | wszystkie klatki CEM 2.0/1.3, części w kolejności rodzic → dzieci, lokalne macierze na klatkę, punkty tag; `globalna(i, k)` = T_rodzic · T_lokalna |
| sekwencje | `silnik/animacja/sekwencje_animacji.gd` (`SekwencjeAnimacji`) | zakresy klatek, czas cyklu, pętla, zdarzenia, dźwięki – z rekordu dbgraphics; stany (atak, ruch, bezczynność, śmierć, czynności) wyłącznie wg gniazd z danych |
| zasób renderowania | `silnik/animacja/animacja_vat.gd` (`AnimacjaVAT`) | wypieka wszystkie części (z hierarchią) do tekstury float; jedna siatka + shader; współdzielona przez wszystkie instancje |
| stan instancji | `silnik/animacja/odtwarzacz_animacji.gd` (`OdtwarzaczAnimacji`) | sekwencja, faza, prędkość, pauza na kanał; zapis 4 liczb do celu (MultiMesh/MeshInstance3D) tylko przy zmianie stanu; zegar globalny `czas_animacji` (project.godot `[shader_globals]`) |

Przepływ: `Zasoby.wczytaj_model_cem` (pamięć podręczna) → `Zasoby.wczytaj_animacje` → `AnimacjaVAT` →
`siatka` (MeshInstance3D, kolor gracza w uniformie) albo `siatka_multimesh()` (kolor = kolor instancji, stan = dane
własne instancji). Statyczny import (`ImporterModeli.importuj`) korzysta z tego samego `ModelCEM` (klatka 0 z hierarchią).

Renderer scenariusza (`sceny/test_scenariusz.gd`): obiekty z sekwencją bezczynności → jeden animowany MultiMesh na model;
pozostałe → dotychczasowe grupowanie statyczne (model + tekstura + kolor). Brak animacji lub błędny zakres → klatka 0.

Diagnostyka modelu (0.5.2): `sceny/diag_modelu.tscn` (`./uruchom_openee.sh model …`) + `silnik/diagnostyka/diagnostyka_modelu.gd`
(trójkąty, współpłaszczyznowe, duplikaty, nawinięcie, opis trójkąta); narzędzia `godot/narzedzia/*.gd` i `narzedzia/*.py`.
Scena diagnostyczna: `sceny/diag_animacji.tscn` (`./uruchom_openee.sh animacje …`) – wybór grafiki, sekwencje,
pauza, prędkość, interpolacja, drzewo części z osiami, film, pomiary. Testy: `testy/testy_etapu4.gd` (syntetyczne
modele `testy/cem_syntetyczny.gd` – bez danych komercyjnych).

## Etap 5 – symulacja jednostek i sterowanie RTS
Rozdzielone warstwy (katalog `silnik/symulacja/`):

| Warstwa | Klasa | Uwagi |
|---|---|---|
| dane ze scenariusza | `JednostkaSym.DaneJednostki` | niezmienne (typ, właściciel, pozycja, kurs, skala); scenariusz na dysku nietknięty |
| stan w symulacji | `JednostkaSym` | id, typ, właściciel, pozycja, kurs, stan ruchu, cel, ścieżka, prędkość (dbobjects), stan animacji |
| logika przemieszczania | `Symulacja` (RefCounted) | stały krok 0,05 s, kolejka rozkazów (wykonanie na początku taktu), porządek wg id, zdarzenia taktu |
| nawigacja | `MapaNawigacji`, `PolitykaRuchu`, `Sciezki` | kategorie pól z danych mapy, flagi dbobjects, A* + składowe spójności |
| czas | `ZegarSymulacji` (Node) | akumulator; 0..N taktów na klatkę; `alfa` do interpolacji renderu |
| renderowanie i animacja | `WidokJednostek` (Node3D) | MultiMesh na model (VAT), interpolacja transformacji, sekwencje ruch/bezczynność, pierścienie, trasa |
| sterowanie | `SterowanieRTS` (Node) + `Zaznaczanie` | LPM/PPM → rozkazy; trafienia promienia bez węzłów |

Symulacja nie zna węzłów Godota – widok czyta stan i zdarzenia (`trasa`, `animacja`, `stop`, `trasa_odrzucona`).
Rozszerzenia przewidziane: rozkazy jako dane (kolejki, multiplayer: wymiana rozkazów), `usun_jednostke`, wiele
zaznaczonych (`zaznaczone` jest listą), polityki dla innych typów ruchu, zapis stanu (`skrot_stanu` jako zalążek).
Scena: `sceny/rts_test.gd` (dziedziczy `test_scenariusz.gd` przez punkty rozszerzeń `_przejmij_obiekt`
i `_po_zbudowaniu`), uruchamianie: `./uruchom_openee.sh rts`.

## Etap 11 – dwie gry na jednym silniku
OpenEE uruchamia **Empire Earth** (`ee`) i **Empire Earth: The Art of Conquest** (`aoc`) jako dwie gry na wspólnym silniku
(szczegóły i dowody: `docs/WARIANTY_GRY.md`; formaty baz: `docs/FORMATY_DB_EE_VS_AOC.md`).

| Element | Plik | Rola |
|---|---|---|
| definicje gier | `dane/gry.json`, `silnik/rdzen/gry_ee.gd` (`GryEE`) | katalogi danych (kolejność), kampanie, `Language.dll`, format bazy, wersje SCN, warstwy bazowe |
| wybór gry | `Konfiguracja.gra` (`[gra] wariant`, `--gra=`) | niezależny od profilu (instalacja + mody) i języków; `Konfiguracja.profil` – alias zgodności |
| warianty formatu bazy | `dane/uklad_db_warianty.json`, `BazaDB`, `EpokiDB` | rozpoznanie ze struktury, kontrola zakresów, błąd zamiast „pomiń” |
| źródła i pamięć podręczna | `Zasoby` (`klucz_zrodel`, `przebuduj_zrodla`, `kampanie`, `teksty`) | tylko katalogi wybranej gry; pamięć podręczna kluczowana grą i źródłem |
| launcher | `StanLaunchera.wybierz_gre`, karta „Gra” | migracja `vanilla_aoc`/`vanilla_ee` → `vanilla` + gra |

Zasada: kod silnika jest wspólny, a różnice gier są danymi. Mechanika zmierzona tylko w AoC jest dla EE hipotezą, dopóki
nie zostanie zweryfikowana na oryginalnym EE.

