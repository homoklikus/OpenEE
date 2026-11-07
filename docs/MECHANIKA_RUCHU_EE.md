# Mechanika ruchu i sterowania jednostkami – Empire Earth 1 / The Art of Conquest

Etap 9 OpenEE. Opis zachowania **oryginalnej gry** ustalony pomiarami, potem odtworzony w Godocie
(`godot/silnik/symulacja/`). Pomiary prowadzono w EE: The Art of Conquest (Wine, normalna szybkość gry) na
scenariuszu testowym `Testy_MCP/mapy/etap9/etap9_pasy.scn`. To mapa Riverlands z rzeką i dwoma brodami oraz 12 grupami
jednostek gracza 1 (generator: `narzedzia/scenariusz_testowy_ruchu.py`).

**Metoda.** Jednostki zaznaczano i dowodzono zwykłym wejściem: mysz i klawiatura przez xdotool. Wynik odczytywano
z pamięci procesu, tylko odczyt (MCP `ee_ruch`):
- pozycja, kurs i pole jednostki – macierz w obiekcie jednostki +0x130;
- zawartość grupy zaznaczenia gracza – wektory w obiektach +0x9AC i +0x9B0 gracza.

Trajektorie zapisywano z częstotliwością 4–10 Hz do `Testy_MCP/ee_ruch/*.json`. Analizowano je skryptem
`narzedzia/analiza_ruchu_ee.py`, a porównanie z OpenEE robi `godot/narzedzia/porownanie_ruchu_ee.gd`.

Nie zapisywano niczego do pamięci gry, nie modyfikowano gry ani jej plików i nie kopiowano kodu.

**Oznaczenia pewności:**
- **[P]** potwierdzone pomiarem (powtarzalne);
- **[W]** wniosek z pomiaru (jeden przypadek albo pośrednio);
- **[H]** hipoteza (decyzja OpenEE, nie mechanika EE);
- **[N]** nieustalone.

§§ 2–7 to pomiary etapu 9 w **AoC**. Etap 12 powtórzył najważniejsze z nich w **podstawowym Empire Earth** i w AoC
na tym samym scenariuszu („Wojna trojańska”) – § 10 i `docs/POROWNANIE_MECHANIK_EE_AOC.md`. Zakres ustaleń:
**(EE)**, **(AoC)**, **(obie)**, **(obie?)**. W EE grupę zaznaczenia gracza przechowują wektory +0x9BC i +0x9C0
(w AoC +0x9AC i +0x9B0).

## 1. Jednostki miary

- **Pole** – jednostka mapy, czyli komórka siatki terenu. Pozycja w pamięci to liczba zmiennoprzecinkowa w polach,
  a środek pola leży w (n + 0,5).
- **Czas** – sekundy rzeczywiste przy normalnej szybkości gry.

## 2. Zaznaczanie

| Reguła | Wynik w EE | Pewność |
|---|---|---|
| LPM na własnej jednostce | Zaznacza tylko ją i zastępuje poprzednie zaznaczenie. | [P] |
| Shift + LPM | Dodaje jednostkę. Na jednostce już zaznaczonej nic nie zmienia (nie odznacza). | [P] |
| Ctrl + LPM na zaznaczonej | Usuwa ją z zaznaczenia. | [P] |
| LPM na pustym terenie | Odznacza wszystko. | [P] |
| Esc | Nic nie zmienia. | [P] |
| Ramka (przeciągnięcie LPM) | Zastępuje zaznaczenie jednostkami w ramce. | [P] |
| Shift + ramka | Dodaje jednostki z ramki. | [P] |
| Ctrl + ramka | Usuwa jednostki z ramki. | [P] |
| Kryterium ramki | Punkt jednostki, nie sylwetka. Ramka przez głowę nie zaznacza, ramka przez tułów lub nogi zaznacza. Dokładna wysokość punktu – [N]. | [W] |
| Limit | Zaznaczono 50 jednostek jedną ramką. Górnej granicy nie szukano. | [P] dla 50 |
| Ramka obejmująca budynek i jednostki | Zaznacza tylko jednostki (Capitol i 5 obywateli → 5 obywateli). | [W] |
| LPM na własnym budynku | Zaznacza budynek. | [P] |
| Shift + LPM na jednostce przy zaznaczonym budynku | Daje zaznaczenie mieszane: budynek + jednostka. | [W] |
| LPM na jednostce przy zaznaczeniu mieszanym | W jednej próbie wynikiem było puste zaznaczenie. | [N] |
| Opóźnienie | Zaznaczenie ramką pojawia się w grupie gracza z opóźnieniem do ~1 s. Wektor +0x9AC przechowuje poprzednie zaznaczenie. | [P] (pamięć) |
| Jednostki wroga, sojusznika | Nie badano. | [N] |

