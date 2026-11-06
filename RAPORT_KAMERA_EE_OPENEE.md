# Kamera oryginalnego Empire Earth i jej odtworzenie w OpenEE

Data: 2026-11-06. Punkt wyjścia: `main` `e5895f9` (lokalnie przed `c3d717d` na GitHubie o jeden commit).
Środowisko: Debian 13, KDE Wayland, RTX 5090 (sterownik 620.70.06, Vulkan 1.4.357), Godot 4.7.2,
EE: The Art of Conquest (Lutris/Wine, DXVK), okno 3440×1440. Mapa pomiarowa: Riverlands 100×100 (generator Riverlands,
kopia w `Data/Scenarios` jako `000_EETEST_kamera.scn`, usunięta po testach).

Oznaczenia: **[Z]** zmierzone, **[W]** wnioskowane z pomiarów, **[N]** nieznane (wartość robocza).

Instalacja gry pozostała tylko do odczytu. Nie modyfikowano EXE ani DLL i nie zapisywano niczego do pamięci procesu.
Nie kopiowano też kodu z dekompilacji. Grą sterowało się wyłącznie zwykłym wejściem: strzałkami, kółkiem i ruchem
myszy, w kontrolowanej sesji testowej. Pomiary pochodzą z odczytu pamięci przez `/proc/<pid>/mem`. Narzędzia opisuje
`Riverlands_MCP/RAPORT_ROZBUDOWA_EE_MCP.md` (§ 9).

## 1. Jak mierzono

1. **Znalezienie kamery w pamięci.** Porównywałem migawki wszystkich zapisywalnych regionów procesu (około 247 MB
   każda) przed ruchem kamery i po nim: przesunięcie strzałką i kliknięcie kółka. Wartości, które zmieniały się zgodnie
   z ruchem, wskazały blok kamery w obiekcie świata (`0x930D40`), czyli w tym samym obiekcie, z którego
   `ee_api.GRA_STAT` czyta stan gry. Wynik:
   * macierz kamera→świat 3×4 pod `0x930D5C`, kolumny: prawo, przód, góra, oko;
   * oko pod `0x930D9C`;
   * ognisko pod `0x931750`;
   * odległość pod `0x931780` (ze znakiem minus);
   * poziom zoomu 0..1 pod `0x9317F0`.

   Kopie macierzy i macierz widoku leżą w buforach renderera (`0x8E8FC0`, `0x928E40`, `0x9309A0`). Wartość `0,7854`
   pod `0x928D64` okazała się **nie** być używanym kątem widzenia (§ 2.6).
2. **Zakres i charakter zoomu.** 22 kliknięcia w dół i 40 w górę, z odczytem po każdym. Osobno seria odczytów co
   około 10 ms po pojedynczym kliknięciu.
3. **Przesuwanie.** Strzałka przytrzymana 1 s i 3 s przy poziomach zoomu 0, 0,5 i 1. Mierzone przesunięcie ogniska.
4. **Granice.** Strzałki przytrzymane 6–9 s w każdą stronę, aż ognisko przestało się zmieniać.
5. **Kąt widzenia.** Użyłem dwóch niezależnych metod.
   * Przesunięcie obrazu budynku przy znanym przesunięciu kamery, w poziomie i w pionie, ze zrzutów okna.
   * Porównanie wielkości tego samego modelu (centrum miasta z prehistorii) w EE i w OpenEE. Ognisko i odległość były
     te same, sprawdzałem hipotezy 45° i 50,4°.

## 2. Wyniki

