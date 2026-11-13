# Produkcja jednostek w budynkach (etapy 52–53)

Atlas mechanizmu produkcji jednostek w Titan i jego odpowiednik w OpenEE Core. Główna wersja badawcza: AoC
(`EE-AOC.exe` db8fc5ce…); kontrolnie EE (`Empire Earth.exe` e352d7ae…). Obie kompilacje GOG + NeoEE. Adresy każdej gry
ustalone osobno (wzorce kodu, RTTI), bez przenoszenia przesunięć między grami. Porównanie wersji:
`EE_AOC_POROWNANIE.md`.

Oznaczenia: [P] pomiar, [W] analiza statyczna, [H] hipoteza, [N] nieustalone.

## 1. Rozpoznanie Titan

### 1.1. Ścieżka rozkazu

`EEMBuildUnit` („Build Unit”, AoC vtable 0x838AB4, EE 0x824B40) **nie jest produkcją w budynku**. Wykonanie (AoC
0x4BBCC4) tworzy fundament budynku w punkcie (+0x10, +0x14) i przydziela go zaznaczonej grupie (+0x9AC), z dopisaniem
celu (Shift, +0x1C) albo zastąpieniem kolejki [W]. To rozkaz budowy z etapów 50–51.

Produkcję jednostek wydaje komunikat **„Research Technology”** (`EEMResearchTechnology`, AoC vtable 0x83D550,
wykonanie vt[10] = 0x4C49B7; EE vtable 0x828888, vt[10] = 0x4BBE02) [W]. Jednostka to technologia z
„Is object?” = 1 (`dbtechtree`). Pola komunikatu (AoC, serializacja 0x4C4D8A): +0xC (1 B), +0x10 budynek, +0x14
technologia, +0x18 flaga (Shift → 5 sztuk, inaczej 1).

Wykonanie: dla każdego zaznaczonego, ukończonego budynku tego typu (+0x34C AoC / +0x340 EE) – dopisanie do kolejki
(0x5F5F97). Dla części typów technologii wybór budynku o najkrótszej kolejce (0x4940EB) [W].

### 1.2. Funkcje i pola

| Funkcja | AoC | EE | Źródło |
|---|---|---|---|
| wykonanie „Research Technology” | 0x4C49B7 | 0x4BBE02 | [W] RTTI + vt[10] |
| dopisanie do kolejki | 0x5F5F97 | 0x5E8908 | [W] wzorzec: limit kl. 0x1B, push, vt+0xB4 |
| start pozycji z kolejki | 0x5FDC58 | 0x5EF9FF | [W] +0x34C/+0x340, vt+0x54(…, 2), ×(+0x94) |
| ustawienie bieżącej pozycji | 0x5FEA99 | 0x5F077C | [W] wywołanie z BuildingRepaired (EE 0x60BD19) |
| odliczanie i utworzenie | 0x6394CD (tworzenie 0x631B55) | 0x624DF8 (tworzenie w funkcji) | [W] −A_GRA+0xA4, ponowienie 5000 ms |
| anulowanie bieżącej | 0x5FD8F3 | [N] | [W] zwrot vt+0x44 ×1,0 |
| anulowanie pozycji / całej kolejki | 0x5FD984 / 0x5FCE47 | [N] | [W] |
| gracz: opłata (vt+0xB4) | 0x56B09E | 0x55BE2C | [W] indeks 45 w obu |
| gracz: zwrot (vt+0x44) | 0x5628CB | 0x5546F5 | [W] indeks 17 w obu |
| gracz: liczniki kl. 0x1B (vt+0x50) | 0x564223 | 0x555E93 | [W] |
| gracz: warunki (vt+0x54) | 0x563A25 | 0x55574D | [W] |
| gracz: limit (vt+0x7C) | 0x56528B | 0x556EBC | [W] |

