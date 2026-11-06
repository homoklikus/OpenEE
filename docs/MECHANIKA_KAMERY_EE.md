# Mechanika kamery – Empire Earth 1 / The Art of Conquest

Etap 10 OpenEE. Zebrane tu zachowanie **oryginalnej gry** zmierzono przed zmianą kamery OpenEE. Dokument rozszerza
`RAPORT_KAMERA_EE_OPENEE.md` (pierwsze badanie kamery). Wcześniejsze ustalenia sprawdziłem ponownie, a pozycje
oznaczone tam jako nieznane uzupełniłem.

**Środowisko.** EE: The Art of Conquest (wydanie GOG), Wine/DXVK, RTX 5090, okno 3440×1440 (obszar mapy 3440×1302).
Mapy:
- Riverlands 100×100 (`etap9_pasy.scn`) i 150×150 (`etap10_kamera_150.scn`);
- scenariusz kampanii „Wojna trojańska” (teren górzysty).

**Metoda.**
- Odczyt pamięci procesu, tylko odczyt: macierz kamery `0x930D5C`, ognisko `0x931750`, odległość `0x931780`, poziom
  zoomu `0x9317F0`, kopie macierzy w buforach renderera, pozycja kursora gry.
- Zwykłe wejście: klawisze, kółko, ruch myszy (xdotool, ruch względny).
- Narzędzia MCP `ee_kamera` (`kam_*`), opis w `Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` § 14.
- Wyniki zadań 146–159 w `Testy_MCP/ee_zadania/*.wynik.json` (lokalnie).
- Nie zapisywano niczego do pamięci gry i nie modyfikowano gry.

**Oznaczenia:**
- **[P]** potwierdzone powtarzalnymi pomiarami;
- **[W]** wniosek z ograniczonych pomiarów;
- **[H]** przybliżenie przyjęte w OpenEE;
- **[N]** nieustalone.

Jednostka długości: **pole** (siatka pozycji EE, mapa N×N ma romb pól o przekątnej 2N).

## 1. Orientacja

| Pytanie | Wynik | Pewność |
|---|---|---|
| Obrót wokół osi pionowej w rozgrywce | Brak. Azymut 135° (kierunek patrzenia (−1, +1)/√2) nie zmienił się w żadnym pomiarze: strzałki, kółko, kółko z Shift/Ctrl/Alt, przeciąganie środkowym przyciskiem (także z Ctrl/Alt), krawędzie ekranu, 3 mapy. | [P] |
| Skrót do obrotu lub zmiany pochylenia | Nie znaleziono. Badano: Q/E, Prior/Next/Home/End/+/− (etap kamery), kółko z modyfikatorami, przeciąganie środkowym przyciskiem z modyfikatorami. | [P] dla zbadanych |
| Pochylenie | 35° w dół, stałe, także przy każdym poziomie zoomu. | [P] |
| Zależność od trybu i scenariusza | **Przerywniki filmowe scenariusza używają własnej kamery.** Wstęp „Wojny trojańskiej”: azymut od −55° do 166°, pochylenie od −3° do 31°, zmiany bez wejścia gracza. Esc pomija przerywnik, a kamera rozgrywki wraca do 135°/35°. | [P] |

W rozgrywce kamera gracza ma więc stałą orientację. Zmienną orientację ma tylko skryptowana kamera przerywników.
Przerywniki nie należą do zakresu etapu.

## 2. Przybliżanie i oddalanie

| Pytanie | Wynik | Pewność |
|---|---|---|
| Liczba poziomów | 21 (poziom 0 = najbliżej, 20 = najdalej). Scenariusz startuje na poziomie 20. | [P] |
| Odległość oko–ognisko | 29,7 na poziomie 20, krok 1,49 na poziom, poziom 0 = 0,1 (oko ≥ 0,4 nad ziemią). | [P] |
| Kółko | Jedno kliknięcie = jeden poziom. W górę przybliża, w dół oddala. | [P] |
| Płynność | Skokowa. Stan gry **i kopie macierzy renderera** mają nową wartość już w pierwszej próbce (19 ms) po kliknięciu, także dla 4 kliknięć co 30 ms. Wygładzania obrazu nie zaobserwowano (wcześniej [N]). | [P] |
| Co się zmienia | Tylko odległość wzdłuż osi widoku. Ognisko, azymut, pochylenie i kąt widzenia stoją. | [P] |
| Punkt pod kursorem | Nie wpływa na zoom. Kursor w 4 miejscach (rogi i środek kadru): ognisko bez zmian (różnica 0,0000). | [P] |
| Modyfikatory | Kółko z Shift, Ctrl lub Alt działa jak bez modyfikatora. | [P] |

