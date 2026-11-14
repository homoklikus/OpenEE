# OpenEE — raport etapu 54: punkt zbiórki, gospodarka, walidacja AoC i wysokość obiektów SCN

Etap prowadził Claude Fable 5.2. Oznaczenia: [P] pomiar w grze, [W] analiza kodu albo danych, [H] hipoteza,
[N] nieustalone.

Najważniejsze wyniki:
- **Lewitujące obiekty: przyczyna w generatorze map, nie w grze.** Generator kopiował rekord wzoru razem z wysokością
  jego miejsca. Gra nie osadza obiektu na terenie przy wczytaniu – robi to dopiero pierwszy krok ruchu, a budynek się
  nie rusza. Generator jest poprawiony; koszary, obywatel i taran stoją na ziemi w AoC i w EE (liczby i zrzuty).
- **Punkt zbiórki działa w Core tak jak w grze.** Reguła miejsca powstania odczytana z kodu AoC przez emulację
  i potwierdzona 13 miejscami w obu grach. 16 jednostek z punktem zbiórki zgadza się z grą co takt od utworzenia do
  zatrzymania; jedna sytuacja (cel w miejscu powstania) różni się stanami przez 3 takty.
- **Kamień to ten sam mechanizm co drewno.** Jeden zbieracz i dwóch zbieraczy przy jednej kopalni zgadzają się
  z Core co takt w AoC i EE, razem z gospodarką. Potwierdzona różnica wersji: okres kamienia 8925 ms w AoC, 8926 ms w EE.
- **Budowa w AoC:** koszary w całości; dwóch budowniczych – pierwszy obywatel i fundament w całości. Nowa reguła
  miejsca pracy naprawiła przy okazji starą rozbieżność EE 663.
- **Panel produkcji w potyczce Godot:** przyciski jednostek z kosztem i czasem, kolejka, PPM – anulowanie, PPM w teren –
  punkt zbiórki. Logika w Core.
- Regresja wcześniejszych nagrań bez zmian. CTest 26/26, GDExtension 88/88, Godot 325/325, narzędzia 24/24,
  Riverlands_MCP 108/108.

Nie zrobione: prorok i obrót końcowy w AoC (648/652), kolizje dużych jednostek (gałąź 0x548A3C), wyczerpanie złoża,
budynki inne niż 2 × 2 w regule miejsc.

## 1. Początkowy HEAD i stan repozytorium

- HEAD `e1984fa371d90a3df187795c193485245ce2c9e7` („Etap 53…”), gałąź `main`, zgodny ze zdalnym z zadania.
- Drzewo robocze: tylko pliki użytkownika (`godot/project.godot`, `*.uid` w `godot/testy/eksperymenty/`,
  `konfiguracja/uzytkownik.cfg.przed_etapem11`) – nietknięte.
- Testy bazowe przed zmianami: CTest 24/24 w Release i Debug.
- Końcowy: lokalny commit „Etap 54: punkt zbiórki, gospodarka i wysokość obiektów SCN”. Bez `push`.

## 2. Zmienione pliki

| Obszar | Pliki |
|---|---|
| Core | `cpp/core/include/openee/jednostka.hpp`, `symulacja.hpp`, `cpp/core/src/symulacja.cpp` |
| GDExtension | `cpp/gdextension/src/openee_symulacja.cpp`, `.hpp` (wersja 0.27.0) |
| Testy | `cpp/tests/testy_core.cpp`, `cpp/tests/CMakeLists.txt`, `godot/testy/testy_gdextension.gd`, `narzedzia/titan/test_titan_narzedzia.py` |
| Godot | `godot/sceny/potyczka.gd`, `godot/silnik/symulacja/sterowanie_rts.gd`, `parametry_typow_db.gd`, `godot/testy/eksperymenty/odtworz_scenariusz.gd` |
| Dane | `dane/testy_walki/e42_warianty.json`, `parametry_jednostek_ee.json`, `e35_a.uklad_wej.json`, `dane/potyczka/potyczka_e54_koszary.json` (nowy), `dane/launcher/aktualnosci.json` |
| Narzędzia | `narzedzia/eksperymenty/scenariusz_testowy_kolizji.py`, `scenariusze_czyste.py`, `narzedzia/titan/odtworzenie_nagrania.py`, `narzedzia/titan/wysokosc_obiektow.py` (nowy) |
| Dokumentacja | `docs/titan/WYSOKOSC_OBIEKTOW_SCN.md` (nowy), `produkcja.md`, `zbieranie.md`, `budowa.md`, `EE_AOC_POROWNANIE.md`, `POSTEP_REKONSTRUKCJI.md`, `fizyka_terenu.md`, `import_mapy.md`, `precyzja_numeryczna.md`, `dziennik_eksperymentow.md`, `README.md`; `docs/ARCHITEKTURA_OPENEE.md`, `docs/HISTORIA.md`, `README.md`, `raporty/README.md` |
| Raporty | `RAPORT_ETAP_54.md` (nowy), `RAPORT_ETAP_53.md` → `raporty/archiwum/` |

