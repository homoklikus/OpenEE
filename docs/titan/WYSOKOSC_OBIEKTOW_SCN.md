# Wysokość obiektów w scenariuszach SCN (etap 54)

Dlaczego obiekty na mapach testowych lewitowały, co gra robi z wysokością obiektu i jak poprawiono generator.
Oznaczenia: [P] pomiar w grze, [W] analiza kodu albo danych, [H] hipoteza, [N] nieustalone.

**Wynik w skrócie**

- Przyczyna leży w generatorze map testowych, nie w grze: kopiował rekord jednostki wzorcowej razem z jej wysokością
  z miejsca wzoru i zmieniał tylko x i y [W].
- Gra **nie osadza obiektu na terenie przy wczytaniu scenariusza**. Wysokość z rekordu obowiązuje, dopóki obiekt nie
  wykona kroku ruchu [P: AoC i EE].
- Jednostka wraca na teren w pierwszym takcie po rozkazie; budynek nigdy, bo się nie rusza [P].
- Jednostka utworzona przez produkcję dostaje wysokość terenu od razu, także z lewitujących koszar [P + W].
- Generator ustawia teraz wysokość kopii z terenu nowego miejsca. Sprawdzone w AoC i w EE: liczbowo i na zrzutach
  ekranu [P].

## 1. Gdzie rekord trzyma pozycję

Rekord obiektu złożonego w kawałku 5 (gramatyka: `narzedzia/eeformaty/gracze.py`):

| Pole | Zawartość | Uwagi |
|---|---|---|
| `X`, `Y` (i32) | pole kotwicy obiektu | budynek n × n: lewy dolny róg |
| `pos.x`, `pos.y`, `pos.z` (f32) | 0 we wszystkich zbadanych rekordach | generator ich nie zmienia; gra ustawia jednostkę według macierzy [P] |
| `transform` (64 B) | macierz 4 × 4 f32 wierszami; translacja = elementy 3, 7, 11 | **x, y, z świata** |

- z w macierzy jest **bezwzględne** (wysokość świata), nie względne do terenu [W].
- Dowód z kampanii (scenariusz źródłowy wzorów, 3 → 234 obiektów na typ): z − teren w punkcie obiektu jest stałe dla
  typu.

| Rodzaj obiektu | z − teren |
|---|---|
| jednostki lądowe (obywatel 32, gwardia 422, typy 37, 136, 480) | 0,000 (pojedyncze odchyłki do 0,09 na stokach) |
| budynki 34, 35, 39, 41, 52, 54, 62, 64 | +0,010 |
| mury i bramy 42, 454, 462, 467, 468, 473 | +0,001 |
| okręty i obiekty na wodzie (110, 111, 115, dok 36) | z = 0 przy terenie ujemnym (dno) |

- Wysokość terenu: ten sam wzór co `GETerrainMesh::GetMeshZ` (`fizyka_terenu.md` § 1) na wierzchołkach kawałka 4.
  Wartości kawałka 4 są już w jednostkach świata (kwant 0,204).

## 2. Skąd wzięła się lewitacja

`narzedzia/eksperymenty/scenariusz_testowy_kolizji.py` (wołany przez `scenariusze_czyste.py`) kopiował rekord wzoru
bajt w bajt i zmieniał: identyfikator, `X`, `Y`, translację x i y macierzy. Element 11 (z) zostawał z miejsca wzoru [W].

| Wzór | Miejsce wzoru | z wzoru | Skutek na mapie testowej (teren 0) |
|---|---|---|---|
| obywatel `CIT` | (180,5; 110,5), teren 1,021 | 1,021 | 1,02 nad ziemią |
| gwardia `GRD` (także taran: typ podmieniony na 102) | (176,9; 125,5), teren 1,837 | 1,837 | 1,84 nad ziemią |
| koszary `BARR` | (173; 122), teren 1,837 | 1,847 | 1,85 nad ziemią |
| dom `BLD` | (182,5; 113,5), teren 1,021 | 1,021 | 1,02 nad ziemią |

- Stąd „Z stojącej jednostki około 1,837” z eksperymentu Fable: to wysokość terenu pod wzorem gwardii, nie przesunięcie
  modelu.
- Skala: 66 z 69 map testowych (`e42_*`, `fable_*`) miało obiekty poza terenem – 275 z 292 obiektów graczy, największa
  różnica 1,847 [W: `wysokosc_obiektow.py scn`].