| # | Pytanie | Wynik | Status |
|---|---|---|---|
| 1 | Azymut stały czy obracany | **Stały.** Kierunek patrzenia w płaszczyźnie mapy to (−1, +1)/√2 (azymut 135° od osi x). Prawo ekranu to (+1, +1)/√2, a strzałka w górę prowadzi w (−1, +1). Klawisze Prior, Next, Home, End, +, − i kółko nie obracają kamery. | [Z] |
| 2 | Pochylenie | **35°** w dół od poziomu (sin = 0,5736, cos = 0,8192 w macierzy). Potwierdzone także zrzutami: przesunięcie obrazu w pionie zgadza się z 35°, a nie z 55°. | [Z] |
| 3 | Czy zoom zmienia tylko odległość | **Tak.** Oko przesuwa się wzdłuż osi widoku ku ognisku, macierz obrotu się nie zmienia, a ognisko stoi w miejscu. | [Z] |
| 4 | Zakres zoomu | **21 poziomów.** Odległość oko–ognisko od 29,7 (poziom 20, najdalej) w krokach co 1,49. Poziom 0 daje 0,1 i oko na wysokości 0,4 (praktycznie widok przy ziemi). Scenariusz startuje na poziomie 20. | [Z] |
| 5 | Zoom płynny, skokowy czy interpolowany | **W stanie gry skokowy.** Jedno kliknięcie zmienia poziom o 1 natychmiast; przy próbkowaniu co 10–40 ms brak wartości pośrednich. W kopii macierzy renderera raz zaobserwowano wartość pośrednią (12,84 między krokami 13,16 a 12,31), więc renderer mógł **wygładzać** obraz. Monitor był wtedy wygaszony i gra rysowała około 1–3 klatki/s, więc czasu ani przebiegu wygładzania nie dało się zmierzyć. | stan [Z], obraz [N] |
| 6 | Kółko i klawisze | Kółko w górę przybliża, w dół oddala. **Strzałki przesuwają kamerę.** Prior, Next, Home, End, +, − nie zmieniają kamery (jeden z nich otworzył okno „Poprzednie wiadomości” i wstrzymał grę). WASD nie badano jako kamery: w EE to skróty. | [Z] |
| 7 | Przesuwanie | Prędkość **15 + 30·(poziom/20) pól/s** (15 / 30 / 45 przy poziomach 0 / 10 / 20), stała od pierwszej klatki, bez rozpędzania i wybiegu (1 s i 3 s dają tę samą prędkość). Przesuwanie myszą przy krawędzi ekranu **występuje** (ruch kursora poza krawędź przesuwał kamerę), ale pod Wine z przesunięciami xdotool nie dało się zmierzyć prędkości ani szerokości strefy. | strzałki [Z], krawędź [Z]/[N] |
| 8 | Brzegi mapy i wysokość terenu | Ognisko jest ograniczone do obszaru mapy: dla mapy 100×100 x + y ∈ [100, 300] i x − y ∈ [−100, 100], czyli prostokąt w osiach ekranu (romb pól). Na brzegu kamera po prostu staje. Ognisko leży 0,4 nad z = 0, a teren mapy testowej był płaski (−0,6…0). **Czy ognisko nadąża za górami – nie zmierzono.** | granice [Z], wysokość [N] |
| 9 | Rzut i jego parametry | **Perspektywa.** Wielkość obiektów maleje z odległością w stosunku 1,99 przy ilorazie odległości 2,0. Ogniskowa wynosi około 3650 px przy szerokości okna 3440 px, co daje **poziomy kąt widzenia ≈ 50,4°**. Potwierdzenie: budynek wyrenderowany w OpenEE przy 50,4° ma tę samą szerokość co w EE (230 px wobec 235 px), a przy 45° jest o 13% szerszy. Jak kąt zmienia się przy innych proporcjach okna – nie zmierzono. | [Z] przy 3440×1440, skalowanie [N] |

### 2.6. Uwagi do pomiarów

* `0,7854` (π/4) w bloku renderera nie odpowiada mierzonemu kątowi widzenia: ani 45° w poziomie, ani 45° w pionie
  przy tych proporcjach. Znaczenie tej wartości pozostaje nieznane.
* **Zrzuty okna mogą być nieaktualne.** Gdy gra rysuje rzadko (wygaszony monitor), zrzut X11 potrafi zwrócić klatkę
  sprzed kilku sekund. Dlatego `ee_widok` robi zrzuty, aż dwa kolejne będą zgodne (SSIM ≥ 0,995). Pierwszy zrzut
  1,5 s po ruchu miał SSIM 0,24–0,73 względem stabilnego.
* Jednostka długości to „pole” siatki pozycji EE. Mapa 100×100 ma siatkę 200×200 i romb poprawnych pól, w tych samych
  jednostkach co pozycje jednostek w pamięci (`ee_jednostki` → X, Y) i w OpenEE (`UkladEE`).

## 3. Odbicie lustrzane świata OpenEE (nowe ustalenie)

`UkladEE` mapuje świat EE (x, y, z) na Godot (X, Y, Z) = (x, z, y). To odbicie (wyznacznik −1), co
`FORMATY_ETAP4 §3.1` opisywał jako nierozstrzygniętą skrętność obrazu. Porównanie kamery rozstrzyga tę kwestię:

