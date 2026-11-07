# Raport – etap 9: sterowanie jednostkami i ruch grupowy (wierne odtworzenie EE)

Data: 2026-11-06. Szczegółowa specyfikacja mechaniki ze źródłami i poziomami pewności znajduje się
w `docs/MECHANIKA_RUCHU_EE.md`.

**Oznaczenia pewności:**
- **[P]** potwierdzone pomiarem;
- **[W]** wniosek z pomiaru;
- **[H]** hipoteza lub decyzja OpenEE;
- **[N]** nieustalone.

## 1. Wyniki badań oryginalnego EE

Badania prowadziłem w kontrolowanej sesji EE: The Art of Conquest. Scenariusz testowy `etap9_pasy.scn` to mapa
Riverlands 100×100 z rzeką i dwoma brodami. Zawiera 12 grup gracza 1:
- grupy obywateli: 1, 2, 5, 10, 25 i 50;
- 5 jeźdźców i 5 mieczników;
- dwie grupy po 5 jednostek naprzeciw siebie;
- 10 obywateli przy brodzie;
- 5 obywateli przy Capitolu.

Wykonałem 47 zadań MCP (zadania 99–145). Wynikiem jest 25 plików trajektorii (4–10 Hz) oraz odczyty zaznaczenia
z pamięci po każdym kliknięciu.

**Najważniejsze ustalenia:**
- **Zaznaczanie [P].**
  - LPM zastępuje zaznaczenie, Shift dodaje, Ctrl usuwa, LPM na terenie czyści, Esc nic nie robi.
  - Ramka działa tak samo z modyfikatorami.
  - Ramka obejmuje 50 jednostek bez limitu.
  - Ramka obejmująca budynek i jednostki wybiera tylko jednostki [W].
  - Shift dodaje jednostkę do zaznaczonego budynku [W].
- **Szyk [P].**
  - Siatka 5 kolumn, rzędy prostopadłe do kierunku od środka grupy do celu.
  - Pierwszy rząd stoi w punkcie rozkazu.
  - Odstęp = „Size in formation”.
  - Odchyłka modelu od pomiaru wynosi 0,02–0,03 pola w 8 przejściach.
- **Ruch [P].**
  - Każda jednostka idzie do własnego miejsca w szyku, z własną prędkością.
  - Wszystkie ruszają razem; nie ma lidera ani wyrównywania prędkości.
- **Prędkość [P].** Prędkość = `Speed` × 1,46 pola/s (obywatel 0,73, miecznik 0,875, jeździec 1,17).
  Etap 13: 1,46 to tempo czasu gry (1,461 ms gry na 1 ms rzeczywisty), a `Speed` podaje pola na sekundę czasu gry [P].
- **Trasy [P].**
  - Trasa biegnie przez środki pól, tylko w 8 kierunkach: najpierw przekątna, potem prosto.
  - Nie ma skrótów pod dowolnym kątem.
  - Bród przechodzą jedną kolumną pól.
- **Kolizje [P].**
  - Jednostki przenikają się (min. odległość 0,035–0,077), także grupy idące naprzeciw siebie i w brodzie.
  - Nie ma zatrzymań ani unikania lokalnego.
    **[Etap 13.5 – zastąpione]** Etap 13: potwierdzone także w EE; dodatkowo jednostka w ruchu omija pole jednostki **stojącej**
    (`docs/KOLIZJE_JEDNOSTEK_EE.md`).
- **Rozkazy.**
  - Nowy PPM zastępuje poprzedni w trakcie ruchu [P].
  - Shift + PPM dopisuje punkt do kolejki [W].
  - Rozkaz w wodę prowadzi jednostki na najbliższe osiągalne pola [W].
- **Budynek [W].** Obrys Capitolu wynosi ~2 × 2 pola, więc „Size of collider” działa jak średnica.

## 2. Rozszerzenia MCP i dlaczego były potrzebne