Riverlands_MCP: w tym etapie bez zmian. Zmiany z etapu 53 (`ee_obserwacja.py`, `ee_walka.py`, `ee_budowa.py` – parametr
`nowe_gracza`) nadal są tam niezacommitowane.

Lokalnie, poza repozytorium: mapy `e42_e54_wysokosc`, `_zbiorka`, `_kamien`; 12 nagrań; opisy odtworzeń
(`Testy_MCP/e54`); skrypty emulacji (`~/e54`).

## 3. Wysokość obiektów: diagnoza i poprawka

Pełny opis: `docs/titan/WYSOKOSC_OBIEKTOW_SCN.md`.

- Rekord trzyma pozycję w macierzy 4 × 4; z jest bezwzględne. W kampanii z − teren jest stałe dla typu: jednostki 0,
  budynki +0,01, mury +0,001 [W].
- Generator zmieniał x i y, a z zostawiał z miejsca wzoru: obywatel 1,021, gwardia i taran 1,837, koszary 1,847.
  66 z 69 map testowych miało obiekty poza terenem (275 z 292 obiektów graczy) [W].
- Pomiar (AoC 711, EE 712, scenariusz z obiema wersjami obiektów obok siebie):

| Chwila | Korekta wysokości |
|---|---|
| wczytanie scenariusza | nie |
| takty bez rozkazu | nie (obywatel 3741 próbek bez zmiany) |
| pierwszy krok ruchu po rozkazie | tak – z = teren jeszcze przed zmianą x, y |
| każdy następny krok | tak |
| jednostka z produkcji | tak – także z lewitujących koszar |
| budynek | nigdy |

- AoC i EE: te same wartości we wszystkich wierszach.
- Poprawka: `z kopii = teren(nowe miejsce) + (z wzoru − teren pod wzorem)`. Bez stałej korekcyjnej, bez z = 0.
  Wzór pływający zachowuje poziom wody; wzór, który sam nie stoi na terenie, jest odrzucany.
- Stare warianty map zachowują tryb „wzor” (odtwarzalność map wcześniejszych nagrań); nowe mają tryb „teren”.
- Walidator `wysokosc_obiektow.py scn` zgłasza obiekty graczy z |z − teren| > 0,05; testy w `test_titan_narzedzia.py`.
- Wynik w grze: poprawione obiekty mają różnicę 0 (budynek +0,01) od wczytania, na płaskim, na płaskowyżu i na stoku,
  w obu grach. Zrzuty: koszary, obywatel i taran stoją na ziemi w AoC i w EE.
- Ograniczenia: budynek na stoku (wysokość środka – nieocenione wizualnie), pochylenie wzoru, jednostki powietrzne.
- Fizyka Core bez zmian.

## 4. Funkcje Titan związane z wysokością [W]

| Rola | AoC | EE |
|---|---|---|
| wysokość terenu w punkcie | 0x4C0894 | 0x4C0201 |
| krok ruchu (z po przesunięciu) | 0x55A2B3, 0x55A668, 0x55A977 | 0x54D986, 0x54DD21, 0x54E01B |
| miejsce nowej jednostki przy budynku | 0x643561 (wywołanie 0x6438F1) | 0x62E201 (0x62E54B) |
| wczytanie obiektu (`EEComplexUnit::Load`) | bez wywołania wysokości | to samo |

Stawianie budynku przez gracza – funkcja nieodczytana [N].

## 5. Punkt zbiórki

Pełny opis: `docs/titan/produkcja.md` § 6.

- **Analiza:** funkcja tworzenia AoC 0x631B55 → wybór miejsca 0x643561. Kolejność pól obwodu (0x64BB36 bez punktu,
  0x641299 z punktem) i wzór miejsc w polu (0x63F697) odczytane przez emulację kodu na obrazie pliku exe.
