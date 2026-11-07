# OpenEE – raport: naprawa grafiki (modele, materiały, UV, hierarchie) – 0.5.1-dev

Data: 2026-11-05. Zakres: wyłącznie poprawność importu i renderowania modeli. Nie dodano mechanik RTS, formacji, walki,
ekonomii, SI ani sieci.

## 1. Stan wyjściowy
* Git lokalny: `main` = `1505618` (= GitHub `origin/main`, ostatni push po etapie 5), drzewo czyste.
* Kopia zapasowa przed zmianami: `kopie_OpenEE/OpenEE_przed_naprawa_grafiki_2026-11-05.tar.gz` (poza repozytorium).
* Testy przed zmianami: 121/121 zaliczonych – **żaden test nie wykrywał błędów opisanych niżej**: kontrola CEM sprawdzała
  tylko, czy indeks < liczba wierzchołków części, a test koloru gracza – tylko obecność formuły w shaderze.

## 2. Objawy → przyczyny

| Objaw | Przyczyna | Warstwa | Status |
|---|---|---|---|
| „Rozsypane / eksplodujące” budynki, trójkąty łączące odległe punkty | A: indeksy trójkątów materiału odczytywane jako bezwzględne, a są względne wobec `v_offset` | **importer** (`ModelCEM`, `ImporterModeli.parsuj`, `cem.py`) | naprawione |
| Rozciągnięte tekstury / złe UV na ścianach i dachach | A (drugi materiał brał UV wierzchołków pierwszego) + B: zawsze obraz 0 pliku SST | **importer** (`Zasoby`, `ImporterModeli`, `AnimacjaVAT`) | naprawione |
| Żółte/pomarańczowe trójkąty i płaty (kolor gracza) | A (trójkąty `player color` rozlane na przypadkowe wierzchołki) + C: reguła mieszania koloru | importer + **renderer** (shader) | naprawione |
| Niektóre obiekty dobre, inne nie | modele z jednym materiałem (`v_offset = 0`) – obie interpretacje indeksów równoważne; błąd ujawniał się tylko przy ≥ 2 materiałach i ≥ 2 obrazach SST | – | wyjaśnione |

Szczegóły formatu: `docs/FORMATY_NAPRAWA_GRAFIKI.md`.

### Hipotezy z wcześniejszych etapów okazały się błędne
* Etap 1: indeksy LOD bezwzględne → **względne wobec `v_offset`** [D: 544/544 materiałów z `v_offset > 0`].
* Etap 1: drugi obraz SST = maska koloru gracza → **kolejna tekstura modelu, wybierana polem materiału** [D: 811/824 grafik].
* Etap 2: kolor gracza = `mix(kolor, tekstura, alfa)` → **tekstura.rgb × kolor gracza** (fragmenty pod `player color` szare,
  alfa 255) [D co do danych, H co do dokładnej jasności].

### Sprawdzone i bez błędu
* **Hierarchia części** (parent/child, macierze klatek, pivot, części `orbital_*`): 188 części potomnych, 148 spójnych
  orbitali, 4 przypadki niejednoznaczne (`gun_aagun_11`, `gun_aaskywatcher_11`, `bld_dock_14`, `fx_priesttower_03`)
  obejrzane – położenie wiarygodne. Kolejność macierzy z etapu 4 bez zmian.
* **Kolejność wierzchołków / winding / culling**: zamiana 2↔3 indeksu przy zmianie osi (Z w górę → Y w górę) poprawna;
  normalne ścian zgodne z normalnymi wierzchołków po naprawie (wcześniej niezgodne na drugich materiałach).
* **Stride/offset wierzchołków** (32 B: poz., normalna, UV) i odwrócenie V – poprawne; błąd UV wynikał wyłącznie z A i B.
* **Wariant CEM 1.3** – wierzchołki powstają z rogów trójkątów (brak `v_offset`), więc błąd A nie występuje; bez zmian.
* **Przezroczystość** zwykłych materiałów – wycinanie alfa pozostaje (drzewa, ogrodzenia); dla `player color` wyłączone.

## 3. Zmiany w kodzie (systemowe, bez łatek pod konkretne modele)
* `godot/silnik/importery/model_cem.gd` – odczyt `tekstura_id`, `v_offset`, `v_liczba`; indeksy `v_offset + i`;
  `kontrola()` sprawdza zakres materiału.
* `godot/silnik/importery/importer_modeli.gd` – to samo w `parsuj` (ścieżka zgodności); nowa wspólna funkcja
  `obraz_materialu()` (obraz nr `tekstura_id`, zgłaszanie braków i numeru poza plikiem); shader: `t.rgb * kolor_gracza`.
* `godot/silnik/animacja/animacja_vat.gd` – ta sama reguła koloru i wybór obrazu dla modeli animowanych.
* `godot/silnik/zasoby/zasoby.gd` – `wczytaj_tekstury()` zwraca wszystkie obrazy SST (z pamięcią podręczną).
* `narzedzia/eeformaty/cem.py` – `indeksy_materialu()`, kontrola zakresów materiałów.
* Wersja 0.5.1-dev (launcher, `project.godot`, README, aktualności).

## 4. Testy regresji – `godot/testy/testy_grafiki.gd` (15 nowych, łącznie **136/136 zaliczonych**)
Jednostkowe (syntetyczny CEM z 2 materiałami, bez danych gry):
* indeksy względne (materiał B z `v_offset = 3` → wierzchołki [3, 5, 4]); odczyt `tekstura_id`, `v_offset`, `v_liczba`;
* wykrycie złego indeksu (poza zakresem materiału) przez `kontrola()`; zgodność `parsuj` z `ModelCEM`;
* UV i geometria każdej powierzchni siatki zgodne z wierzchołkami jej materiału;
* `obraz_materialu`: wybór obrazu 1, przycięcie numeru poza plikiem, `null` przy braku tekstury;
* parametry materiałów (`kolor_gracza_mnoz` tylko dla `player color`, wycinanie alfa tylko dla zwykłych);
* VAT: te same indeksy co siatka statyczna.

