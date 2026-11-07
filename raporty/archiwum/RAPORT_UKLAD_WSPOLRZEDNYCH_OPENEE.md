# Etap 7 – układ współrzędnych świata OpenEE: przyczyna odbicia i naprawa

Data: 2026-11-06. Punkt wyjścia: lokalny `main` `0d7bd49` (dwa commity przed `origin/main` `c3d717d`; drzewo czyste).
Przed pracą zrobiłem kopię `kopie_OpenEE/OpenEE_przed_etapem7_0d7bd49.bundle` (pełna historia, zweryfikowana) oraz
`OpenEE_przed_etapem7_drzewo.tgz`. Stan wyjściowy testów: **169/169**.

Oznaczenia: [Z] zmierzone, [W] wnioskowane, [N] nieustalone.

## 1. Przyczyna odbicia świata

OpenEE zamieniało współrzędne świata EE (x = kolumna, y = wiersz, z = góra) na Godota macierzą
**C(x, y, z) = (x, z, y)**. To **odbicie** (wyznacznik −1): w prawoskrętnym Godocie oglądanym z góry oś y świata
lądowała po przeciwnej stronie osi x niż w grze. Tę samą macierz stosowano wszędzie:

* teren (`TerenEE`, `test_scenariusz._teren`, `test_teren`);
* pozycje obiektów i jednostek (`test_scenariusz`, `rts_test`, `WidokJednostek`);
* wskazywanie (`Zaznaczanie`);
* bazę obiektów C·R·M⁻¹ (`test_scenariusz._baza_obiektu`, `UkladEE.baza`).

W efekcie cała mapa była spójnym, ale **lustrzanym** obrazem mapy EE. Żadna kamera Godota nie mogła tego zakryć.
Kamera z tego samego kierunku co w EE pokazywała mapę odbitą lewo–prawo. Kamera z przeciwnej strony odtworzyłaby
układ mapy, ale pokazała inne ściany budynków.

Siatki modeli (`ModelCEM.P`, `ImporterModeli`: (x, z, −y)) były od początku zamieniane poprawnie, czyli obrotem.
Błąd dotyczył wyłącznie warstwy świata.

## 2. Dowody z oryginalnego Empire Earth

Scena: kampania AoC „Żołnierze dla Rzymu”, plik wyodrębniony narzędziem `ee_scenariusz_kampanii`. Gra działała
w kontrolowanej sesji MCP; instalacja pozostała tylko do odczytu, a kopia `000_EETEST_rzym.scn` została usunięta.
Wybrałem asymetryczny układ obiektów:

* dwa forty: A (220, 108) i B (217, 107);
* pięć domów trzech różnych modeli wokół (222,5–223,5; 108,5–110,5);
* jednostki o znanym kursie z macierzy rekordu:
  * obywatele (45°);
  * łucznicy konni (173° i −160°);
  * legioniści.

Pozycje pochodzą z pliku scenariusza (`narzedzia/obiekty_scenariusza.gd`, teraz także z `--plik-scn`) i z pamięci
gry (`ee_obiekty_w_widoku`). Kamera (`ee_kamera`):

* oko (237,19; 90,80; 18,68);
* ognisko (219,99; 108,00);
* azymut 135°, pochylenie 35°, poziom zoomu 20.

**Rzut punktów kontrolnych.** Porównałem piksele zmierzone na zrzucie oryginału z rzutem według zmierzonej kamery,
w dwóch hipotezach.

| Punkt | EE (x, y) | Piksel w EE | Rzut, świat prawoskrętny | Rzut, odbicie (dawny OpenEE) |
|---|---|---|---|---|
| Fort A | 220; 108 | 1720, 690 | błąd 27 px | 27 px (punkt na osi odbicia) |
| Fort B | 217; 107 | 1368, 600 | **35 px** | 691 px |
| Dom Dark | 221,5; 110,5 | 2080, 650 | **21 px** | 705 px |
| Dom Bronze | 222,5; 110,5 | 2180, 710 | **34 px** | 899 px |
| Dom Copper (szopa) | 223,5; 110,5 | 2280, 775 | **47 px** | 1098 px |
| Dom Bronze | 222,5; 108,5 | 2000, 820 | **33 px** | 555 px |
| Dom Dark | 223,5; 108,5 | 2110, 870 | **33 px** | 764 px |
| **średnio** | | | **33 px** | **677 px** |