| Pole | AoC | EE | Źródło |
|---|---|---|---|
| kolejka budynku (wektor) | +0x48 (+0x4C pocz., +0x50 kon.), pozycja **8 B** {technologia, flaga +0xB4E gracza} | +0x48 (+0x4C, +0x50), pozycja **4 B** {technologia} | [W] + [P: 677/679] |
| bieżąca technologia (100000 = brak) | +0x260 | +0x25C | [W] + [P] |
| pozostały czas ms | +0x280 | +0x27C | [W] + [P] |
| budynek ukończony | +0x34C | +0x340 | [W] |
| populacja gracza | +0xB14 | +0xB10 | [P: AoC 677, EE 679] + [W] |
| składniki limitu | +0xB20, +0xB24, glob. 0x930E14 | +0xB1C, +0xB20, glob. 0x9183D4 | [W] + [P: glob. 100] |
| zasoby gracza (żywność … żelazo) | +0xAFC … +0xB0C | +0xAF8 … +0xB08 | [P: 675/677; 660] |
| kategoria kl. 0x1B (jedn., rezerw., limit 1) | +0xB28, +0xB2C, +0xAE0 | +0xB24, +0xB28, +0xAE8 | [W]; [P] stałe przy obywatelach; znaczenie [H: bohaterowie] |

### 1.3. Algorytm (AoC i EE – ten sam przebieg)

1. **Rozkaz** (0x5F5F97): warunek kosztu (gracz vt+0x80, mnożnik 1,0) i, dla klasy +0x1D0 = 0x1B, osobny limit. Pozycja
   na koniec kolejki. **Koszt pobierany od razu** (gracz vt+0xB4, mnożnik 1,0) [W; P].
2. **Start** (0x5FDC58), gdy budynek nie ma bieżącej pozycji: budynek ukończony; pierwsza pozycja; warunek gracza vt+0x54
   w trybie 2: `koszt_pop + populacja > 1 + a + b + globalny` → czekaj [W]. Czas := round(Build time × ulepszenie
   +0x94) [W; P: 28000].
3. **Odliczanie** (0x6394CD) co takt, gdy HP > 0 i gra nie stoi: licznik −= 34 ms (EEPhysics +0xA4) [W; P: stałe 34
   także w taktach 35 ms]. Przy ≤ 0 utworzenie jednostki; przy braku miejsca licznik := 5000 i ponowna próba [W].
4. **Utworzenie**: populacja += koszt populacji; pozycja bieżąca := brak; następna pozycja startuje w tym samym takcie
   [P].

Miejsce wyjścia [P: 4 jednostki AoC, 2 EE]: krawędź budynku y = Y − r, x = X + r + k·2r (r = 0,5·rozmiar; obywatel
0,15), kolejne wolne miejsce co 2r. Kurs nowej jednostki: −y (m01 = 0, m11 = −1). Reguła wolnego miejsca [H]; funkcja
tworzenia AoC 0x631B55 nieprzeczytana [N].

Wybór płci obywatela (przycisk produkuje 1451 Female Citizen albo 1074 Citizen) [N]: sekwencje AoC 1451, 1451, 1074,
1074, 1074; EE 1074, 1074; hipoteza wyrównywania płci obalona (678). Losowanie generatora przy kliknięciu: brak [P].
**[Etap 53 – zastąpione]** Płeć losuje **start pozycji**: wynik URandom ≥ 0,5 → Female Citizen – § 5.2 [W + P].

### 1.4. Dane (`dbtechtree`)

Schemat EE DB Editor (`dane/schemat_db_eedbeditor/AOC/dbtechtree.dats`): pola 7 Wood, 8 Stone, 10 Gold, 12 Iron,
13 Food cost, 14 Build time, 19 Object ID, 21 Is object?; przesunięcia wspólne EE i AoC (pola 0–36) [P: porównanie
658 par w etapie 11].

| Rekord (ID) | Obiekt | Koszt | Build time | Budują | EE = AoC |
|---|---|---|---|---|---|
| Citizen (1074) | 32 | 50 żywności | 28000 | 35, 41, 721 | tak |
| Female Citizen (1451) | 480 | 50 żywności | 28000 | 35, 41, 721 | tak |
| b House (1069) | 37 | 50 drewna, 40 kamienia | 35000 | 32, 480 | tak |
| b Barracks (1071) | 34 | 225 drewna | 45000 | 32, 480 | tak |

