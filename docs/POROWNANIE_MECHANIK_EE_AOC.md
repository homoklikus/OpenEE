# Porównanie mechanik: Empire Earth i The Art of Conquest

Etap 12 OpenEE. Dokument zestawia pomiary podstawowych mechanik w **oryginalnym Empire Earth** (`Empire Earth.exe`)
i w **The Art of Conquest** (`EE-AOC.exe`), wykonane tym samym zestawem narzędzi na tym samym scenariuszu. Dotąd
kamerę i ruch grupowy mierzono tylko w AoC (etapy 9–10), a ich wspólność z EE była hipotezą (`docs/WARIANTY_GRY.md` § 4).

**Oznaczenia pewności:**
- **[P]** potwierdzone powtarzalnym pomiarem;
- **[W]** wniosek z ograniczonego pomiaru (jedna próba albo pośrednio);
- **[H]** hipoteza;
- **[N]** nieustalone.

**Zakres:** **EE** – tylko Empire Earth, **AoC** – tylko The Art of Conquest, **obie** – zmierzone w obu grach
z tym samym wynikiem, **obie?** – wspólność tylko przypuszczalna.

## 1. Środowisko pomiarów

| | Empire Earth | The Art of Conquest |
|---|---|---|
| plik wykonywalny | `Empire Earth.exe`, SHA-256 `e352d7ae…a2b5` | `EE-AOC.exe`, SHA-256 `db8fc5ce…7f52` |
| instalacja | społecznościowa (Lutris, GOG + NeoEE), uruchamiana tym samym profilem Wine | ta sama |
| okno | 3440×1440, obszar mapy 3440×1302 | to samo |
| szybkość gry (rejestr) | `Game Speed` = 1 | `Game Speed` = 1 |
| czułość myszy (rejestr) | `Mouse Sensitivity` = 31 | `Mouse Sensitivity` = 7 |
| VSync (rejestr) | 0 | 1 |
| scenariusz | „Wojna trojańska” (kampania EE, wersja SCN 231), kopia `000_EETEST_e12_troja.scn` | ten sam plik |

Ustawień gier nie zmieniano. Różnica czułości myszy tłumaczy różne przełożenie ruchu myszy na kursor (EE ~19 px,
AoC ~4,7 px na jednostkę ruchu względnego X11) i została uwzględniona w narzędziach (krok kursora dobierany
adaptacyjnie).

**Wybór scenariusza.** Podstawowe EE odrzuca scenariusze w wersji 250 (komunikat „Plik z zapisaną grą jest
nieprawidłowy”) [P, EE]. Scenariusz w wersji 231 wczytują obie gry: 7 graczy i 5368 obiektów w pamięci obu gier [P].
„Wojna trojańska” ma teren płaski i górzysty, morze, mury z bramą, budynki, drzewa, obywateli, piechotę, bohatera
i proroka. Nie ma w niej kawalerii ani brodu, dlatego te przypadki porównuję z pomiarami etapu 9 (AoC, Riverlands).

**Wiarygodność odczytu EE.** Struktury pamięci EE zmierzono od nowa (adresy w `Riverlands_MCP`, `ee_warianty.py`).
Porównanie z plikiem scenariusza: 5325 z 5327 identyfikatorów obiektów znalezionych w pamięci, typ i gracz zgodne
w 5325/5325, pole mapy zgodne w 5285 [P]. Dopiero po tej weryfikacji porównywano mechaniki.

**Metadane każdego eksperymentu** (wariant, kompilacja exe, scenariusz, ustawienia, czas, stan początkowy) zapisują
wyniki zadań MCP `Testy_MCP/ee_zadania/180…235_*.wynik.json` (lokalnie, poza repozytorium).

## 2. Tabela porównawcza