Uwagi:

* Rzut liczy kamera produkcyjna OpenEE (`unproject_position`, okno 3440×1440). Ten sam wynik daje niezależne
  obliczenie analityczne w Pythonie.
* Piksele EE to środki budynków odczytane ręcznie (±20 px). Pozostały błąd wynika z tego odczytu i z wysokości punktu
  na budynku.
* Przy okazji ustaliłem, że środek rzutu EE to środek **całego** okna (y = 720), a nie środek obszaru nad paskiem
  interfejsu: przy 651 każdy punkt był przesunięty o ~70 px w pionie [Z]. Poprawiłem to w `ee_kamera.rzut`.

Pomiar jest jednoznaczny: gra pokazuje świat w orientacji prawoskrętnej. Oś x biegnie na ekranie w prawo-w-dół, oś y
w prawo-w-górę [Z]. Zgadza się to z pomiarem klawiszy z etapu kamery: strzałka w prawo przesuwa ognisko o (+1, +1),
strzałka w górę o (−1, +1).

**Orientacja modeli.** Dla konwencji osi modelu względem świata (L) sprawdziłem w OpenEE dwie hipotezy:

* L = I – model w układzie świata;
* L = D – odbita oś y modelu, czyli lewoskrętny CEM.

Obie wyrenderowałem przy kamerze EE i porównałem z oryginałem:

| Obiekt | Kurs | EE | OpenEE L = I | OpenEE L = D |
|---|---|---|---|---|
| Obywatele (8) | 45° | **plecami do kamery** | plecami do kamery ✓ | przodem do kamery ✗ |
| Łucznicy konni (3) | 173°, −160° | przodem, w lewo-w-dół | w lewo-w-dół ✓ | w prawo-w-górę ✗ |
| Legioniści z tarczami | różne | tarcze z lewej, ku dołowi | zgodnie ✓ | odwróceni ✗ |
| Forty i domy | 0° | – | rozróżnienie słabe (modele prawie symetryczne w y) | – |

Wynik: **L = I** [Z]. Przód modelu +Y (ustalenie etapu 5) daje w grze kierunek R·(0, 1).

**Kamera.** Kierunek patrzenia, pochylenie i skala z etapu kamery pozostały bez zmian. Zmieniła się tylko ich
reprezentacja w Godocie, liczona przez warstwę konwersji.

## 3. Prawidłowa transformacja i uzasadnienie

**W(x, y, z) = (x, z, −y)**, czyli Godot X = kolumna, Y = wysokość, Z = −wiersz.

* Jest obrotem (wyznacznik +1), więc zachowuje skrętność, której wymagają pomiary z § 2.
* Jest tą samą macierzą co zamiana siatek CEM (`ModelCEM.P`), więc świat i modele przechodzą przez jedno
  przekształcenie.
* Baza obiektu to **W · R · L · P⁻¹** z L = I. Dla R = I daje to macierz jednostkową, a model wygląda jak w grze.
* Kurs jednostki θ (obrót wokół z świata EE) i wzór kierunku ruchu θ = atan2(−dx, dy) pozostały bez zmian, bo są
  zdefiniowane w układzie EE.

Odrzuciłem dwie alternatywy:

* obrót całej sceny kamerą – zabroniony w zadaniu i niemożliwy, bo odbicia nie da się usunąć obrotem;
* globalna skala −1 – ponownie odbija świat i odwraca nawinięcie.

## 4. Zmienione podsystemy (spójna migracja)

Jedyną warstwą konwersji jest teraz **`UkladEE`**:

* `godot(p, h)` i `mapa(v)` – punkty;
* `wektor`, `wektor_ee` i `kierunek` – kierunki;
* `baza(R)` i `basis_ee` – macierze;
* `pozycja_z_rekordu` – pozycja z rekordu scenariusza;
* `ustaw_konwencje_modelu` – tylko diagnostyka, `--uklad-modelu=I|D|F`.

Lokalne zamiany osi usunąłem z następujących plików:

| Podsystem | Plik | Zmiana |
|---|---|---|
| Teren | `silnik/render/teren_ee.gd` | wierzchołki, woda, normalne (gradient liczony w świecie EE, potem `wektor`) |
| Obiekty scenariusza | `sceny/test_scenariusz.gd` | pozycje i baza przez `UkladEE`; teren etapu 2 i woda; kierunek światła przeliczony tak, by względem świata EE pozostał jak dotąd |
| RTS | `sceny/rts_test.gd` | pozycje z rekordów, kamera podążająca, demo |
| Widok jednostek | `silnik/symulacja/widok_jednostek.gd` | transformacje, pierścienie i trasy |
| Wskazywanie | `silnik/symulacja/zaznaczanie.gd` | punkt terenu i walec jednostki |
| Kamera produkcyjna | `silnik/kamera/model_kamery_ee.gd`, `sceny/kamera_rts.gd` | wielkości w układzie EE (`kierunek_ee`, `os_prawo_mapy`, `os_dalej_mapy`); ognisko i granice w układzie mapy |
| Kamera diagnostyczna | `sceny/kamera_diagnostyczna.gd` | domyślny kąt od strony kamery EE (45°); obrót swobodny jak dotąd |
| Diagnostyka modelu | `sceny/diag_modelu.gd` | baza jak obiekt sceny (`UkladEE.baza`); `--lustro` zostaje jako test bazy odbitej; `--kamera-ee` liczy kierunek przez `UkladEE` |
| Scena etapu 2 | `sceny/test_teren.gd` | teren, woda, model, kamera, światło; odwrócona kolejność wierzchołków (`cull_back`) |
| Narzędzie | `narzedzia/obiekty_scenariusza.gd` | `--plik-scn`, pole, id, kurs i macierz R w wyniku |
| Bez zmian (świadomie) | symulacja, `MapaNawigacji`, A*, `Sciezki`, kolizje | pracują w 2D układu mapy EE, więc konwersja ich nie dotyczy |
| Bez zmian | `ImporterModeli`, `AnimacjaVAT`, `ModelCEM` (części: P·D·P⁻¹) | przestrzeń modelu; shader odrzuca tylne ściany według znaku wyznacznika `MODELVIEW`, więc działa dla obu baz |

Przy okazji poprawiłem dwie rzeczy:

* **`ee_kamera` (MCP):** pole `0x931750` nie zawsze jest ogniskiem (po filmie wprowadzającym kampanii zawierało inny
  punkt). Ognisko liczę teraz jako oko + przód·odległość.
* **`wejscie.okno` (MCP):** pełnoekranowe okno gry minimalizuje się, gdy fokus przejmie inne okno, na przykład render
  OpenEE. MCP szuka teraz także ukrytego okna i je przywraca.
  * Taka gra może jednak zamrozić obraz i wymagać ponownego uruchomienia. **Zalecenie:** nie uruchamiać renderów
    OpenEE w trakcie sesji z oryginałem.

## 5. Porównania przed i po

Zrzuty są lokalne w `Testy_MCP/oe_render/20261106_09*_E7_*` i `10*_E7_*`; nie publikuję ich.

| Kryterium | Przed (C, odbicie) | Po (W, obrót) |
|---|---|---|
| Położenie 7 punktów kontrolnych względem EE | średnio ~677 px (układ lustrzany: fort B w prawym górnym rogu, domy z lewej) | **33 px** (fort B w lewym górnym rogu, domy z prawej, jak w EE) |
| Orientacja jednostek (obywatele, łucznicy, legioniści) | – | **zgodna z EE** (przy L = D niezgodna) |
| Orientacja budynków | wygląd modelu zgodny, położenie lustrzane | wygląd i położenie zgodne |
| Skala i perspektywa | bez zmian (kamera etapu 6: 230 px wobec 235 px w EE) | bez zmian |
| Meczet w Troi (arkada, filary) | widoczne | widoczne; układ placu nieodbity |
| Animacje | – | w scenach bez regresji: jednostki z sekwencją bezczynności, demo RTS z animacją ruchu; przód jednostki zgodny z kierunkiem ruchu (test punktu `attack`) |
| Wskazywanie i nawigacja | – | test piksel → promień → jednostka/teren; testy A*, kolizji, wąskich przejść i rozkazów z etapu 5 przechodzą bez zmian |