Dom i koszary potwierdzają wartości zmierzone w etapie 51 (koszt 660/674, K z +0x27C) [P]. Modyfikatory
cywilizacji i technologii kosztów – nieodczytane [N].

## 2. Implementacja OpenEE Core

- `ParametryProdukcji` (technologia, obiekt, koszt, czas, mnożnik, koszt populacji, parametry jednostki);
  `Swiat::ustaw_produkcje`, `rozkaz_produkcji`, `anuluj_produkcje`, `ustaw_populacje`, `populacja`, `limit_populacji`,
  `nowe_jednostki`.
- `Jednostka`: `prod_kolejka`, `prod_biezaca`, `prod_ms`.
- `krok_produkcji` – osobny przebieg po pętli fizyki (żywe budynki są poza kolejką fizyki), od końca listy; nowe jednostki
  dodawane po przebiegu na koniec listy.
- Losowania: start pozycji +1 [P obie gry] – **[Etap 53 – zastąpione]: tylko technologia obywatela (wybór płci), § 5.2**;
  utworzenie – `WariantTitan::losowania_utworzenia` (EE 3, AoC 1) [P: 679 / 677; 706 / 704]. To pierwszy jawny wariant mechaniki z etapu 52 (różnica kodu: EE tworzy jednostkę w 0x624DF8, AoC w osobnej
  0x631B55).
- Koszt i czas z `dbtechtree` przez importery (`EpokiDB.techtree` – pola `koszt`, `czas_ms`, `czy_obiekt`; Python
  `narzedzia/eeformaty/epoki.py`); w danych (`parametry_jednostek_ee.json → produkcja`) tylko mnożnik i koszt populacji.
- Nie odtworzono: wybór płci, wybór budynku o najkrótszej kolejce, limit kategorii 0x1B, ponowienie 5000 ms przy
  zajętym miejscu (jest, ale niezmierzone), punkt zbiórki, technologie bez obiektu.

## 3. Testy syntetyczne

CTest `produkcja` (4 sprawdzenia): obie gry – koszt, start 28000, 824 takty, wyjście, populacja, losowania; dwie pozycje;
brak zasobów, limit populacji, anulowanie. GDExtension `_test_etapu52` (4 wyniki).

## 4. Pomiar oryginalnej gry

| Zadanie | Gra | Wynik |
|---|---|---|
| 675/676 | AoC | panel Centrum Miasta (przycisk obywatela 830, 1260; skrót C), zasoby AoC +0xAFC… |
| 677 | AoC | 1 + 2 jednostki, nagrania `e52_677_jeden`, `e52_677_dwa` |
| 678 | AoC | brak zasobów (`e42_e52_brak`): odmowa bez zmian; limit glob. 100; płeć 1074 ×2 |
| 679 | AoC + EE | anulowanie – klik w ikonę kolejki (40, 1400) lewy/prawy bez skutku [N]; EE: 2 jednostki, nagranie `e52_679_ee` |

Zgodność Core (odtworzenie `opis_produkcji` + `odtworz_scenariusz.gd --wariant=…`, porównanie `porownaj_produkcje`):
677 jeden 1898/1898, 677 dwa 3101/3101 (pozycje wyjścia = gra po uwzględnieniu jednostki z poprzedniego przebiegu),
679 EE 2996/2996; nowe jednostki: czas (±1 próbka), typ, pozycja i kurs = gra; losowania w taktach produkcji = gra.

Niezmierzone: anulowanie (miejsce w interfejsie nieznalezione), limit populacji osiągnięty, zajęte miejsce wyjścia,
punkt zbiórki, produkcja w innych budynkach.

## 5. Integracja Godot

- `odtworz_scenariusz.gd`: `--wariant`, typy produkcji z `dbtechtree`, rozkaz `produkcja` po takcie, próbki `prod_<id>`,
  `populacja`, `nowe`.
- Potyczka `dane/potyczka/potyczka_e52_produkcja.json` (`demo_e52`): Centrum Miasta produkuje dwóch obywateli; raport
  co sekundę (pozycja, licznik, kolejka, zasoby, populacja) i lista nowych jednostek z modelem.