- Na płaskowyżu 1,84 (x 169–179, y 118–125) gwardia stała przypadkiem poprawnie – dlatego problem nie był widoczny we
  wszystkich układach.

## 3. Co robi gra [P: AoC 711, EE 712 + nagrania etapów 53 i Fable]

Scenariusz `e42_e54_wysokosc`: obywatel, taran (102) i koszary w trzech miejscach – płasko z = 0, płaskowyż z = 1,02,
stok – w trybie poprawionym, oraz ten sam zestaw w starym trybie obok. Rejestracja co takt, 260 s.

| Zdarzenie | Jednostka lewitująca (stary tryb) | Wynik |
|---|---|---|
| po wczytaniu | obywatel z 1,0206 nad terenem 0; taran 1,8371; koszary 1,8471 | z z rekordu, bez korekty |
| takty bez rozkazu | obywatel: 3741 próbek AoC (3902 EE) bez zmiany z; taran i koszary: całe nagranie | bez korekty |
| rozkaz ruchu | obywatel: z = 0 w pierwszej próbce stanu 10003; x, y jeszcze (162,501; 110,501) | korekta w pierwszym kroku ruchu |
| taran po rozkazie (Fable 2, 5 taranów × 2 gry) | z = teren w pierwszej próbce 10003, przed zmianą x, y | to samo |
| produkcja w lewitujących koszarach | nowa jednostka z = 0,000 = teren od pierwszej próbki | wysokość z terenu przy utworzeniu |
| koszary przed produkcją i po niej | 1,8471 bez zmiany | budynek nie jest osadzany |
| budynek postawiony w grze przez obywatela (707, 717) | dom z = 0,000; koszary z = 0,826 na stoku | wysokość z terenu przy postawieniu |

Odpowiedzi na pytania o chwilę korekty:

| Chwila | Korekta wysokości |
|---|---|
| inicjalizacja obiektu ze scenariusza | **nie** [P] |
| pierwszy takt fizyki bez ruchu | **nie** [P] |
| rozpoczęcie ruchu | **tak** – pierwszy krok fizyki w trybie ruchu [P] |
| każda zmiana pozycji | **tak** – z = GetMeshZ w każdym kroku (`fizyka_terenu.md` § 4 pkt 7) [P: różnica 0 przez cały ruch, także na stoku] |
| utworzenie jednostki przez produkcję | **tak** [P + W] |

AoC i EE zachowują się tak samo we wszystkich wierszach (te same wartości z; różnią się tylko czasy rozkazów).

## 4. Funkcje Titan [W]

| Rola | AoC | EE |
|---|---|---|
| wysokość terenu w punkcie (woła `GetMeshZ` z DLL) | 0x4C0894 | 0x4C0201 |
| krok ruchu: z = wysokość po przesunięciu | wywołania 0x55A2B3, 0x55A668, 0x55A977 | 0x54D986, 0x54DD21, 0x54E01B |
| miejsce nowej jednostki przy budynku (produkcja): z z terenu | 0x643561, wywołanie 0x6438F1 | 0x62E201, wywołanie 0x62E54B |
| wczytanie obiektu ze scenariusza (`EEComplexUnit::Load`) | czyta macierz bez wywołania wysokości | to samo |

- Funkcję wysokości woła 39 miejsc w każdej grze; przejrzane są tylko powyższe. Miejsce stawiania budynku przez
  gracza – nieodczytane [N]; pomiar pokazuje wysokość terenu w środku budynku (+0,01 dla wzoru kampanii).

## 5. Poprawka generatora

`scenariusz_testowy_kolizji.py` – nowa reguła wysokości kopii (domyślna, `"z_tryb": "teren"`):

```
z kopii = teren(nowe x, y) + (z wzoru − teren(x, y wzoru))
```

- Przesunięcie wzoru nad terenem zostaje (budynek +0,01, mur +0,001, jednostka 0). Nie ma stałej korekcyjnej ani
  ustawiania z = 0.
- Wzór pływający (teren pod wzorem < 0, z ≥ 0 – okręt, dok) zachowuje z bezwzględne. Nowe miejsce musi być wodą,
  inaczej błąd.