Integracyjne (dane z instalacji użytkownika; bez niej pomijane):
* `kontrola()` na 105 modelach z `dbgraphics` – 0 błędów;
* 5 problematycznych budynków: trójkąty `player color` trafiają w szare pola tekstury (mediana nasycenia 0–14/255),
  dawny odczyt trafiał w kolorowe fragmenty (44–94/255) w 3 z 5 modeli – w Fortress/Barracks przesunięte wierzchołki
  przypadkiem też padały na szare pola, ale geometria była błędna (widać na zrzutach);
* House – Paleo: materiał z `tekstura_id = 1` dostaje obraz 1 pliku z 2 obrazami;
* fragmenty tekstur pod `player color` (262 próbki) – mediana nasycenia 0/255;
* 64 modele scenariusza Troi – każda teksturowana powierzchnia ma obraz.

## 5. Weryfikacja wizualna (zrzuty lokalne, poza repozytorium – zawierają grafikę gry)
* `wyniki/naprawa/przed/zestawienie.png` i `wyniki/naprawa/po/zestawienie.png` – 6 modeli w scenie diagnostycznej
  (`diag_animacji.tscn --model=… --bez-ui`):
  * **House – Copper** (budynek „rozsypany”): przed – pomarańczowe bryły i trójkąty przez cały model; po – spójny dom,
    kolor gracza tylko na detalach;
  * **House – Paleo** (złe UV, 2 obrazy SST): przed – zniekształcona tekstura, druga połowa modelu z obrazu 0; po – poprawne
    ściany i dach;
  * **Fortress – Copper**, **Town Center – Paleo**, **Barracks – 10** (żółte fragmenty): przed – odłamki i płaty koloru
    gracza; po – spójna bryła, kolor gracza na chorągwiach/obramowaniach;
  * **Scaffolding Copper 3×3** (obiekt odniesienia, 1 materiał): przed = po.
* `wyniki/naprawa/troja_przed_po.png` – scena podglądu scenariusza Troi: pomarańczowe „klocki” zamiast domów → poprawne
  domy; mury z obramowaniem w kolorze gracza.
* `wyniki/naprawa/hierarchia_watpliwe.png` – 4 niejednoznaczne przypadki hierarchii.

Kryterium ukończenia: problematyczne budynki mają spójną geometrię (normalne zgodne, brak trójkątów spinających odległe
części), właściwe tekstury (obraz wg materiału, UV z własnych wierzchołków) i kolor gracza tylko na przeznaczonych do tego
szarych fragmentach – potwierdzone testami i zrzutami.

## 6. Klasy błędów faktycznie naprawione
1. Błędne wierzchołki trójkątów materiałów z `v_offset > 0` (geometria „rozsypana”) – importer.
2. Błędne UV tych trójkątów (rozciągnięte tekstury) – importer.
3. Zawsze pierwszy obraz pliku SST zamiast obrazu wskazanego przez materiał – importer.
4. Kolor gracza rozlany na przypadkowe trójkąty – importer (skutek 1).
5. Reguła mieszania koloru gracza (mix z alfą → mnożenie przez szarą teksturę) – renderer.
6. Cichy brak tekstury / numer obrazu poza plikiem – teraz zgłaszane w dzienniku.
7. Luki w testach: kontrola zakresu materiału, testy UV/materiałów/obrazów na danych.

## 7. Otwarte kwestie [H]
* Dokładna jasność koloru gracza (mnożenie liniowe vs. sRGB, ewentualne rozjaśnienie) – do porównania z oryginalną grą
  (porównanie w Wine nadal zablokowane w piaskownicy sesji – etap 5).
* Próg wycinania alfa (0,5) i ewentualne mieszanie półprzezroczyste.
* 12 grafik, w których liczba obrazów SST nie równa się max(`tekstura_id`) + 1 (w tym `nav_fishingboat_02`).

## 8. Bezpieczeństwo i licencja
Nie zmieniono instalacji EE/AoC (tylko odczyt), Riverlands ani laboratorium; nie użyto dekompilacji – ustalenia
pochodzą ze statystyki plików danych. Do repozytorium trafiają wyłącznie pliki tekstowe (kod, testy, dokumentacja);
zrzuty i dane gry pozostają w ignorowanym `wyniki/`. Licencja GPLv3 bez zmian.

## 9. Git / GitHub – stan publikacji
* Commit lokalny `4ed3c3a` „OpenEE 0.5.1-dev – naprawa grafiki: indeksy materiałów, obrazy SST, kolor gracza”
  (20 plików, tylko tekst: kod, testy, dokumentacja) + commit z tym raportem; rodzic `1505618` (= `origin/main`).
* Kontrola zawartości: w indeksie brak plików zasobów gry (`*.cem`, `*.sst`, `*.ssa`, `*.dat`, zrzuty); jedyne pliki PNG
  w repozytorium to własne banery launchera z etapu launchera.
* Test czystej kopii (`git clone` bez danych użytkownika): 132 testy, 69 zaliczonych, 63 pominiętych jawnie (wymagają
  instalacji gry), 0 błędów. Pełna kopia robocza z danymi: 136/136.
* GitHub: sesja nie ma dostępu do konta GitHub (brak powiązania), więc push należy wykonać ręcznie:
  `git push origin main` (bez force – historia liniowa nad `1505618`).