## 6. Testy

**Godot (headless): 180/180 zaliczonych** (było 169).

Nowe testy:

* `testy/testy_ukladu.gd` (10):
  * punkt EE → Godot → EE;
  * kierunki;
  * zachowanie odległości;
  * skrętność (wyznacznik +1, x × y = z, W = P);
  * macierz obiektu W·R·P⁻¹;
  * orientacja trójkątów i normalnych;
  * rzut 7 asymetrycznych punktów kontrolnych EE przez kamerę OpenEE (średnio 32,6 px, maks. 46,5 px);
  * hipoteza odbicia odrzucona (średnio 677 px);
  * wskazywanie myszą;
  * napisy Windows-1250.
* `testy_kamery.gd` – nowy test: prawo ekranu Godota = (+1, +1) mapy EE, czyli kadr nie jest odbity.

Przepisane testy (nowa konwencja, ta sama treść):

* baza obiektu po obrocie 90° (wyznacznik +1);
* przód modelu względem kierunku ruchu;
* promienie zaznaczania budowane z punktów mapy przez `UkladEE`;
* kamera: przesunięcia w układzie mapy.

**MCP:** `test_ee_kamera.py` 7/7 (środek rzutu y = 720), `test_ee_diag.py` 8/8.

Sprawdzone ręcznie (renderer Vulkan na RTX 5090):

* Rzym (poziomy 20 i 3), Troja (poziom 8), `diag_modelu --kamera-ee` (Stable – Copper), scena `test_teren`;
* demo RTS w rendererze programowym (lavapipe).

## 7. Pozostałe niezgodności (poza zakresem układu współrzędnych)

* **Tekstury:**
  * fort (`bld_fortress_03`) ma w EE dachy z czerwonej dachówki, a w OpenEE strzechę;
  * obywatel w EE nosi białą togę, w OpenEE ma nagi tors.

  To wybór wariantu tekstury lub epoki, nie geometria.
* **Domy** w scenie startowej EE są półprzezroczyste (stan budowy lub widoczności), a w OpenEE pełne.
* **Oświetlenie:** kierunek słońca w EE [N]. OpenEE zachowało dotychczasowy kierunek względem świata EE. Jasność
  kadrów się zmieniła, bo kamera widzi teraz inne zbocza.
* **Ruchu jednostki w kilku kierunkach w EE nie nagrałem.** Zaznaczenie jednostki kliknięciem nie zadziałało
  w zautomatyzowanej sesji. Orientację potwierdzają kursy jednostek stojących (trzy różne) oraz test punktu `attack`
  w OpenEE.
* **Teren górzysty:** porównania przeprowadziłem na Rzymie i w Troi. Nachylenia liczy jedna funkcja gradientu w układzie
  EE; osobnego porównania stoków z EE nie było.
* **Pełnej zgodności renderowania nie stwierdzam.** Zgodne są: położenie (punkty kontrolne), orientacja jednostek,
  kierunek, skala i perspektywa kamery.

## 8. Dodatkowo: polskie znaki

* **Oryginalne EE:** krzaki w odprawach i napisach („zosta³”) wynikały z uruchamiania Wine bez `LANG`, czyli ze stroną
  kodową 1252. MCP uruchamia teraz grę z `LANG/LC_ALL=pl_PL.UTF-8` (konfiguracja `gra.locale`) i strona kodowa to
  1250. Instalacja, prefiks i system pozostały bez zmian. Przy ręcznym starcie z Lutrisa trzeba dodać tę zmienną
  w ustawieniach gry.
* **OpenEE:** nowy `TekstEE.cp1250` (pełna tablica Windows-1250) obsługuje nazwy w archiwach SSA, nazwy graczy
  w scenariuszach i napisy tabel db.

## 9. Stan repozytorium

Lokalny commit etapu 7 jest na `main`. **HEAD i liczba commitów oczekujących na publikację są podane w opisie commita
i w podsumowaniu sesji** (przed tym etapem: 2 commity przed `origin/main`; po nim: 3). Nie wykonywałem pusha.