Dodałem moduł `riverlands_mcp/ee_ruch.py` z 8 funkcjami zadań `ruch_*`. Opis jest w `RAPORT_ROZBUDOWA_EE_MCP.md` § 13.

Moduł był potrzebny z trzech powodów:
- Etap wymagał liczb: trajektorii, zawartości zaznaczenia i modyfikatorów przy kliknięciu. Dotychczasowe MCP dawało
  migawkę jednostek i kliknięcie bez Shift/Ctrl.
- Zrzuty ekranu X11 okazały się nieaktualne o jedną akcję, więc zaznaczenie czytam z pamięci grupy gracza
  (+0x9B0 i +0x9AC).
- Ramkę trzeba było rysować wokół rzutów konkretnych jednostek.

Moduł działa tylko na odczycie pamięci i zwykłym wejściu, bez zapisów do procesu. Ma 3 nowe testy; razem MCP ma
21 testów i wszystkie przechodzą.

Zanotowałem trzy problemy operacyjne razem z rekomendacjami:
- zawieszony klawisz strzałki po `kam_przytrzymaj`;
- odwzorowanie minimapy;
- `gra_usun_scenariusz` bez nazwy usuwa wszystkie dawne kopie testowe MCP.

## 3. Reguły zaznaczania i rozkazów

Pełna tabela jest w `docs/MECHANIKA_RUCHU_EE.md` § 2 i § 7.

W OpenEE:
- **`ZaznaczenieEE`** – logika bez węzłów.
- **`SterowanieRTS`**:
  - klik i ramka z podglądem; próg 6 px [H];
  - Shift/Ctrl;
  - PPM = rozkaz ruchu grupy; Shift + PPM = kolejka.
- **Kryterium ramki** to rzut punktu jednostki na wysokości 0,3 [H: punkt potwierdzony, wysokość nie].
- **PPM na obiektach** nie jest odtwarzany: nie zastępuję innych rozkazów błędnym ruchem.

## 4. Reguły grup i formacji

Szczegóły: `docs/MECHANIKA_RUCHU_EE.md` § 3.

Pytania z zadania:

| Pytanie | Wynik |
|---|---|
| Czy układ jest zachowany? | Nie – grupa tworzy nowy szyk, zawsze 5 kolumn i prostopadle do marszu. |
| Czy zależy od liczebności? | Liczba rzędów = ⌈n/5⌉. |
| Czy zależy od typu? | Tylko odstęp („Size in formation”). |
| Czy cele są indywidualne? | Tak. |
| Prędkość indywidualna czy grupowa? | Indywidualna. |
| Czy jest lider? | Nie. |
| Obrót | Szybki obrót w miejscu, < 0,5 s na ~90°. |
| Jednostki zablokowane | W brodzie nie występują, bo jednostki się przenikają. |
| Układ końcowy | Siatka. |

Kolejność obsadzania miejsc według id zgadza się dokładnie dla pierwszych rozkazów grup w siatce (4 z 9 przejść).
W pozostałych regułę oznaczyłem jako [N]. Odrzuciłem 5 hipotez.

## 5. Reguły kolizji i nawigacji

Nawigacja (pathfinding) i unikanie lokalne to w EE dwie oddzielne rzeczy. Unikania lokalnego oryginał nie ma, więc
OpenEE też go nie ma. To nie jest arbitralne sterowanie: odtworzenie przenikania jest wierne pomiarowi.

Nawigacja:
- Istniejący A* rozszerzyłem o tryb **oktylowy**: zachowuje komórki trasy i upraszcza je do kanonicznych odcinków
  „przekątna, potem prosto”. Drugiego systemu ruchu nie dodałem.
- Siatka sceny RTS ma 1 komórkę na pole (wcześniej 2): trasy EE biegną przez środki pól (x,5).
- Obrys przeszkód ma promień = „Size of collider” / 2.
- Gdy cel jest nieosiągalny, jednostka idzie na najbliższe osiągalne pole w tym samym obszarze.