## 5. Etap 53 – produkcja wojskowa, płeć obywatela, anulowanie, punkt zbiórki

Główna wersja: AoC (`EE-AOC.exe` db8fc5ce…, proces testowy c636a2ab…), kontrola: EE (e352d7ae…, proces 846350a8…).
Scenariusz `e42_e53_koszary` (SCN 231, czysta mapa): ukończone koszary 34 gracza 1 (kotwica 164, 112; 2×2), obywatel,
zasoby 1111 / 1222 / 1333 / 1444 / 1555, populacja 1, brak AI w pobliżu. Ten sam plik w obu grach.

### 5.1. Produkcja wojskowa [P: AoC 704, 705, 709; EE 706, 710]

Pierwszy przycisk panelu koszar w obu grach: technologia **3011 „Inf03 - Maceman”** (obiekt dbobjects 21; skrót S).
Dane `dbtechtree` identyczne w EE i AoC: 30 żywności + 30 żelaza, Build time 32000 ms, budują 34 i 530. `dbobjects` 21:
HP 150, atak 13, prędkość 0,6, rozmiar 0,5, „Population count” 1 – identyczne w obu grach.

| Wielkość | AoC | EE |
|---|---|---|
| koszt | 30 żywności + 30 żelaza w próbce kliknięcia, także dla pozycji czekającej | to samo |
| licznik startowy | 32000 ms w próbce kliknięcia (budynek wolny) | to samo |
| odliczanie | −34 ms na takt; 942 takty na jednostkę | to samo |
| utworzenie | próbka z licznikiem 6 → 0; bieżąca := brak; populacja +1 | to samo |
| druga pozycja | start w takcie utworzenia pierwszej (licznik 32000, bez odliczenia w tym takcie) | to samo |
| miejsce | (164,25; 111,75), (164,75; 111,75), (165,25; 111,75): x = X + r + k·2r, y = Y − r, r = 0,25 | to samo |
| kurs | −y (m01 = 0, m11 = −1) | to samo |
| stan początkowy | 5000 (Idle), bez celu i trasy | to samo |
| losowania przy starcie | **0** | **0** |
| losowania przy utworzeniu | 1 | 3 |

- Mechanizm jest ten sam co dla obywatela (§ 1.3); jedyna różnica przebiegu to brak losowania przy starcie (§ 5.2).
- Różnica EE/AoC: tylko liczba losowań przy utworzeniu (znana z etapu 52, `WariantTitan::losowania_utworzenia`).
- Drugi przycisk panelu różni się **danymi**: AoC 3107 „x Gallic Warrior” (jednostka dodatku), EE 2024 „Inf02 -
  Spearman” [P: 709/710]. To zmiana zawartości bazy, nie mechaniki.
- Parametry ruchu jednostki z ulepszenia gracza nie były odczytywane; nowa jednostka stała, więc nie wpływają na wynik.

### 5.2. Losowanie przy starcie pozycji = wybór płci obywatela [W + P]

Start pozycji (AoC 0x5FDC58, EE 0x5EF9FF), po sprawdzeniu warunków gracza (vt+0x54):

- gdy technologia jest obiektem, a jej obiekt to dbobjects 32 (Citizen; AoC 0x5FDE00 `cmp [typ+0x1BC], 0x20`, EE
  0x5EFB91 `cmp [typ+0x4B8], 0x20`), funkcja woła `URandom::Generate` i porównuje wynik z 0,5 (AoC stała 0x838AAC, EE
  0x824AD0);
- przy wyniku ≥ 0,5 i dostępnej technologii obywatelki bieżącą pozycją zostaje technologia Female Citizen (id z typu
  obiektu obywatelki, pole +0x1E4);
- czas liczony jest z technologii z kolejki: 1 ms przy fladze gracza +0xB45, 2 ms przy fladze pozycji i technologii-
  obiekcie, inaczej round(Build time × ulepszenie +0x94) [W].