## 3. Rozkaz ruchu grupy (PPM) i szyk

| Cecha | EE | Pewność |
|---|---|---|
| Cel jednostki | Każda jednostka dostaje własne miejsce w szyku i idzie do niego własną trasą. Nie ma lidera ani wspólnego punktu marszu. | [P] |
| Start | Wszystkie jednostki ruszają w tym samym takcie. | [P] |
| Prędkość | Każda jednostka idzie z własną prędkością. Grupa nie wyrównuje prędkości, także w grupie mieszanej (kawaleria dochodzi pierwsza). | [P] |
| Kształt | Siatka o szerokości 5 kolumn: 2 → 1×2, 5 → 1×5, 10 → 2×5, 25 → 5×5, 35 → 7×5. | [P] (odchyłka miejsc 0,02–0,03 pola w 8 przejściach; 35 – 0,3) |
| Orientacja | Rzędy są prostopadłe do kierunku od środka grupy do punktu rozkazu. Orientacja nie zależy od ułożenia przed rozkazem. | [P] (6 kierunków) |
| Położenie | Pierwszy rząd stoi w punkcie rozkazu, kolejne za nim. | [P] |
| Odstęp | W rzędzie i między rzędami odstęp = `dbobjects` „Size in formation” (obywatel 0,625; zmierzone 0,60–0,63). | [P] |
| Grupa mieszana | Odstęp ~0,77 (= „Size in formation” kawalerii), układ nieregularny. | [W] |
| Niepełny rząd | Nie mierzono osobno; w OpenEE wyśrodkowany. | [H] |
| Przydział jednostek do miejsc | Przy pierwszym rozkazie grup ułożonych w siatkę (2, 5, 10, 25) identyfikatory rosnąco wypełniają rzędy od pierwszego, w rzędzie od lewej strony kierunku marszu. W 5 innych przejściach oryginał przydziela inaczej (patrz niżej). | [W] / [N] |
| Formacje z przycisku (8 rodzajów) i tryb „Szybko/Sprytnie” | Teksty istnieją w Language.dll (19501–19508, 31001–31002). Nie badano. | [N] |

**Przydział jednostek do miejsc w pozostałych przejściach.** Dotyczy marszu przez bród i krótkich przejść z zastanego
szyku. W 8 z 9 przejść zachowana jest kolejność poprzeczna, czyli lewo–prawo względem marszu (korelacja rang 1,0).
Sprawdzone i odrzucone hipotezy:
- minimalna suma dróg;
- minimalna suma kwadratów dróg;
- zachłanny przydział: najbliższe miejsce dla kolejnych jednostek;
- zachłanny przydział: najbliższa jednostka dla kolejnych miejsc;
- kolejność poprzeczna z rzędami.

Ostateczna reguła – [N].

**Szybkość obrotu.** Obrót o ~93° na starcie trwa < 0,5 s, a przyspieszenie jest pomijalne [P]. OpenEE używa
„Idle/Moving turning speed” jako rad/s [H].

## 4. Prędkość

Zmierzone prędkości (mediana w środkowej części ruchu, kilka przejść) [P]:

| Jednostka | `Speed` (dbobjects) | Prędkość (pola/s) |
|---|---|---|
| Obywatel | 0,5 | 0,73 |
| Miecznik | 0,6 | 0,875 |
| Jeździec | 0,8 | 1,17 |

Stosunek wynosi 1,45–1,55, średnio 1,46. Wniosek: prędkość = `Speed` × 1,46 [P dla trzech typów, AoC, Riverlands].

**Etap 13 (`docs/MECHANIKA_PREDKOSCI_EE.md`):**
- `Speed` to pola na sekundę **czasu gry** [P].
- Licznik ms czasu gry (`A_GRA+0xD0`) rośnie o 1461 ms na sekundę rzeczywistą w EE i AoC [P], więc mnożnik wynosi
  **1,461**. Dotychczasowa hipoteza jest potwierdzona.
- Wartość 1,706 z etapu 12 była artefaktem: maksimum próbek 10 Hz przy położeniach zmienianych skokowo co takt.
  Wycofano ją [P].
- W scenariuszach testowych z kampanii „Blitzkrieg” dochodzi stały dodatek +0,15 pola/s czasu gry (obywatel, prorok;
  EE i AoC). Przyczyna [N].

## 5. Trasy i nawigacja (pathfinding)