- Wzór, który sam nie stoi na terenie (różnica ponad 0,05 – jednostka powietrzna albo zamierzone przesunięcie), jest
  odrzucany z komunikatem. Trzeba podać `"z"` albo `"z_tryb": "wzor"`.
- `"z"` w grupie nadal ustawia wysokość wprost; `"z_tryb": "wzor"` daje stare zachowanie.
- `scenariusze_czyste.py`: `z_tryb_wariantów` w `dane/testy_walki/e42_warianty.json`. Warianty sprzed etapu 54 mają
  `"*": "wzor"` – mapy wcześniejszych nagrań da się odtworzyć bajt w bajt. Nowe warianty (`e54_*`) mają `"teren"`.
  Pojedyncza grupa może mieć własny tryb (`"_z_tryb"`).
- Fizyka Core nie została zmieniona.

Walidacja:

- `narzedzia/titan/wysokosc_obiektow.py scn PLIK.scn` – lista obiektów graczy z |z − teren| > 0,05 (ćwierć kwantu
  terenu), kod wyjścia 1. Obiekty na wodzie i obiekty Świata nie są zgłaszane.
- `… statystyka PLIK.scn` – rozkład różnicy według typu; `… nagranie NAGRANIE.json PLIK.scn` – odcinki różnicy
  z − teren każdej jednostki nagrania.
- Testy: `narzedzia/titan/test_titan_narzedzia.py`, klasa `WysokoscObiektow` (interpolacja, lista podejrzanych, kopia
  na terenie i na stoku, wzór pływający, wzór lewitujący).

## 6. Wynik w grze [P]

Poprawione scenariusze: `e42_e54_wysokosc` (9 obiektów w trybie „teren”), `e42_e54_zbiorka` (koszary, obywatel,
taran), `e42_e54_kamien`.

| Obiekt (tryb „teren”) | z po wczytaniu = teren | AoC 711 | EE 712 |
|---|---|---|---|
| obywatel, płasko 0 / płaskowyż / stok | 0,000 / 1,021 / 0,630 | różnica 0 przez całe nagranie, także w ruchu | to samo |
| taran 102, płasko 0 / płaskowyż / stok | 0,000 / 1,021 / 1,105 | różnica 0 | to samo |
| koszary, płasko 0 / płaskowyż / stok | 0,010 / 1,031 / 0,418 | +0,01 bez zmiany | to samo |
| jednostka z produkcji (3 koszary) | 0,000 / 1,021 / 0,408 | = teren | to samo |

- Zrzuty ekranu: w AoC (713, `e42_e54_zbiorka`) i w EE (712, `e42_e54_wysokosc`) koszary, obywatel i taran w trybie
  „teren” stoją na ziemi – pierścień zaznaczenia u podstawy, cień przy obiekcie. Obiekty w starym trybie w tym samym
  scenariuszu wiszą nad swoim cieniem (AoC 711, EE 712).
- Kryterium etapu (koszary, zwykła jednostka i taran na powierzchni bez rozkazu ruchu) – spełnione dla terenu
  płaskiego w obu grach.

## 7. Ograniczenia

- **Budynek na stoku:** generator bierze wysokość terenu w środku budynku (jak budynek postawiony w grze: 0,826 dla
  koszar 717). Czy gra przy stawianiu wyrównuje teren albo liczy inną wysokość dla dużych budynków – niezbadane [N].
  Zrzut koszar na stoku nie był oceniany.
- **Pochylenie:** kopia zachowuje część obrotową macierzy wzoru. Wzór stojący na stoku przeniesiony na płaski teren
  będzie pochylony do pierwszego ruchu; wzory używane w testach stoją płasko.
- **Jednostki powietrzne i podwodne:** bez reguły – wymagają jawnego `"z"`.
- **Obiekty Świata (gracz 0)** nie są dodawane przez generator i nie są walidowane.
- Stare mapy testowe nie zostały przegenerowane (nagrania etapów 42–53 powstały na nich). W Core wysokość jednostki
  i tak pochodzi z terenu, więc odtworzenia nie zależą od z rekordu.
- Kliknięcia rozkazów w zadaniach MCP: punkt na ekranie liczony z wysokości podanej w zadaniu; przy obiektach
  w starym trybie trzeba było podawać wysokość terenu, nie z rekordu (obserwacja z eksperymentu Fable). Na
  poprawionych mapach obie wartości są równe.