Pomiar: we wszystkich 7 startach obywatela z nagrań 677–679 ostatnie losowanie taktu startu rozstrzyga płeć zgodnie z
regułą (0,83 → 1451; 0,60 → 1451; 0,58 → 1451; 0,39 → 1074; 0,09 → 1074; EE 0,33 → 1074; 0,18 → 1074) [P]. Start
jednostki wojskowej nie losuje (10 startów: 5 AoC, 5 EE) [P]. Kolejka przechowuje technologię przycisku (1074), płeć
ustala się dopiero przy starcie.

### 5.3. Anulowanie [P: AoC 705, 709; EE 706, 710] + [W: AoC 0x5FD984, 0x5FD8F3, komunikat 0x4C47xx]

Sposób wskazania: **prawy przycisk myszy na przycisku technologii** w panelu budynku. Ikon pozycji kolejki nie ma –
kliknięcia w lewy dolny róg z etapu 52 trafiały w tło panelu.

- 0x5FD984 (technologia, flaga „wszystkie” = 0): przegląd kolejki od początku; pasuje ta sama technologia albo para
  1074/1451 (0x6414D2). **Pierwsza** pasująca pozycja jest usuwana, pozostałe zachowują kolejność [W; P: kolejka
  [3011, X, 3011] → [X, 3011] w obu grach].
- Gdy w kolejce nie ma tej technologii, a bieżąca pozycja pasuje – 0x5FD8F3: bieżąca := brak, licznik := 0 [P].
- Gdy bieżąca jest inną technologią – nic się nie zmienia [P: 709/710, trzeci PPM].
- Zwrot: pełny koszt (mnożnik 1,0, gracz vt+0x44) w takcie kliknięcia, także po 12,7 s produkcji [P].
- Populacja i generator bez zmian [P]. Licznik rezerwacji klasy 0x1B (+0xB2C) maleje tylko dla tej klasy [W].
- Następna pozycja nie startuje w funkcji anulowania; rusza w aktualizacji budynku [W]. Chwila startu po anulowaniu
  bieżącej pozycji przy niepustej kolejce nie została zmierzona [N].
- EE i AoC: ten sam przebieg we wszystkich zmierzonych krokach.

### 5.4. Punkt zbiórki [P: AoC 705, EE 706] – rozpoznany, **nieodwzorowany w Core**

- Ustawienie: budynek zaznaczony, PPM w teren. Punkt trafia jako `EEUGLocation` (pochodzenie 1) do **drugiego poziomu**
  kolejki celów budynku z dokładnym miejscem kliknięcia, np. (168,957; 115,813). Zapis natychmiast, przed produkcją.
- Obowiązuje dla kolejnych jednostek z kolejki (2 z 2).
- Nowa jednostka powstaje w innym miejscu niż bez punktu zbiórki: (166,25; 114,25) – narożnik budynku od strony punktu
  (X + n + r; Y + n + r) – zamiast (164,25; 111,75). Druga jednostka – to samo miejsce (pierwsza już odeszła).
- Kurs początkowy: kierunek od miejsca powstania do punktu kliknięcia (AoC 30,0°, EE 29,0° – kliknięcia różniły się o
  0,05 pola).
- Stan początkowy 8000 z celem `EEUGLocation` (pochodzenie 1); w kolejnych taktach 2015 → 10003 → … → 5000.
- Cel jednostki to nie punkt kliknięcia, tylko miejsce w polu punktu: pierwsza (168,25; 115,25), druga
  (168,25; 115,75) – odstęp 2r.
- Reguła wyboru miejsca powstania i kolejnych miejsc docelowych: jeden układ – [H: najbliższe miejsce obwodu; kolejne
  ćwiartki pola]. Bez drugiego układu nie implementuję.

### 5.5. Zmiany Core (etap 53)

- `ParametryProdukcji::losowy_zamiennik` – start losuje tylko dla technologii z zamiennikiem; wynik ≥ 0,5 → zamiennik
  (dane: `parametry_jednostek_ee.json → produkcja → 1074 → losowy_zamiennik = 1451`). [Zastąpione: losowanie przy
  każdym starcie.]