| Cecha | EE | Pewność |
|---|---|---|
| Siatka | Trasa przechodzi przez środki pól. W brodzie wszystkie jednostki szły jedną kolumną dokładnie po x = 76,5. | [P] |
| Kształt trasy | Tylko odcinki w 8 kierunkach. Po zmianie kierunku zwykle najpierw przekątna, potem prosto (G1, rozkazy A→B, kolejka, bród). Nie ma skrótów pod dowolnym kątem. | [P] |
| Ostatni odcinek | Prowadzi do dokładnego punktu (miejsca w szyku). | [P] |
| Bród (przesmyk 1 pola) | 10 jednostek przeszło bez zatrzymań, kolejno w jednej linii, przenikając się (min. odległość 0,065). Czas i droga jak bez kolejki. | [P] |
| Budynek | Capitol jest omijany po siatce. Obrys ~2 × 2 pola przy „Size of collider” = 2, więc „Size of collider” działa jak średnica. | [W] |
| Cel w wodzie | Rozkaz w koryto rzeki: jednostki stanęły na środkach pól przy punkcie (najbliższe osiągalne). | [W] (1 próba; nie potwierdzono, że to było pole głębokiej wody) |
| PPM na budynku, wrogu, zasobie | Inne rozkazy niż ruch – poza zakresem etapu. | [N] |

## 6. Kolizje (unikanie lokalne)

Etap 13 powtórzył te pomiary w EE i AoC na płaskim scenariuszu testowym w 7 przypadkach
(`docs/KOLIZJE_JEDNOSTEK_EE.md`). Wyniki poniżej potwierdzono w obu grach. Doszła jedna reguła: **jednostka w ruchu
omija pole jednostki stojącej** [P].

| Cecha | EE | Pewność |
|---|---|---|
| Przenikanie | Jednostki tej samej i przeciwnej grupy przenikają się. | [P] |
| Minimalne odległości | 0,035–0,077 pola: G25, grupy idące naprzeciw siebie, bród. | [P] |
| Zachowanie przy spotkaniu | Brak zatrzymań i objazdów. Odchylenie boczne ≤ 0,4 pola, mieszczące się w różnicy tras. | [P] |
| Wzajemne blokowanie grup | Nie występuje. | [P] |
| Promień kolizji według typu | Nieustalony – w ruchu nie działa. | [N] |
| Gęstość w punkcie docelowym | Wynika wyłącznie z szyku: odstęp = „Size in formation”. | [P] |

| Jednostka stojąca na trasie (etap 13) | Objazd jej pola po siatce, bez zwalniania; najmniejsza odległość 0,66 pola. | [P] (EE i AoC, 1 układ) |
| Wspólny punkt docelowy (etap 13) | Druga jednostka staje 0,3 pola od pierwszej; pierwsza nie jest przesuwana. | [W] |

Unikanie lokalne jednostek w ruchu nie zostało zaimplementowane: oryginał go nie wykazuje. Od etapu 13 trasa omija
pola jednostek stojących (`Symulacja.OMIJANIE_STOJACYCH`).

## 7. Rozkazy: zastępowanie, kolejka, pauza

| Cecha | EE | Pewność |
|---|---|---|
| Nowy PPM w trakcie ruchu | Zastępuje poprzedni rozkaz. Jednostka zawraca po ~0,6 s (w tym opóźnienie wejścia) i nie dochodzi do starego celu. | [P] |
| Shift + PPM | Dopisuje punkt do kolejki. Jednostka dochodzi do bieżącego celu, potem idzie do następnego, bez wyraźnego postoju. | [W] (1 próba, jednoznaczna) |
| Sygnalizacja rozkazu (znacznik, dźwięk) | Nie badano – zrzuty X11 są nieaktualne. | [N] |
| Rozkazy w pauzie | Nie badano. | [N] |

## 8. Odtworzenie w OpenEE

| Mechanika | Plik | Uwagi |
|---|---|---|
| Reguły zaznaczania | `zaznaczenie_ee.gd`, `sterowanie_rts.gd` | Ramka z podglądem, Shift/Ctrl. Punkt jednostki na wysokości 0,3 [H]. |
| Szyk grupy | `formacja_ee.gd`, `Symulacja.rozkaz_grupy` | Przydział według id [W]. |
| Prędkość | `Symulacja.MNOZNIK_PREDKOSCI = 1,461` (tempo czasu gry, etap 13) | [P] |
| Trasy oktylowe przez środki pól | `Sciezki.oktylowe`, siatka `podzial = 1` w scenie RTS | Rozszerza istniejący A*, nie dodaje drugiego systemu. |
| Kolejka Shift + PPM | `JednostkaSym.kolejka_celow` | Szyk punktu w kolejce liczony od poprzednich miejsc [H]. |
| Cel nieosiągalny | `Sciezki.najblizszy_osiagalny` | [W] |
| Obrys przeszkód | `rts_test.gd` | Promień = „Size of collider” / 2 [W]. |
| Przenikanie jednostek w ruchu | Brak kodu unikania | [P] |
| Objazd jednostek stojących | `Symulacja.zajete_komorki`, `Sciezki.znajdz(..., zajete)` | [P]; trasa liczona przy rozkazie [H] |
| Animacja | Stan „ruch” / „bezczynność” z symulacji | Bez zmian względem etapu 5. |