* W EE centrum miasta gracza 1 leży na **prawo** od ogniska (x 17, y 99 przy ognisku 17,95; 96,92). W OpenEE, przy tej
  samej kamerze i tym samym ognisku, leży **na lewo**. **Rozmieszczenie obiektów na mapie jest lustrzane lewo–prawo.**
* Wygląd pojedynczego modelu z tego kierunku jest zgodny z EE. Na przykład wysoki niebieski kamień centrum miasta jest
  w obu grach z lewej strony. **Modele nie są lustrzane względem ekranu.**
* Żadna kamera nie usunie tej różnicy. Kamera patrząca z kierunku EE pokazuje modele jak w EE, ale układ mapy odbity.
  Kamera z przeciwnej strony odtworzyłaby układ mapy, ale pokazałaby inne ściany budynków.

Kamera OpenEE trzyma się kierunku patrzenia EE (widać te same ściany i proporcje), a odbicie układu mapy zostaje
**opisane, nie zamaskowane**. Naprawa należy do warstwy układu współrzędnych: `UkladEE.C` jako obrót, na przykład
(x, z, −y), razem z bazą obiektów, terenem, nawigacją i wskazywaniem. To osobne zadanie, wykraczające poza zmianę
kamery. Polecenie zadania „nie traktuj ograniczeń obrotu jako naprawy geometrii” zostało tu zachowane.

## 4. OpenEE – zmiany

### Kamera produkcyjna – `godot/sceny/kamera_rts.gd` (przepisana)

* Parametry pochodzą z `godot/silnik/kamera/model_kamery_ee.gd` (`ModelKameryEE`). Każda stała ma tam opis pomiaru
  i oznaczenie [Z], [W] lub [N].
* **Bez obrotu.** Nie ma Q/E, przeciągania środkowym przyciskiem, R ani WASD. Kierunek patrzenia jest stały, mapa EE
  (−1, +1) odpowiada Godot (−X, +Z). Pochylenie 35°, poziomy kąt 50,4° (`KEEP_WIDTH`).
* **Zoom:** kółko zmienia poziom o jeden w zakresie 0–20, z odległościami jak w EE. Start na poziomie 20.
* **Przesuwanie:** strzałki i mysz przy krawędzi okna (strefa 3 px [N], aktywna dopiero po ruchu myszy w oknie),
  prędkość 15–45 pól/s.
* **Ognisko:** ograniczone do rombu mapy, z granicami wyliczanymi z zakresów pól wierszy (`teren.rp`). Leży 0,4 nad
  terenem, z nadążaniem za wysokością [W].
* **Zgodność:** `cel`, `odleglosc`, `ustaw(cel, odl)` i `_aktualizuj()` działają dalej (odległość jest dociągana do
  najbliższego poziomu), więc kamera podążająca `--rts-sledz` i demo w `rts_test` działają bez zmian.
* Przy zrzutach i pomiarach (`--zrzut`, `--pomiar`, `--rts-zrzuty`, `--rts-film`, `--rts-pomiar`) przesuwanie
  krawędzią jest wyłączone.
  * Bez tego wyłączenia test wizualny wykrył dryf kadru: nowe okno zgłasza kursor w (0, 0), co uruchamiało
    przesuwanie przy krawędzi.

### Kamera diagnostyczna – `godot/sceny/kamera_diagnostyczna.gd`

To dawna wolna kamera: obrót, WASD, dowolny zoom 3–400, środkowy przycisk i R. Działają też niezależne kamery
`diag_modelu` i `diag_animacji`.

### Wybór kamery

* `rts_test` (rozgrywka) – produkcyjna; `--kamera-wolna` włącza diagnostyczną.
* `test_scenariusz` (podgląd) – diagnostyczna; `--kamera=ee` włącza produkcyjną.

### Nowe argumenty diagnostyczne

* `--plik-scn=<ścieżka>` – scenariusz z dysku zamiast archiwum kampanii.
* `--kamera-ognisko=x,y`, `--kamera-poziom=0..20`, `--kamera-fov=<°>` – porównywanie hipotez z oryginałem.
* `diag_modelu --kamera-ee=<poziom>` – model z kamerą oryginału.

## 5. Testy

**Godot (headless): 169/169 zaliczonych**, w tym 19 nowych testów kamery w `godot/testy/testy_kamery.gd`:

* model kamery:
  * odległości poziomów;
  * prędkości;
  * pochylenie i kierunek;
  * granice mapy 100×100 równe zmierzonym w EE;
  * dociąganie do brzegu;