## 3. Przesuwanie kamery

### 3.1. Strzałki

**Prędkość** = 15 + 30·(poziom/20) pól/s. Zmierzone 14,6 / 29,4 / 44,0 przy poziomach 0 / 10 / 20, w 4 kierunkach.
Próbki zbierane w trakcie trzymania klawisza dają wynik ~2% niżej z powodu opóźnienia odczytu. Wcześniejszy pomiar
z przesunięcia całkowitego: 15 / 30 / 45. [P]

**Kierunki:**
- prawo ekranu = mapa (+1, +1)/√2;
- strzałka w górę = (−1, +1)/√2, czyli kierunek patrzenia.

[P]

**Dwie strzałki:**
- Wektory się sumują i nie są normalizowane. Góra + prawo dały 41,4 pola/s, a 29,4·√2 = 41,6. [P]
- Przeciwne strzałki się znoszą. [P]

**Rozpędzanie i wybieg:** brak, prędkość jest stała od pierwszej klatki. [P]

### 3.2. Krawędź ekranu (mysz)

Strefy krawędziowej o stałej szerokości **nie ma**. Kursor gry stojący 0, 1, 2, 3, 5, 8, 15 lub 30 px od krawędzi
nie przesuwał kamery. Sprawdziłem to na 4 krawędziach i przy 3 poziomach zoomu. [P]

Przewijanie włącza dopiero **ruch myszy na zewnątrz okna, gdy kursor stoi już na krawędzi**. Kursor gry jest
wtedy zatrzymany na krawędzi, a gra dostaje dalszy ruch względny. [P]

Jak działa po włączeniu:
- Wielkość tego ruchu nie ma znaczenia: wynik jest ten sam przy 2, 6 i 20 jednostkach co 50 ms. [P]
- Po włączeniu przewijanie trwa, dopóki kursor zostaje na krawędzi, także bez dalszego ruchu myszy. [P]
- Ustaje po ruchu kursora do wnętrza okna (≥ 3 jednostki, czyli ~5 px). [P]
- Prędkość wynosi **5/6 prędkości strzałek**: 12,6 / 24,9 / 37,2 pola/s przy poziomach 0 / 10 / 20 (wobec
  12,5 / 25 / 37,5). [P – 3 poziomy, krawędzie prawa i górna]
- Kierunki są jak dla strzałek: prawa krawędź = prawo, górna = w górę ekranu. [P – 4 krawędzie]

**Przeciąganie ramki zaznaczenia (LPM)** blokuje przewijanie krawędzią: przy kursorze na krawędzi i przy pchaniu
na zewnątrz kamera stoi. [P – krawędzie prawa, lewa, górna]

### 3.3. Środkowy przycisk myszy (nowe ustalenie)

Przytrzymanie środkowego przycisku i ruch myszą **przesuwa kamerę**. To mechanika EE nieopisana w poprzednim
badaniu. [P]

| Cecha | Wynik | Pewność |
|---|---|---|
| Kursor | Zatrzymany w miejscu na czas przeciągania. | [P] |
| Kierunek | Ten sam co ruch myszy: mysz w prawo → kamera w prawo (obraz odjeżdża w lewo), mysz w dół → kamera w dół ekranu. | [P] |
| Wielkość | Δ pól = Δ jednostek myszy × prędkość strzałek(poziom) / 640: 0,0235 / 0,0469 / 0,0703 pola na jednostkę przy poziomach 0 / 10 / 20. Proporcja liniowa (100–400 jednostek), taka sama w poziomie i w pionie, niezależna od liczby kroków ruchu (±5%). | [P] |
| Bezwładność | Brak. Przy przytrzymaniu bez ruchu kamera stoi (dryf 0,000). | [P] |
| Modyfikatory | Ctrl i Alt bez wpływu. | [P] |

„Jednostka myszy” to ruch względny przekazany do gry (DirectInput pod Wine). Dla porównania ta sama jednostka
przesuwa kursor gry o ~1,75 px w poziomie i ~1,09 px w pionie. Jak ma się to do fizycznej myszy (czułość systemu,
mickeys) – [N].