| Mechanika | EE | AoC | Czy wspólny kod wystarcza? | Dowody |
|---|---|---|---|---|
| Azymut kamery | 135°, stały | 135°, stały | tak (obie) [P] | macierz kamery, oba warianty |
| Pochylenie | 35°, stałe na każdym poziomie | 35° | tak (obie) [P] | jw. |
| Wartość kąta w strukturze projekcji | 0,78542 rad | 0,78542 rad | tak (obie) [P]; znaczenie tej wartości względem zmierzonego 48,4° poziomo – [N] | struktura projekcji, pole +0x24, w obu grach |
| Poziomy zoomu | 21, skokowo, d = 29,7 − 1,49·krok, min 0,1 | to samo | tak (obie) [P] | zad. 181, 201, 211 |
| Zoom z Shift/Ctrl | jak bez modyfikatora | jak bez modyfikatora | tak (obie) [P] | zad. 201, 211 |
| Strzałki, poziom 20 | 42,3–43,2 pola/s | 43,45 pola/s | tak (obie) [P]; model 15 + 30·p/20 (pomiar z próbkowaniem zaniża ~2–4%) | zad. 201, 211 |
| Strzałki, poziom 0 | 14,16 pola/s | 14,48 pola/s | tak (obie) [P] | jw. |
| Dwie strzałki (góra + prawo) | 60,6 pola/s (suma bez normalizacji) | 61,3 pola/s | tak (obie) [P] | jw. |
| Krawędź ekranu – skok kursora na krawędź bez dalszego ruchu | brak przewijania | brak przewijania | tak (obie) [P] | zad. 230, 215 |
| Krawędź – kursor na krawędzi i ruch na zewnątrz | przewija, prędkość od razu stała: ~38 pola/s (poziom 20), ~12,5 (poziom 0); 4 krawędzie | przewija; prędkość narasta przez ~1 s od ~3 do ~38 pola/s (poziom 20), od ~4 do ~12,3 (poziom 0); 4 krawędzie | prędkość docelowa wspólna (obie) [P] = 5/6 strzałek; narastanie tylko w AoC [W] – przyczyna nieustalona, możliwe ustawienie czułości myszy (31 / 7) [H] → **bez zmian w OpenEE** | zad. 231, 233, 234 |
| Środkowy przycisk (200 jednostek ruchu w prawo) | 35,9 pola, ruch tylko w czasie przeciągania, dryf 0 | 36,7 pola, dryf 0 | tak (obie) [P] dla tego samego wejścia; wartość bezwzględna różni się od etapu 10 (14 pól przy tej samej liczbie jednostek) – [N], możliwa zmiana przyspieszenia wskaźnika X11 między sesjami [H] | zad. 201, 211 |
| Granica ogniska | romb x + y ∈ [140, 420] na mapie 140×140 (punkty (69,9, 70,1) i (209,9, 210,1)) | to samo | tak (obie) [P] | zad. 201, 211 |
| Wysokość ogniska | śledzi teren: 2,237 na wzgórzu obozu, 0,4 nad morzem | to samo | tak (obie) [P] | jw. |
| `kam_ustaw` (sterowanie kamerą z MCP) | 2–4 iteracje, błąd ≤ 0,53 pola | to samo | tak – narzędzie wspólne, adresy osobne | zad. 182, 201, 211 |
| LPM na jednostce | zastępuje zaznaczenie | zastępuje (etap 9) | tak (obie) [P] | zad. 189, 225; MECHANIKA_RUCHU_EE.md § 2 |
| Shift + LPM | dodaje; na zaznaczonej bez zmian | to samo (etap 9) | tak (obie) [P] | jw. |
| Ctrl + LPM na zaznaczonej | usuwa | usuwa (etap 9) | tak (obie) [P] | jw. |
| Esc | nic nie zmienia | nic nie zmienia | tak (obie) [P] | zad. 225, 215 |
| Ramka | zastępuje zaznaczenie; obejmuje bohatera i proroka, jeśli są w ramce | to samo (6 identycznych obiektów w obu grach) | tak (obie) [P] | zad. 225, 215 |
| Ctrl + ramka | usuwa zaznaczone z ramki | to samo | tak (obie) [P] | jw. |
| LPM na murze | zaznacza mur | zaznacza mur | tak (obie) [P] | jw. |
| LPM na pustym terenie | nie zmierzono w EE (punkt testowy trafił w mur) | odznacza (etap 9) | obie? [H] | – |
| Limit zaznaczenia | nie badano | ≥ 50 (etap 9) | [N] – 50 nie jest udowodnionym maksimum | – |
| Prędkość jednostki | **etap 13:** `Speed` pól/s czasu gry; czas gry = 1,461 × rzeczywisty | to samo | tak (obie) [P] | `MECHANIKA_PREDKOSCI_EE.md`; zad. 292–344 |
| Mnożnik prędkości a scenariusz | etap 12: 1,706 („Wojna trojańska”) – **etap 13: artefakt metody** (maksimum próbek); średnia: Speed × 1,43–1,50 | to samo | jeden mnożnik 1,461 (obie) [P] | jw. |
| Dodatek prędkości w scenariuszu z „Blitzkriegu” | +0,15 pola/s gry (obywatel, prorok) | +0,15 (to samo) | tak (obie) [P]; przyczyna [N], bez implementacji | zad. 268–335, 307, 308 |
| Prorok (Speed 0,45) | **etap 13:** 0,600 pola/s gry na trasie 27–28,6 pola („Blitzkrieg”), 0,461 („Wojna trojańska”) | 0,600 („Blitzkrieg”), 0,461 („Wojna trojańska”) | brak osobnego mnożnika (obie) [P]; wartości 0,853/0,96 z etapu 12 (trasa 1,2 pola) wycofane | zad. 307, 308, 342, 346 |
| Zegar czasu gry `A_GRA+0xD0` | 1460,9–1461,5 ms/s; stoi w pauzie (F3) i w przerywniku | 1460,7–1461,1 ms/s | tak (obie) [P] | zad. 292, 307, 308, 337, 342, 346 |
| Start ruchu, obrót | wszystkie w tym samym takcie, obrót pomijalny | to samo | tak (obie) [P] | jw. |
| Szyk i miejsca końcowe | identyczne z AoC w granicy 0,05 pola | – | tak (obie) [P] | porównanie trajektorii zad. 189/215 |
| Prędkość indywidualna w grupie | każda jednostka własna | to samo | tak (obie) [P] | jw. |
| Nowy PPM w trakcie ruchu | zastępuje rozkaz natychmiast | to samo | tak (obie) [P] | jw. |
| Shift + PPM (kolejka) | dopisuje punkt | dopisuje punkt | tak (obie) [W] | jw. |
| Grupy idące naprzeciw | **etap 13:** przenikanie, 1 na 1, 5 na 5, 10 na 10: d_min 0,017–0,054, bez zatrzymań | to samo: d_min 0,015–0,030 | tak (obie) [P] | `KOLIZJE_JEDNOSTEK_EE.md`; zad. 268–284 |
| Skrzyżowanie pod kątem prostym, przesmyk 1 pola | przenikanie, bez kolejki | to samo | tak (obie) [P] | zad. 278, 290, 325, 327 |
| Jednostka stojąca na trasie | objazd jej pola (d_min 0,660) | objazd (0,666), trajektoria zgodna do 0,01 pola | tak (obie) [P]; OpenEE: `OMIJANIE_STOJACYCH` | zad. 329, 331 |
| Wspólny punkt docelowy | druga jednostka staje 0,297 od pierwszej | 0,295 | tak (obie) [W] – 2 jednostki | zad. 333, 335 |
| Teren, woda, modele, skala | ta sama geometria, te same modele i woda | – | tak (obie) [P] | 5 par kadrów, § 4 |
| Jasność kadru | ~10 jednostek ciemniej | – | [H] – możliwa mgła lub stan rozpoznania mapy; **bez zmian renderera** | jw. |