* kamera produkcyjna:
  * start na poziomie 20, kąt 50,4° i `KEEP_WIDTH`;
  * **stały azymut** – Q, E i środkowy przycisk nic nie obracają;
  * kółko co jeden poziom w zakresie 0,1–29,7 bez zmiany pochylenia;
  * strzałka w prawo 45 pól/s, w górę 15 pól/s przy poziomie 0;
  * WASD nie przesuwa;
  * zatrzymanie na brzegu rombu;
  * nadążanie za terenem;
  * **promień wskazywania ze środka ekranu trafia w ognisko** (sterowanie jednostkami: `SterowanieRTS` używa
    `project_ray_*` kamery);
  * dociąganie `odleglosc` ustawianej z zewnątrz;
* kamera diagnostyczna – obrót i dowolna odległość zachowane;
* warunek wiarygodności – symulowane klawisze są widoczne w `Input`.

Testy wcześniejszych etapów (150) przechodzą bez zmian, w tym wszystkie testy etapu 5 (sterowanie, nawigacja).

**MCP (Python): 7 nowych testów `testy/test_ee_kamera.py` i 8 dotychczasowych – wszystkie zaliczone.** Atrapa pamięci
i wejścia odtwarza zmierzone zachowanie EE.

## 6. Ponowna weryfikacja grafiki (etap D)

Wszystkie widoki zostały wyrenderowane kamerą EE. Zrzuty są lokalne (`Testy_MCP/oe_render/20261106_0841…0846_D_*`,
`OpenEE/cache/kamera_D/`) i nie są publikowane.

| Widok | GPU Vulkan (RTX 5090) | GPU OpenGL (RTX 5090) | Programowy (lavapipe, VM) |
|---|---|---|---|
| Troja, poziom 8: meczet, koszary, stragany, mury, wieże | arkada (5 ostrołuków) i filary widoczne; 0 błędów | SSIM 0,995 względem Vulkana | SSIM 0,998 względem Vulkana GPU |
| Troja, poziom 20 (pełne oddalenie) | poprawny; widać kilka epok (budynki prehistoryczne, mury i wieże miasta, chaty) | – | – |
| Troja, poziom 1 (skrajne przybliżenie) | bez obcinania przez bliską płaszczyznę i bez migotania | – | – |
| `diag_modelu --kamera-ee`: Stable – Copper, Barracks – 01, x Mosque, Tree – Spruce 5 (billboard) | kompletne; arkada meczetu z filarami; impostor świerka zwrócony do kamery | – | meczet: SSIM 0,979 (różna rozdzielczość, po przeskalowaniu) |

Oryginał EE na GPU (DXVK/RTX 5090), mapa Riverlands, centrum miasta z prehistorii przy poziomie 20:

* skala modelu zgodna (230 px wobec 235 px);
* widoczne te same ściany modelu;
* układ mapy odbity lewo–prawo (§ 3).

Kolorystyka trawy i oświetlenie różnią się, co widać bez porównań liczbowych. To nie należy do zakresu kamery.

Pełnej zgodności renderowania nie stwierdzam. Zgodne są: kierunek patrzenia, pochylenie, zakres i krok zoomu,
prędkość przesuwania, granice ogniska oraz skala przy 3440×1440.

## 7. Niewiadome i zalecenia

1. **Wygładzanie zoomu w obrazie [N].** Pomiar wymaga włączonego monitora, żeby gra rysowała 60 klatek/s.
   Jednorazowy przebieg: `kam_kolko_seria` (MCP) z odczytem kopii renderera co 10 ms. Do tego czasu OpenEE zmienia
   poziom natychmiast, jak w stanie gry.
2. **Przesuwanie krawędzią [N]:** prędkość i strefa. Do zmierzenia z fizycznym kursorem albo z narzędziem
   pozycjonującym kursor bezwzględnie w Wine.
3. **Nadążanie ogniska za terenem [N].** Do zmierzenia na mapie z górami: `ee_kamera_ustaw` nad szczytem i nad doliną,
   porównanie wysokości oka.
4. **Kąt widzenia przy innych proporcjach okna [N].** Do zmierzenia w EE przy 1024×768 (zmiana rozdzielczości w opcjach
   gry, za zgodą użytkownika).
5. **Odbicie świata (§ 3)** – osobne zadanie w warstwie `UkladEE` z testami regresji: teren, obiekty, nawigacja,
   wskazywanie.
6. Klawisze kamery (np. powrót do ostatniego zdarzenia) i środkowy przycisk w EE – nie badano. Nie dodawano nowych
   mechanik.
