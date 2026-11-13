# Produkcja jednostek w budynkach (etap 52)

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
- Losowania: start pozycji +1 [P obie gry]; utworzenie – `WariantTitan::losowania_utworzenia` (EE 3, AoC 1) [P: 679 /
  677]. To pierwszy jawny wariant mechaniki z etapu 52 (różnica kodu: EE tworzy jednostkę w 0x624DF8, AoC w osobnej
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