## 9. Nieustalone (do dalszych badań)

1. Reguła przydziału jednostek do miejsc w szyku poza pierwszym rozkazem.
2. Formacje z przycisków oraz tryb Szybko/Sprytnie.
3. Dokładny punkt jednostki w teście ramki.
4. Zaznaczanie jednostek wroga i sojusznika.
5. LPM przy zaznaczeniu mieszanym.
6. Pauza.
7. Sygnalizacja rozkazu.
8. PPM na obiektach – rozkazy inne niż ruch.
9. Grupa mieszana:
   - czas dojścia w EE o ~20% dłuższy niż wynika z prędkości;
   - krętość 1,09.
10. Różnice EE 1.0 ↔ AoC – zbadane w etapach 12 i 13. Wyjaśnione w etapie 13:
    - grupy idące naprzeciw w EE przenikają się jak w AoC;
    - prorok ma prędkość = `Speed` (bez własnego mnożnika);
    - mnożnik 1,706 był artefaktem pomiaru.

    Otwarta jest przyczyna dodatku +0,15 w scenariuszu z „Blitzkriegu”.

## 10. Etap 12 – Empire Earth i The Art of Conquest

Scenariusz „Wojna trojańska” (SCN 231) wczytany w obu grach, te same jednostki i te same rozkazy. Trajektorie:
`Testy_MCP/ee_ruch/e12_*.json` (lokalnie).

| Cecha | EE | AoC | Zakres |
|---|---|---|---|
| LPM, Shift + LPM, Ctrl + LPM na zaznaczonej | zastępuje / dodaje (na zaznaczonej bez zmian) / usuwa | jak w § 2 | (obie) [P] |
| Esc | nic nie zmienia | nic nie zmienia | (obie) [P] |
| Ramka, Ctrl + ramka | zastępuje (z bohaterem i prorokiem w ramce) / usuwa | te same 6 obiektów | (obie) [P] |
| LPM na murze | zaznacza mur | zaznacza mur | (obie) [P] |
| LPM na pustym terenie | niezmierzone (punkt trafił w mur) | odznacza (§ 2) | (obie?) [H] |
| Prędkość | `Speed` × 1,706: obywatel 0,853, gwardia 1,023, bohater 1,366 | gwardia 1,023, bohater 1,38 | (obie) [P] |
| Prorok (`Speed` 0,45 w obu bazach) | 0,853 | 0,96 | [H] – jedna trasa 1,2–1,3 pola w każdej grze |
| Start, obrót | jeden takt, obrót pomijalny | to samo | (obie) [P] |
| Szyk, miejsca końcowe | – | – | (obie) [P]: końcowe pozycje zgodne w granicy 0,05 pola |
| Prędkości w grupie | każda jednostka własna | to samo | (obie) [P] |
| Nowy PPM w trakcie ruchu | zastępuje natychmiast | to samo | (obie) [P] |
| Shift + PPM | kolejka | kolejka | (obie) [W] |
| Grupy idące naprzeciw | częściowe skrzyżowanie 2 + 2: najmniejsza odległość 0,99, odchylenia do 1,8 pola przy murze i bramie | czysty test nieudany (kliknięcia trafiały sąsiednie jednostki) | [N]; § 6 (AoC, Riverlands) pozostaje [P] dla AoC |

Wnioski:
- Mechaniki zaimplementowane w OpenEE (§ 8) zachowują się w EE tak samo jak w AoC. Wspólny kod wystarcza, bez
  rozgałęzień według gry.
- `Symulacja.MNOZNIK_PREDKOSCI = 1,46` zostało bez zmian. Wartość 1,706 dotyczyła innego scenariusza, w obu grach
  jednakowo, a przyczyna różnicy między scenariuszami była nieustalona [N]. **Etap 13:** 1,706 to artefakt metody;
  stała to tempo czasu gry, 1,461.
- Unikania lokalnego nie dodano: w EE nie zmierzono go jednoznacznie [N]. **Etap 13:** przenikanie potwierdzone
  w EE [P].