- `Swiat::anuluj_technologie(budynek, tech)` – reguła 0x5FD984 / 0x5FD8F3; `anuluj_produkcje(budynek, indeks)` bez zmian.
- Jednostka z produkcji: parametry z pomiaru albo z rekordu `dbobjects` (`godot/silnik/symulacja/parametry_typow_db.gd`:
  a, vmax, α, ωmax, rozmiar, c4 = 1/a, c8 = 1/α; HP, atak, pancerze, zasięg, pole widzenia, przeładowanie, klasy
  trafień). Reguły dają dokładnie wartości zmierzone dla 422, 32, 216, 173; koszt populacji z „Population count”.
  Nie ma kodu ani wpisu danych specjalnie dla jednej jednostki wojskowej poza mnożnikiem czasu 3011.
- GDExtension: `ustaw_produkcje` (pole `losowy_zamiennik`), `anuluj_technologie`.

### 5.6. Zgodność Core z nagraniami (odtworzenie `opis_produkcji` → `odtworz_scenariusz.gd --od-startu=0`)

| Nagranie | Gra | Stan produkcji (bieżąca, licznik, kolejka, zasoby, populacja) | Nowe jednostki | Losowania |
|---|---|---|---|---|
| 704 jeden | AoC | 2646/2647 + 1 próbka nieaktualna rejestratora | (rejestrator bez nowych jednostek) | 2/2 taktów |
| 704 dwa | AoC | 4984/4984 | – | 3/3 |
| 705 anulowanie | AoC | 1008/1008 | – | 2/2 |
| 709 nowa | AoC | 1967/1967 | 1/1: Δt 0 taktów, typ, pozycja, kurs, stan | 2/2 |
| 706 jeden | EE | 2387/2387 | 1/1 | 2/2 |
| 706 dwa | EE | 3920/3920 | 2/2 | 3/3 |
| 706 anulowanie | EE | 860/860 | – | 2/2 |
| 677 jeden (obywatel) | AoC | 1897/1897; płeć z generatora (`--rng-nagranie`) = gra (1451) | typ 480 | 2/2 |
| 677 dwa | AoC | 3170/3170; płeć 1451, potem 1074 = gra | typy 480, 32 | 3/3 |
| 679 | EE | 2995/2995; płeć 1074, 1074 = gra | typy 32, 32 | 3/3 |

- Pierwsza rozbieżność: brak w każdym nagraniu. Próbka nieaktualna 704 (t = 181133): rejestrator zwrócił stan z
  poprzedniego taktu, następna próbka znów zgodna.
- Nagrania 705/706 „zbiórka” nie są odtwarzane (punkt zbiórki nieodwzorowany).
- Liczby 677/679 różnią się od etapu 52 (1898, 3101, 2996), bo porównanie idzie teraz po numerze taktu, a nie po
  czasie (§ 5.7); 677 „dwa” obejmuje całe nagranie.

### 5.7. Zegar gry powyżej 524 288 ms [P]

Czas gry (EEPhysics +0xD0) rośnie o 1500/44 = 34,0909 ms na takt tylko poniżej 524 288 ms. Powyżej tej wartości
przyrost wynosi 34,0625 ms (16 taktów po 34 ms na 1 takt 35 ms), w tym samym nagraniu po obu stronach granicy
(`e52_677_dwa`: 34,0935 → 34,0627; 705: 34,0625). [H]: zegar jest liczbą f32, a 1/16 ms to kwant f32 w przedziale
[2^19, 2^20). Licznik produkcji tego nie widzi (odejmuje stałe 34). Skutek dla narzędzi: próbki i rozkazy są
dopasowywane po numerze taktu (`takt_przed`, `koniec_takt` w opisie; `--od-startu=0`), bo czas rozjeżdża się z siatką
Core o 0,03 ms na takt. Zob. `precyzja_numeryczna.md`.

### 5.8. Niezmierzone

Limit populacji osiągnięty w grze (start czekający na miejsce), zajęte miejsca wyjścia (ponowienie 5000 ms), wybór
budynku o najkrótszej kolejce, produkcja z Shift (5 sztuk), technologie bez obiektu (ulepszenia), produkcja w innych
budynkach niż Centrum Miasta i koszary, punkt zbiórki na obiekcie.