- **Reguła:**
  1. pola obwodu budynku posortowane według odległości pola od pola punktu zbiórki (liczby całkowite);
  2. w polu kolejne miejsca przylegające do budynku, co rozmiar jednostki;
  3. miejsce zajęte, gdy d² + 0,1·s < ((o + s)/2)² dla jednostki w tym samym polu;
  4. kurs na dokładny punkt kliknięcia; cel w pierwszym wolnym miejscu pola punktu; stan 8000 od pierwszej próbki.
- Wybór nie zależy od liczby wcześniej wyprodukowanych jednostek, generatora losowego ani stanu kolejki – tylko od
  geometrii, punktu i zajętości miejsc. Wybór miejsca jest osobny od trasy (trasa jak dla zwykłego rozkazu ruchu).
- **Pomiary:** AoC 713 – 5 punktów (zachód ×2 jednostki, południe, północ, daleko, pole obwodu); EE 714 – 3 punkty;
  kontrola bez punktu (711/712) i nagrania etapu 53 (705/706). 13 miejsc powstania i 12 celów zgodnych z regułą.
- **Core:** punkt jako dane budynku, zmiana w czasie gry, API GDExtension, użycie w demonstracji Godot.

| Nagranie | Produkcja | Utworzenie | Przebieg nowych jednostek co takt |
|---|---|---|---|
| AoC 713 | 14046/14046 | 6/6 | 5 jednostek w całości (2485–10607 próbek); szósta 1/588 |
| EE 714 | 8752/8752 | 4/4 | 3 w całości (2333–5633); czwarta 1/581 |
| AoC 705 / EE 706 (etap 53) | 3688/3688 / 3555/3555 | 2/2 / 2/2 | 4 jednostki w całości |

- Reguła jest zapisana dla każdego rozmiaru budynku, ale zmierzona tylko dla 2 × 2 (koszary, Centrum Miasta).

## 6. Drugi surowiec i dwóch zbieraczy

Pełny opis: `docs/titan/zbieranie.md` § 6. Wybrany kamień: kopalnia kampanii (194, 131) na płaskim terenie.

- C1, jeden zbieracz [P: AoC 715, EE 716]: kopalnia typ 38, HP 1, ilość 300 000; pierwszy cykl zeruje HP, kolejne
  +1 obywatelowi i −1 złożu; udźwig 15; oddanie +15 w próbce wejścia w 4005; stany jak drewno z trzema różnicami
  (8000 w próbce kliknięcia, 4027 przed 4004, brak widocznego 4023 po oddaniu).
- Okres: AoC 8925 ms, EE 8926 ms – z taktów cyklu i z odczytu pamięci ulepszenia obywatela.
- C2, dwóch zbieraczy: osobne miejsca pracy w różnych polach obwodu, bez oczekiwania, niezależne cykle, osobne miejsca
  oddania; kamień 1333 → 1378 po trzech dostawach.
- Wyczerpanie złoża: niezmierzone (300 000 jednostek).
- Core: ten sam mechanizm co drewno; parametry źródła z dbobjects; punkty pracy i oddania z reguły pól obwodu
  (zamiast rzutu prostopadłego); okres kamienia jako parametr wariantu.

| Nagranie | Obywatele (stan, pozycja, kurs) | Gospodarka (kamień gracza, ładunek, ilość i HP złoża) |
|---|---|---|
| AoC 715 jeden | 5317/5317 | 5316/5316 |
| AoC 715 łącznie (dwóch) | 10423/10423 każdy | 10422/10422 każdy |
| EE 716 jeden | 5288/5288 | 5287/5287 |
| EE 716 łącznie (dwóch) | 10357/10357 każdy | 10356/10356 każdy |

## 7. Budowa: EE i AoC

Pełny opis: `docs/titan/budowa.md` § 9.

| Przypadek | EE | AoC |
|---|---|---|
| koszary (674 / 717) | obywatel 3803/3804, fundament 2335/2335 | obywatel 3120/3121, fundament 1688/1688 |
| dwóch budowniczych (663 / 718), pierwszy obywatel | 2270/2270 (przed etapem: do t = 77216) | 2205/2206 |
| pomocnik | do t = 62863 (przed: 58465) | do t = 63374 |
| fundament | 1072/1072 (przed: 767 + 305 nieaktualnych) | 1020/1020 |