Szczegóły: § 5–6 dokumentu.

## 6. Zaimplementowane mechaniki

1. Zaznaczanie EE: klik, Shift, Ctrl, teren, ramka z modyfikatorami i podglądem – `zaznaczenie_ee.gd`,
   `sterowanie_rts.gd`.
2. Rozkaz ruchu grupy z szykiem EE, z własnymi celami i prędkościami – `formacja_ee.gd`,
   `Symulacja.rozkaz_grupy`.
3. Prędkość z danych × 1,46 – `Symulacja.MNOZNIK_PREDKOSCI`.
4. Trasy oktylowe przez środki pól – `Sciezki.oktylowe`, domyślnie włączone w `Symulacja`.
5. Zastępowanie rozkazu oraz kolejka Shift + PPM – `JednostkaSym.kolejka_celow`.
6. Rozkaz do terenu nieosiągalnego → najbliższe osiągalne pole – `Sciezki.najblizszy_osiagalny`.
7. Obrys budynków z „Size of collider” jako średnicy – `rts_test.gd`.
8. Przenikanie jednostek: świadomie bez kodu kolizji.
9. Animacja ruchu i bezczynności spójna ze stanem symulacji (VAT/CEM bez zmian).
10. Narzędzia:
    - `narzedzia/eksperymenty/scenariusz_testowy_ruchu.py` – scenariusz testowy;
    - `narzedzia/eksperymenty/analiza_ruchu_ee.py` – analiza trajektorii;
    - `godot/narzedzia/porownanie_ruchu_ee.gd` – porównanie i wydajność.

Kamery, epok ani przezroczystości nie zmieniałem.

## 7. Tabela zgodności EE ↔ OpenEE

| Mechanika | EE | OpenEE | Zgodność |
|---|---|---|---|
| LPM, Shift, Ctrl, teren, ramka | Jak w § 3 | Identyczne reguły | Pełna [P] |
| Kryterium ramki | Punkt jednostki | Punkt na wysokości 0,3 | Częściowa (wysokość [H]) |
| Limit zaznaczenia | ≥ 50 | Brak limitu | Zgodna do 50 |
| Budynki w zaznaczeniu | Ramka pomija budynki | Brak budynków w symulacji | Nie dotyczy |
| Szyk: kształt, orientacja, odstęp | 5 kolumn, prostopadle, „Size in formation” | Identycznie | Pełna (RMS 0,02–0,04) |
| Przydział miejsc | Według id dla pierwszego rozkazu, poza tym [N] | Według id | Częściowa |
| Prędkość | `Speed` × 1,46 | `Speed` × 1,46 | Pełna |
| Kształt tras | Oktylowe, przez środki pól | Oktylowe, przez środki pól | Pełna (krętość ±0,02) |
| Bród, przesmyk | Jedna kolumna, bez zatrzymań | Jedna kolumna, bez zatrzymań | Pełna |
| Kolizje | Przenikanie | Przenikanie | Pełna |
| Zastąpienie rozkazu | Natychmiast | Następny takt | Pełna |
| Shift + PPM | Kolejka | Kolejka | Pełna [W] |
| Cel nieosiągalny | Najbliższe pola | Najbliższe pole | Częściowa [W] |
| Formacje z przycisków, Szybko/Sprytnie | Istnieją | Brak | Brak [N] |
| Sygnalizacja rozkazu, pauza | Nie zbadane | Pauza kolejkuje rozkazy | [N] |

## 8. Wyniki testów liczbowych i wizualnych