## 3. Podział na grupy

### 3.1. Zgodne – wystarcza wspólny kod OpenEE

Orientacja kamery, zoom, prędkość strzałek, dwie strzałki, granica ogniska, wysokość ogniska, docelowa prędkość
przewijania krawędzią, środkowy przycisk (dla tego samego wejścia), reguły zaznaczania zmierzone w obu grach,
prędkość jako Speed × mnożnik scenariusza, szyk, prędkości indywidualne, zastępowanie rozkazu, geometria terenu
i wody. Wspólny kod OpenEE (`ModelKameryEE`, `zaznaczenie_ee.gd`, `formacja_ee.gd`, `Symulacja`) odpowiada obu grom.
Testy etapu 12 sprawdzają, że te parametry nie zależą od wybranej gry.

### 3.2. Różne – wariant przez dane lub parametry

Potwierdzonych różnic mechaniki nie ma. Różnice, które istnieją, leżą w danych i w ustawieniach:
- bazy `dbobjects` (wartości pól ruchu w wielu rekordach) – OpenEE czyta bazę wybranej gry (etap 11);
- adresy i struktury pamięci oryginałów – tylko narzędzia MCP, osobne definicje wariantów;
- czułość myszy, VSync – ustawienia użytkownika w rejestrze, nie mechanika gry.