- Wzór HP, podział pracy i kolejność stanów: bez różnic między grami (fundament zgodny co takt).
- Miejsce pracy pomocnika: następne pole listy, gdy najbliższe zajmuje pierwszy budowniczy – w obu grach.
- Otwarte w obu grach jednakowo: kurs pomocnika przy wejściu w budowę różni się o 0,0023 rad (próg 0,002).
- Różnica jednej próbki (brak 4028 w AoC, etap 53) bez nowych ustaleń.
- Aktualizacja grafu w AoC: nadal nieodczytana. Prorok i obrót końcowy (648/652) w AoC: niewykonane.

## 8. Zmiany Core i GDExtension

Core:
- `ustaw_punkt_zbiorki`, `usun_punkt_zbiorki`; pola budynku `zbiorka`, `zbiorka_x/y`.
- `pola_wyjscia`, `miejsca_w_polu`, `miejsce_wolne`, `miejsce_wyjscia` (nowa treść), `miejsce_zbiorki`.
- `CelRuchu::bez_obrotu`: cel bez obrotu końcowego – `UnitFacingNotRequired` od razu prawdą.
- `miejsce_budowy` i `punkt_przy_obiekcie`: ta sama reguła pól obwodu dla budowniczego i zbieracza.
- `rozkaz_zbierania` ustawia MoveToWaitingArea 4023; wejście w 4023 przy źródle innym niż drzewo przechodzi do 8008.
- Bez nowego wariantu w kodzie; różnica okresu kamienia jest daną (`parametry_jednostek_ee.json` → `warianty.aoc`).

GDExtension: `ustaw_punkt_zbiorki`, `usun_punkt_zbiorki`; słownik jednostki z `zbiorka*` i `prod_kolejka`; wersja 0.27.0.

Zmiany w istniejących testach (z powodem):
- CTest `budynki`, zbieranie drewna: pierwszy stan po rozkazie to teraz 4023, a 8008 po pierwszym takcie – rozkaz
  jest wykonywany przed taktem; próbka kliknięcia pozostaje 8008 jak w pomiarze 673.
- GDExtension etapu 53: napis wersji akceptuje „etap 5”.
- Tolerancji nie zmieniałem.

Narzędzia: `odtworzenie_nagrania.py` – rozkaz „zbiorka”, przebieg nowych jednostek co takt, model zegara gry
(`takt_zegara`), gospodarka dla dowolnego surowca; `odtworz_scenariusz.gd` – punkt zbiórki, parametry wariantu,
źródła z dbobjects, rozkaz zbierania przed taktem.

## 9. Zmiany Godot i interfejsu

- Potyczka `dane/potyczka/potyczka_e54_koszary.json`: zaznaczenie koszar (LPM) otwiera panel.
- Panel: przycisk każdej dostępnej jednostki (nazwa, koszt, czas); bieżąca pozycja z pozostałym czasem; kolejka;
  zasoby i populacja; punkt zbiórki.
- LPM na przycisku – `rozkaz_produkcji`; PPM na przycisku – `anuluj_technologie`; PPM w teren – `ustaw_punkt_zbiorki`
  (znacznik flagi na mapie). Odmowa rozkazu jest pokazywana w komunikacie.
- `SterowanieRTS.przechwyt_ppm`: scena może przejąć PPM, zanim pójdzie rozkaz ruchu.
- Brak logiki produkcji w GDScript: panel czyta słownik jednostki z Core.
- Automat `demo_e54` tymi samymi ścieżkami: klik w koszary trafia budynek, 2 przyciski, kolejka 0 → 1 → 2, anulowanie
  zwraca 30 + 30, punkt zbiórki (172,40; 117,60) – jednostka z narożnika (169,25; 116,25) dochodzi do (172,2; 117,26);
  po zmianie punktu druga z lewej krawędzi (166,75; 115,25) do (163,3; 115,26).
- Reszta interfejsu potyczki bez przebudowy.

## 10. Regresja i deterministyczność

| Zestaw | Etap 53 | Etap 54 |
|---|---|---|
| CTest Release | 24/24 | **26/26** (nowe: `punkt_zbiorki`, `zbieranie_kamien`) |
| CTest Debug | 24/24 | **26/26** |
| GDExtension | 83/83 | **88/88** |
| Godot | 325/325 | 325/325 |
| Riverlands_MCP | 108/108 | 108/108 (kod bez zmian) |
| `test_titan_narzedzia` | 20/20 | **24/24** |

Nagrania wcześniejsze (pierwsza rozbieżność) – wszystkie jak w etapie 53:

| Nagranie | Wynik |
|---|---|
| czyste ×5, e46 ×4, e48 a ×3 | w całości |
| 619 / 620 | 124254 / 109423 |
| 649 dom1 / dom3, 651 koszary | 74215 / 79432 / 76909 |
| 648 | prorok 3585/3585; gwardie od 6136 |
| 652 mur_rog; dom_*, kosz_* | 75034; gwardie 5318–6204 |
| 654 | 5 w całości; NE 42477; koszary W 50727 |
| 658_1 / 658_2 / 659 / 660 / 674 / 707 | w całości (2650 / 2649 / 3013 / 2411 / 3803 / 2580) |
| 663 | **lepiej:** pierwszy obywatel i fundament w całości, pomocnik do 62863 |
| 673 od t = 80000; 708 od t = 90000 | 5069/5069 i 4783/4783; gospodarka 5069 / 4782 |
| produkcja: 677 ×2, 679, 704 ×2, 705, 706 ×3, 709 | w całości (10 nagrań) |
| tarany: obok, między, zderzenie × 2 gry | w całości |
| taran sam EE / AoC; objazd EE / AoC | 55226 / 54715; 57749 / 76091 |
| gwardia wokół gwardii EE / AoC | w całości |

- Deterministyczność: dwa odtworzenia 713 (punkt zbiórki) i 715 łącznie (dwóch zbieraczy) – pliki wyników
  identyczne bajt po bajcie.
- Generator map: dwa przebiegi dają ten sam plik (suma kontrolna).

## 11. Pierwsze nierozwiązane rozbieżności

| Nagranie | Rozbieżność | Przyczyna |
|---|---|---|
| 713 jednostka 6, 714 jednostka 4 | takt 1 po utworzeniu: gra 9006, Core 2015 | cel w miejscu powstania – przejście 8000 → 9006 w grze [N]; pozycja zgodna |
| 713 | t = 431927: gra 19 losowań, Core 2 | takt rozkazu produkcji; źródło losowań [N] |
| 718 pomocnik / 663 pomocnik | t = 63374 / 62863: kurs 1,1206 / 1,1229 | kurs przy wejściu w budowę, 0,0023 rad |
| 718 pomocnik | t = 76670: stan 4002 / 4028 | koniec budowy o jedną próbkę |
| 715 „dwaj” osobno | pierwszy obywatel od próbki 0 | nagranie zaczyna się w trakcie kursu – stan początkowy nieodtwarzalny; nagrania łączne zgodne w całości |

## 12. Mapa postępu A/B/C

Pełna tabela: `docs/titan/POSTEP_REKONSTRUKCJI.md` (stan po etapie 54).

| Podsystem | Zmiana | Dowody |
|---|---|---|
| 18 Produkcja jednostek | B 3 → **4** (A 4, C 4) | EE+AoC |
| 16 Zbieranie surowców | B 2 → **3** (A 3, C 3) | EE+AoC (drewno, kamień) |

| Wskaźnik (38 podsystemów) | Etap 53 | Etap 54 |
|---|---|---|
| A ≥ 3 / B ≥ 3 / C ≥ 3 | 21 / 19 / 18 | 21 / **20** / 18 |
| A = 0 | 5 | 5 |
| ocena 5 | brak | brak |
| kod Core | 5536 wierszy | 5725 |

Ocen C nie podnosiłem: nowe zgodności dotyczą dwóch budynków 2 × 2, jednej kopalni i jednego typu jednostki.

### Postęp rekonstrukcji Titan – ile zostało do końca?

- **Rozpoznanie (A):** bez nowych podsystemów na poziomie ≥ 3. Doszła wiedza o wysokości obiektów, miejscach przy
  budynku i drugim surowcu. 12 podsystemów ma ocenę ≤ 1, 5 jest nietkniętych.
- **Zgodność AoC:** przybyły pełne odtworzenia AoC punktu zbiórki, kamienia z dwoma zbieraczami, koszar i dwóch
  budowniczych. Bez nagrań AoC: walka z budynkiem, śmierć, bohater, prorok, graf nawigacji.
- **Implementacja (B):** jedna reguła pól obwodu obsługuje cztery sytuacje – wyjście z budynku, punkt zbiórki, miejsce
  budowniczego, punkt zbieracza.
- **Największe blokery:** technologie i epoki, jednostki dystansowe, AI komputera, widoczność, gałąź kolizji dużych
  jednostek.