**Testy regresyjne Godot: 230/230** (baza 207 + 23 nowe w `testy/testy_ruchu.gd`). Nowe testy obejmują:
- reguły zaznaczania, ramkę 50 jednostek, punkt w ramce;
- szyk: 1, 10, niepełny rząd, grupa mieszana;
- zgodność szyku z pomiarem EE: G5 RMS 0,022, G10 RMS 0,030;
- trasy oktylowe i ich długość;
- ruch grupy: wspólny start, miejsca, indywidualna prędkość, rozstaw;
- spójność animacji ze stanem ruchu;
- bród szerokości 1 pola: bez wejścia w wodę, jedna kolumna;
- przenikanie grup idących naprzeciw siebie, bez zatrzymań;
- budynek 2 × 2: brak przejścia;
- kolejkę Shift + PPM i zastępowanie rozkazu;
- cel w wodzie.

W dwóch testach etapu 5 poprawiłem oczekiwany czas przejścia, bo prędkość = `Speed` × 1,46. Testy kamery, epok
i przezroczystości przechodzą bez zmian.

**MCP: 21/21.**

**Porównanie liczbowe.** Wynik pochodzi z `godot/narzedzia/porownanie_ruchu_ee.gd` →
`wyniki/porownanie_ruchu_ee.json`. Warunki:
- ta sama mapa, w tym przeszkody;
- te same pozycje startowe co w pomiarze EE;
- punkt rozkazu odtworzony z układu końcowego EE.

Każda komórka podaje wartość EE / OpenEE:

| Przejście | n | Czas dojścia (s) | Droga śr. | Krętość | Min. odl. par | Rozstaw końc. | Odchyłka końc. RMS |
|---|---|---|---|---|---|---|---|
| G2 | 2 | 16,0 / 15,6 | 11,01 / 10,95 | 1,005 / 1,000 | 0,628 / 0,625 | 0,628 / 0,625 | 0,011 |
| G5 | 5 | 17,6 / 17,2 | 11,05 / 11,00 | 1,010 / 1,006 | 0,621 / 0,625 | 0,621 / 0,626 | 0,024 |
| G10 | 10 | 18,0 / 17,6 | 10,83 / 10,77 | 1,019 / 1,012 | 0,034 / 0,043 | 0,601 / 0,625 | 0,030 |
| G25 | 25 | 19,5 / 19,2 | 10,07 / 10,02 | 1,038 / 1,033 | 0,035 / 0,043 | 0,608 / 0,615 | 0,037 |
| G35 | 35 | 20,8 / 19,4 | 10,72 / 10,67 | 1,070 / 1,070 | 0,045 / 0,015 | 0,578 / 0,581 | 1,164 ¹ |
| BROD10 | 10 | 67,2 / 68,2 | 47,30 / 47,90 | 1,076 / 1,088 | 0,096 / 0,100 | 0,586 / 0,625 | 1,867 ¹ |
| BUD5 | 5 | 22,4 / 22,6 | 14,40 / 14,86 | 1,055 / 1,078 | 0,431 / 0,333 | 0,611 / 0,595 | 1,738 ¹ |
| kierB1–B4 | 10 | 9,0–9,8 / 9,8–10,0 | 5,1–5,4 / 5,2–5,6 | 1,04–1,06 / 1,04–1,07 | — | ~0,60 / ~0,62 | 0,7–1,8 ¹ |
| MIX10 | 10 | 15,3 / 12,6 | 11,68 / 10,61 | 1,093 / 1,007 | 0,216 / 0,090 | 0,635 / 0,738 | 0,741 ² |
| NAPRZ (2 grupy) | 10 | 24,1 / 20,8 | 9,57 / 9,73 | 1,021 / 1,030 | 0,077 / 0,055 | 0,762 / 0,622 | 5,18 ³ |

Przypisy do tabeli:
1. Kształt szyku i trasa są zgodne. Odchyłka wynika z innego przydziału jednostek do miejsc ([N], § 4).
   Wydłużony czas G35 w EE pochodzi z jednej spóźnionej jednostki.