### 3.4. Granice mapy

Ognisko jest ograniczone do rombu pól: u = x + y ∈ [N, 3N] oraz v = x − y ∈ [−N, N].
- Zmierzone dla N = 100 i N = 150: kamera dochodzi dokładnie do narożników rombu, na przykład (150, 300) i (0, 150)
  dla N = 150. [P]
- Na granicy kamera staje, bez odbicia. [P]

### 3.5. Wysokość ogniska (teren)

- Ognisko leży **0,4 nad terenem i nadąża za wysokością**. „Wojna trojańska”, 8 punktów, wysokości 0–4,3: z ogniska
  od 0,4 do 4,33, oko przesuwa się razem z nim. [P]
- Nad terenem poniżej zera (woda, depresje) z ogniska = 0,4, czyli **wysokość jest ograniczona od dołu do 0**
  (3 punkty). [P]
- Wysokość terenu EE w porównaniu z interpolacją dwuliniową OpenEE (`MapaNawigacji.wysokosc`): w 1 punkcie
  identyczna, w 4 punktach wyższa o 0,07–0,23. EE najpewniej wygładza teren albo inaczej wybiera wierzchołki;
  dokładna reguła – [N]. [W]

## 4. Geometria widoku

| Cecha | Wynik | Pewność |
|---|---|---|
| Rzut | Perspektywiczny. Wielkość obiektów maleje odwrotnie proporcjonalnie do odległości. | [P] (pierwsze badanie) |
| Kąt widzenia | Poziomy ≈ 50,4° przy 3440×1440 (ogniskowa ~3650 px). | [W] |
| Kąt przy innych proporcjach okna | Zmiana rozdzielczości wymagałaby zmiany ustawień gry użytkownika. | [N] |
| Kierunek patrzenia względem siatki | Wzdłuż przekątnej pól (azymut 135°), więc wiersze i kolumny biegną ukośnie na ekranie. | [P] |
| Wielkość obiektów a wysokość terenu | Wynika z perspektywy i nadążania ogniska (§ 3.5): obiekt na wzgórzu jest bliżej oka, gdy ognisko leży niżej. Osobnego skalowania nie znaleziono. | [W] |

## 5. Parametry dla OpenEE

| Parametr | Wartość | Pewność |
|---|---|---|
| Azymut, pochylenie | 135°, 35°, stałe | [P] |
| Poziomy zoomu, odległości, skok | 21, 0,1 … 29,7, krok 1,49, natychmiast | [P] |
| Zoom a kursor | Bez wpływu | [P] |
| Prędkość strzałek | 15 + 30·p/20 | [P] |
| Ukos | Suma wektorów | [P] |
| Krawędź | Włączenie pchaniem poza krawędź, wyłączenie ruchem do środka, prędkość 5/6 strzałek, zablokowana przy ramce | [P] |
| Środkowy przycisk | Δ pól = Δ myszy × prędkość/640, w kierunku ruchu, kursor zatrzymany | [P] |
| Przelicznik piksela Godota (ruch względny) na jednostkę myszy EE | 1 : 1 | [H] |
| Granice | Romb pól | [P] |
| Wysokość ogniska | max(0, h) + 0,4 | [P]; h z interpolacji dwuliniowej OpenEE – [W] (EE wyżej o ≤ 0,23) |
| Kąt widzenia | 50,4° w poziomie przy stałej szerokości | [W]; inne proporcje [N] |
| Przerywniki filmowe | Poza zakresem | – |

## 6. Ograniczenia MCP i pomiarów

- Ruch myszy pochodzi z xdotool (ruch względny przez XWayland/Wine). Fizyczną mysz można porównać tylko pośrednio
  (§ 3.3).
- Rozdzielczość okna stała (3440×1440). Kąt widzenia przy innych proporcjach – [N].
- Kontrola stanu klawiszy w serwerze X działa od poprawki fazy A (XAUTHORITY). Stan klawiszy w Wine sprawdzam
  pośrednio, przez dryf kamery.
- Scenariusze kampanii: wczytanie przez menu wymaga kliknięcia „Odprawy”. Ekrany menu są w układzie 1920×1080
  z pasami po bokach na oknie 21:9.