- **Pierwsza grywalna wersja:** pętla „zbierz drewno albo kamień → zbuduj → wyprodukuj → ustaw punkt zbiórki → walcz
  wręcz” działa w Core; panel produkcji jest. Brakuje interfejsu budowy i zbierania, złota, żelaza, żywności,
  technologii i przeciwnika.
- **Pełna rekonstrukcja Titan:** ponadto transport, lotnictwo, okręty, kalamity, wyzwalacze, zapis gry, multiplayer,
  edytor. Terminu nie podaję.
- Średnie ocen (2,29 / 2,05 / 1,97) są wskaźnikiem kierunku, nie procentem ukończenia.

## 13. Różnice EE/AoC

Nowe wpisy w `docs/titan/EE_AOC_POROWNANIE.md` § 2:
- ZMIENIONE [P]: okres zbierania kamienia – EE 8926 ms, AoC 8925 ms;
- WSPÓLNE [P]: wysokość obiektów ze scenariusza; miejsce powstania, punkt zbiórki i cel; zbieranie kamienia i dwóch
  zbieraczy; budowa koszar i dwóch budowniczych; zegar gry 34,09375 ms na takt od 65 536 ms;
- nierozstrzygnięte: obrót w 9006 przy celu bez obrotu (EE – jednostka stojąca się obraca; w AoC jednostki jeszcze
  hamowały) – Core odtwarza oba przypadki jedną regułą.

## 14. Otwarte hipotezy

1. Punkt odniesienia punktu oddania i powrotu = poprzedni punkt zaokrąglony do pola [H] – 6 punktów, jedna geometria.
2. Natychmiastowe przejście 4023 → 8008 jako akcja stanu, nie przejście Gather.tai [H].
3. Mnożnik 0,85 okresu kamienia (10500 w dbobjects) i źródło różnicy 8925 / 8926 [H: zaokrąglenie].
4. Test zajętości miejsca: warunki klasy (flagi +0x2FC, +0x303, +0x317) [N] – w Core każda jednostka.
5. Remisy sortowania pól dla budynków ≥ 4 × 4 [N].
6. Przejście 8000 → 9006 przy celu w miejscu powstania [N].
7. Funkcje Titan miejsca pracy budowniczego i zbieracza – reguła z pomiaru, kod nieodczytany.
8. Pozycje otwarte wcześniej (gałąź duża, stok, D1–D3, 654, 649/651, 619/620) – bez zmian.

## 15. Proponowany zakres etapu 55

1. Prorok i obrót końcowy w AoC (648, 652) – ostatni punkt priorytetu D.
2. Złoto albo zbieractwo (żywność) oraz dwóch zbieraczy w tym samym polu obwodu (zajęte miejsce, oczekiwanie).
3. Punkt zbiórki dla Centrum Miasta i budynku 3 × 3; brak miejsca w pierścieniu; limit populacji.
4. Interfejs budowy i rozkaz zbierania w potyczce (rozkazy Core są).
5. Gałąź kolizji dużych jednostek: odczyt 0x548E58–0x549179 – teraz także emulacją kodu, która sprawdziła się w tym
   etapie.
6. Przegenerowanie najczęściej używanych map testowych w trybie „teren” przy okazji nowych pomiarów.

## 16. Koszt prac i narzędzia

- Zadania MCP: 8 (711–718): 5 w AoC (711, 713, 715, 717, 718), 3 w EE (712, 714, 716); wszystkie udane.
- Nagrania: 12 (`e54_711_wys`, `e54_712_wys`, `e54_713_zbiorka`, `e54_714_zbiorka`, `e54_715_jeden`, `_dwaj`,
  `e54_716_jeden`, `_dwaj`, `e54_717_ob`, `_bud`, `e54_718_ob`, `_bud`) + 2 złożenia łączne; ponownie użyto 5 nagrań
  etapu 53 i Fable do diagnozy wysokości oraz nagrań regresji.
- Odtworzenia w Core: około 150 uruchomień (nowe nagrania w kolejnych wersjach reguł, pełna regresja, determinizm).
- Wywołania REA/Ghidra: 0. Analiza: listingi liniowe obu plików exe i emulacja 6 funkcji AoC (Unicorn).
- Czas: start 08:04, ostatnie zadanie MCP zakończone 09:00, koniec prac około 09:30 czasu lokalnego (około 1,5 h).
- Tokeny: brak danych w tym środowisku.