2. W EE grupa mieszana dochodzi o ~20% dłużej, niż wynika z prędkości, i z krętością 1,09. Przyczyna nieustalona.
3. W teście naprzeciw jedna jednostka grupy B nie była zaznaczona i w EE nie ruszyła, a przydział miejsc jest
   odwrotny. Przenikanie bez zatrzymań jest zgodne.

**Tolerancje.** W terenie otwartym różnice wynoszą: czas ±0,4 s (2%), droga ±0,6%, pozycje końcowe ≤ 0,04 pola.
Testy regresyjne używają progu RMS ≤ 0,06 pola.

**Kontrola wizualna** (OpenEE, Troja, scena RTS z demo): trasa ma odcinki przekątne i osiowe, a HUD i animacja
ruchu działają. Brak błędów w logu.

## 9. Wydajność

Scena RTS, grupa obywateli, rozkaz na ok. 30 pól z przeszkodami, stały krok 50 ms:

| Jednostek | Przygotowanie mapy, raz na politykę (ms) | A* dla całej grupy w takcie rozkazu (ms) | Takt maks. (ms) | Takt mediana (µs) | Takt śr. (µs) | Odwiedzone komórki A* |
|---|---|---|---|---|---|---|
| 10 | 47,2 | 23,1 | 23,2 | 9 | 30 | 1345 |
| 25 | 47,1 | 31,5 | 31,7 | 22 | 50 | 3100 |
| 50 | 47,3 | 38,4 | 38,6 | 43 | 75 | 4486 |
| 100 | 47,4 | 49,5 | 49,9 | 85 | 121 | 7141 |

Ruch po rozkazie kosztuje ≤ 0,1 ms na takt przy 100 jednostkach, a unikania lokalnego nie ma, więc nic go nie
liczy. Koszt skupia się w takcie wydania rozkazu: A* dla każdej jednostki, ~0,5 ms na trasę. Przy 100 jednostkach
ten takt dochodzi do budżetu 50 ms.

Stały krok jest zachowany: `ZegarSymulacji` nadrabia takty, a deterministyczność się nie zmienia. Możliwa
optymalizacja na później to rozłożenie wyszukiwania tras na kilka taktów albo wspólna trasa grupy z rozejściem
przy celu. To byłaby jednak zmiana zachowania względem EE, więc jej nie wprowadzam.

## 10. Nierozwiązane różnice

1. Przydział jednostek do miejsc szyku poza pierwszym rozkazem grupy ułożonej w siatkę [N].
2. Grupa mieszana: wolniejsze dojście i większa krętość w EE [N].
3. Formacje z przycisków (8) i tryb Szybko/Sprytnie – nie zbadane, nie odtworzone.
4. Dokładna wysokość punktu jednostki w teście ramki [H].
5. Wróg i sojusznik w zaznaczeniu; zaznaczenie budynków w OpenEE (budynki nie są obiektami symulacji).
6. Sygnalizacja rozkazu (znacznik, dźwięk) i zachowanie w pauzie oryginału – nie zbadane.
7. Cel w wodzie: jedna próba [W]; nie potwierdzono, że punkt leżał na głębokiej wodzie.
8. PPM na obiektach (atak, zbieranie, wejście) – poza zakresem etapu.
9. Różnice EE 1.0 ↔ AoC – nie badane.

## 11. Stan repozytorium

- **Lokalny HEAD:** commit etapu 9 „Etap 9: sterowanie jednostkami i ruch grupowy wg pomiarów EE”, na `main`,
  bezpośrednio po `6031c4a` (etap 8). Hash jest widoczny w `git log -1`; sam raport należy do tego commita, więc
  nie może zawierać własnego hasha.
- **Commity do publikacji:** 5 względem GitHuba (`c3d717d..HEAD`): 4 wcześniejsze lokalne + etap 9.
- Bez pusha, bez `reset --hard`, `pull --rebase` i `push --force`.
- Kopia przed etapem: `kopie_OpenEE/OpenEE_przed_etapem9_6031c4a.bundle`.