### 3.3. Nieustalone – bez zmian w kodzie

- narastanie prędkości przewijania krawędzią w AoC [W] i jego brak w EE (przyczyna: gra czy czułość myszy);
- ~~prędkość proroka~~, ~~unikanie lokalne w EE~~, ~~mnożnik zależny od scenariusza~~ – wyjaśnione w etapie 13 (§ 6);
- przyczyna dodatku +0,15 pola/s gry w scenariuszu z „Blitzkriegu” [N];
- LPM na pustym terenie w EE [H];
- limit zaznaczenia [N];
- jasność kadru EE [H].

## 4. Grafika – kadry porównawcze

Pięć par kadrów (EE 210828/842/854/901/911, AoC 210241/254/305/312/322) przy tej samej rozdzielczości, ognisku
i poziomie zoomu. Geometria terenu, modele, skala i woda są takie same [P]. Niskie SSIM wynika z przesunięcia
ogniska o 0,7 pola między grami i z różnego rozstawienia jednostek w chwili zrzutu. EE jest średnio ~10 jednostek
jasności ciemniejsze [H]. Różnice dotyczą stanu sceny (mgła, rozpoznanie, pora animacji), a nie zasobów lub
renderera, więc renderer OpenEE nie został zmieniony.

## 5. Skutki dla OpenEE

- Bez nowego kodu mechanik: pomiary nie wykazały różnicy EE ↔ AoC w zaimplementowanych mechanikach.
- `Symulacja.MNOZNIK_PREDKOSCI = 1,46` zostaje (pomiar AoC na Riverlands). Opis stałej mówi teraz, że mnożnik
  zależy od scenariusza i jest taki sam w obu grach. Pomiar 1,706 na „Wojnie trojańskiej” nie uzasadnia zmiany
  stałej bez ustalenia przyczyny.
  **[Etap 13.5 – zastąpione]** Etap 13: mnożnik nie zależy od scenariusza – 1,706 był artefaktem metody; stała = tempo czasu gry 1,461
  (§ 6, `docs/MECHANIKA_PREDKOSCI_EE.md`).
- Parametry wspólne obu gier zapisano w `dane/mechaniki_ee_aoc.json` (wartości, zakres, pewność, dowód). Testy
  etapu 12 sprawdzają zgodność `ModelKameryEE` z tymi danymi dla obu gier.
- Renderer – bez zmian (§ 4).

## 6. Etap 13 – prędkość i kolizje

Pomiary z zegarem czasu gry i trajektoriami 30 Hz na scenariuszach testowych zbudowanych z kopii „Blitzkriegu” oraz
na „Wojnie trojańskiej”, w obu grach z tymi samymi plikami i rozkazami (`docs/MECHANIKA_PREDKOSCI_EE.md`,
`docs/KOLIZJE_JEDNOSTEK_EE.md`). Różnic EE ↔ AoC nie stwierdzono: zegar gry, prędkości i trajektorie kolizji są zgodne
w granicy 0,01–0,03 pola. Zmiany w OpenEE dotyczą obu gier jednakowo, bez rozgałęzień:
- `MNOZNIK_PREDKOSCI` 1,461;
- omijanie pól jednostek stojących.
