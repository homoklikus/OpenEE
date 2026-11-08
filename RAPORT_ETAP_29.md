# OpenEE – raport etapu 29: nawigacja i kolizje w C++, automatyzacja Riverlands_MCP i prognoza rekonstrukcji Titan

Etap 29 łączy fizykę OpenEE Core z nawigacją, testem kroku, kolizjami i kolejką celów. Rozbudowuje Riverlands_MCP,
tak że eksperymenty z oryginalną grą nie zależą od ręcznego zaznaczania. Zawiera też niezależną prognozę
rekonstrukcji EE/AoC.

Szczegóły:
- `docs/PLAN_REKONSTRUKCJI_TITAN.md` – mapa systemów, zależności, strategia narzędzi, prognoza;
- `docs/cpp/*.md` – moduły, budowanie, API;
- `docs/titan/walidacja_kolizji.md` § 10, `fizyka_terenu.md` § 4, `kolizje_objazdy.md` § 12, `astar_wyniki.md` § 10.

**Oznaczenia:**
- **[P]** potwierdzone kodem i pomiarem;
- **[W]** wniosek z kodu;
- **[H]** hipoteza;
- **[N]** nieustalone.

## 1. Stan wyjściowy

- Commit `a49db42`.
- CTest 9 grup, GDExtension 17/17, Godot 324/324, S1–S7 bitowo, Debug = Release.

**Rozbieżności dokumentacji z kodem znalezione przy analizie:**
- `ARCHITEKTURA_CORE.md` § 9 opisywał test kroku i listę kontaktów jako niewdrożone. Zgadzało się to z kodem, teraz
  oba są wdrożone.
- Atlas (`fizyka_terenu.md` § 4) twierdził, że test kroku zatrzymuje jednostkę na polu ze środkiem innej jednostki.
  Pomiar etapu 29 to obalił (§ 4).
- `kolizje_objazdy.md` § 2 opisywał listę kontaktów tylko przez środki pól. Pomiar wskazuje obrys obiektu (§ 5).

## 2. Zaimplementowane moduły C++

| Moduł | Pliki | Stan |
|---|---|---|
| A* po polach + Bounded | `nawigacja.hpp/.cpp` | wdrożony; kary za jednostki [W], duże jednostki – nie |
| prośba o trasę (Bounded → pełne A*, punkty, dokładny cel) | `symulacja.cpp` (`przygotuj_trase`) | wdrożony, synchronicznie (w grze trasa przychodzi po kilku taktach) |
| przejezdność pól, linie rombu | `teren.hpp/.cpp` | wdrożona; import z mapy – nie |
| test pojedynczego kroku | `fizyka.cpp` (`test_kroku`) | wdrożony |
| lista kontaktów, 0x549179 w takcie, reguła (a), 0x549A08, budzik, +0x248 | `symulacja.cpp` | wdrożone; kolejność EE/AoC [W], obrys [H] |
| kolejka celów, Shift, aktywacja po Idle | `symulacja.cpp` (`rozkaz_ruchu`, `aktywuj_cel`) | wdrożona (poziom 0); +0x32, BO-4, porzucenie – nie |
| 9002 (A* ±50) | `symulacja.cpp` | częściowy, **niezweryfikowany** |
| GDExtension: `rozkaz_ruchu`, `ustaw_przejezdnosc`, diagnostyka kolizji i A* | `cpp/gdextension` | wdrożone |

## 3. Wyniki A*

`core_astar`: 18/18 przypadków zgodnych z niezależnym modelem etapu 24 w:
- kolejności rozwijania węzłów (pełny przebieg);
- trasie, liczbie iteracji i liczbie wywołań;
- fladze +0x28 i powodzie zakończenia.

| Grupa przypadków | Liczba | Iteracje / wywołania |
|---|---|---|
| ściany, luka, pułapka U | 3 | 78 / 5, 585 / 23, 149 / 8 |
| cel zamknięty | 1 | 876 / 32 |
| cel niedostępny | 1 | – |
| narożniki, bez reguły narożników | 2 | – |
| limit całkowity | 1 | 120 / 7 |
| kary | 1 | – |
| Bounded bez testu dostępności końca | 1 | – |
| brzeg mapy | 1 | – |
| losowe mapy 48×48 (27% przeszkód) | 6 | – |

`core_astar_gra` (mapa z gry, lokalnie):
- trasy A i C identyczne z pomiarem gry;
- przypadek E: 145 iteracji w 8 wywołaniach = gra [P].

Test nie zalicza samego dojścia do celu – liczy się trasa i przebieg.

## 4. Wyniki testu kroku

`core_krok`: 9 izolowanych gałęzi zaliczonych:
- to samo pole, pole przejezdne;
- ślizg wzdłuż y, cofnięcie po trzech próbach;
- przekątna z jedną komórką boczną, zakaz ścinania między dwiema przeszkodami;
- jednostka blokująca (+0x20C, +0x330 = 2), poza mapą, linia rombu.

**Korekta wiedzy [P].** W pomiarach 546 i 547 jednostka w ruchu weszła na pole ze środkiem stojącej jednostki, a
+0x20C pozostało 0. Zwykłe jednostki nie blokują pola w teście kroku. Core ich nie liczy. Mechanizm +0x20C zostaje dla
obiektów blokujących.

Przed poprawką porównanie z grą dawało:
- 546: błąd do 5,7 pola;
- 547: błąd do 4,9 pola.

Po poprawce: 0 i 0,02 pola.

## 5. Wyniki kolizji

`core_kolizje_takt`:
- **ruchoma → stojąca większa** (promień 0,55): 28 kolizji, 10 kroków odpychania ruchomej, stojąca bez ruchu
  (ro > ru → budzik);
- **reguła (a):** v = 0, +0x330 = 8, rozkaz kończy się 9000 → 9006 → 5001 → 5000;
- **czołowe:** EE i AoC dają w tym układzie identyczny wynik (różnica kolejności kontaktów nie ujawnia się).

**Porównanie z grą** (EE 547, dwie jednostki w ruchu):

| Miara | Wynik |
|---|---|
| średni błąd pozycji | 0,0003 i 0,0001 pola |
| maksymalny błąd pozycji | 0,021 pola |
| takty z inną obecnością kontaktu | **0 / 1397** |
| takty z inną obecnością +0x248 | 0 |
| takty z innym stanem | 8 (chwila rozkazu ±1 takt) |

Lista kontaktów z obrysem obiektu jest hipotezą [H] wspieraną tym pomiarem. Wersja „tylko środki pól” nie dawała
kontaktu przed nałożeniem się jednostek.

Nie deklarujemy zgodności wszystkich kolizji. Nie są sprawdzone:
- duże jednostki;
- grupy;
- AoC dynamicznie;
- jednostki różnych typów w ruchu.

## 6. Kolejka celów i Shift

`core_kolejka`:
- zwykły rozkaz → 8000 i 1 cel;
- dwa Shift → 3 cele, stan bez zmian;
- wykonanie A → B → C w kolejności, końce w odległości < 0,06 od celów;
- pusta kolejka → Idle;
- zwykły rozkaz czyści kolejkę;
- Shift bez celu działa jak zwykły rozkaz.

Zgodne z `kolejka_rozkazow.md` [P: pomiar etapu 21 dla kolejki].

Przejście do następnego celu w ruchu (moment, droga) nie ma pomiaru dynamicznego [W]. Punkty +0x32 nie są
wdrożone.

## 7. Integracja z maszyną stanów

- Rozkaz ustawia stan 8000. Wejście w 8000 przygotowuje trasę (A*). Dalej: MovePreparationComplete → 2015 → 10003.
- Wejście w Idle zdejmuje cel i aktywuje następny (stan 8000 w tym samym takcie).
- ObstacleDetected (+0x20C albo +0x248 > T) prowadzi do 9002 → A* ±50 → Advance.
- Skrypt `land` bez zmian. Parser sparsował oryginalny `land.tai` – stany ruchu są zgodne ze skryptem wbudowanym
  (`core_tai` z `OPENEE_TAI`).

## 8. Pełne przebiegi jednostek

`core_scenariusze` – wszystkie bez wejścia na pola nieprzejezdne:

| Scenariusz | Wynik |
|---|---|
| prosta trasa | 7 punktów, koniec w takcie 358 |
| objazd ściany | A* 35 iteracji / 3 wywołania, 13 punktów, koniec w takcie 706 |
| zakręty | koniec w takcie 480 |
| cel nieosiągalny | A* 3000 iteracji (limit), zatrzymanie przy najbliższym polu |
| dwie jednostki do wspólnego celu | obie kończą: druga przez regułę (a) albo odpychanie |

- Scenariusz „jednostka ruchoma i stojąca” jest w `core_kolizje_takt`, a „dwa cele Shift” w `core_kolejka`.
- Skróty przebiegów to regresja Core, a **nie porównanie z Titan**. Debug i Release (GCC 11.4 i 13.3) mają
  identyczne skróty.

## 9. Porównania z Titan

`core_porownanie_gra` (dane lokalne `Testy_MCP/e29`) uruchamia Core z tymi samymi:
- stanem początkowym (pozycja i macierz z pamięci gry);
- parametrami i punktami trasy;
- terenem.

Metryki porównuje takt po takcie.

| Seria | Pozycja śr / max | v śr / max | Kąt śr / max | Koniec | Pierwszy rozbieżny | Inny stan | Inny punkt |
|---|---|---|---|---|---|---|---|
| EE 500 | 0,0082 / 0,0497 | 0,0012 / 0,332 | 0,19° / 4,9° | +0 | 48 | 21/813 | 8 |
| AoC 505 | 0,0016 / 0,0148 | 0,0001 / 0,068 | 0,12° / 3,2° | +0 | 224 | – | 1 |
| EE 517 krótki | 0,0062 / 0,0131 | 0,0086 / 0,068 | 2,30° / 10,6° | +0 | 2 | 0/69 | 0 |
| EE 517 1,4 pola | 0,0000 / 0,0000 | 0 / 0 | 0,00° / 0,1° | +0 | brak | 0/86 | 0 |
| AoC 525 krótki | 0,0259 / 0,0492 | 0,0317 / 0,069 | 0,02° / 0,9° | −3 | 2 | – | 3 |
| AoC 525 1,9 pola | 0,0005 / 0,0110 | 0,0085 / 0,136 | 0,01° / 0,2° | −2 | 68 | – | 1 |
| EE 547 (2 jednostki) | 0,0003 / 0,021 | – | – | – | 766 / 724 | 8 / 8 | – |
| EE 546 (ruch obok stojącej) | 0,0000 / 0,0000 | – | – | – | brak | 7 | – |

- Metryki pojedynczych serii są identyczne z metrykami modelu v4 Python (Core = bitowy port).
- **RNG:** gra ok. 12 kroków LCG na takt (11–33 między próbkami), Core ok. 2,4. Różnica wynika z AI i innych systemów, których Core nie ma.
- **546:** 445 taktów z inną obecnością kontaktów, bo pozostałe jednostki sceny nie są symulowane w Core.
- Bez danych lokalnych test ma status SKIP, a nie zaliczony.

## 10. Rozbudowa Riverlands_MCP

Moduł `ee_obserwacja.py`:
- `obs_jednostki`, `obs_wybierz`, `obs_rozkaz`;
- `obs_rejestruj` + `_start` / `_stop`;
- `obs_metryki`;
- odczyt pierwszego i ostatniego punktu trasy.

Testy MCP: 10 plików (+1) – wszystkie OK. Dokumentacja: `RAPORT_ROZBUDOWA_EE_MCP.md` § 20. Commit lokalny w
prywatnym repozytorium (`1a77500`), poza OpenEE.

## 11. Nowe możliwości automatyzacji

- **Wybór obiektu do obserwacji (adres)** jest niezależny od zaznaczenia w grze.
- **Rozkazy dla konkretnej jednostki z weryfikacją**, także w trakcie rejestracji w tle.
- **Seria z MCP trafia do testu Core:** jeden konwerter i `core_porownanie_gra`. Obieg „pomiar → porównanie →
  regresja” jest zamknięty.
- **Dwie jednostki naraz:** po jednym zadaniu MCP dla każdej, rejestracja wszystkich co takt.

## 12. Test dwóch poruszających się jednostek

**Uzyskany [P].** EE 547:
- 18c ruszyła na wschód, 18e dostała rozkaz na zachód 8 s później;
- obie w Advance jednocześnie przez 92 takty, czołowe zbliżenie na 0,334;
- kontakty i odpychanie zarejestrowane.

Rozkazy dostały właściwe jednostki, co potwierdza stan 8000 → 2015 → 10003 i cele w kolejce trasy każdej z nich.

**Wcześniejsze próby w tym etapie:**
- 543 – rozkazy niezależne, ale bez jednoczesnego ruchu;
- 544 – rozkaz w pauzie utracony po zaznaczeniu drugiej jednostki;
- 545–546 – cel poza kadrem albo na rzucie jednostki; narzędzie odmówiło zgodnie z założeniem.

Przypadek referencyjny: `Testy_MCP/e29/serie_porownawcze.json` → `wielojednostkowe` (lokalnie).

## 13. Status RepathAroundObstacle

- **Niepotwierdzony [N].** Próba 548 (cel za murem) nie wystartowała: rzut celu był poza kadrem.
- We wcześniejszych etapach licznik +0x248 nie przekroczył 2,9 s.
- W Core 9002 to A* w oknie ±50 pól z flagą „niezweryfikowany” (`objazdy_niezweryfikowane`).
- Następny krok: narzędzie kamery „pokaż punkt” (§ 3.3 planu) i rozkaz przez mur / brzeg z rejestracją co takt.

## 14. Wpływ automatyzacji na efektywność

| Miara | Etap 27 | Etap 29 | Rodzaj |
|---|---|---|---|
| zaznaczenie 18d (zasłonięta przez 55c) | niewykonalne (kilka zadań) | 4 próby automatyczne, ok. 7 s | pomiar |
| kroki zadania na 15 s rejestracji 5 jednostek | ok. 500 (`pamiec_u32` + `czekaj`) | 1 | pomiar |
| próbki co takt | ok. 1 z duplikatami, odfiltrowywanymi później | 1 na takt, 0 luk, 0 niespójnych (601–1662 próbek) | pomiar |
| jednostki w jednej próbce | 1–5 przy dużej liczbie kroków | 5, wszystkie pola, RNG, trasa | pomiar |
| prawidłowe serie dwóch jednostek w ruchu | 0 z 4 zadań | 1 z 5 zadań (+1 seria mijania) | pomiar |
| ręczne operacje na serię | konwersja, szacowanie celu z serii, osobny model Python | zapis gotowy do konwersji, cel z pamięci | pomiar (jakościowy) |
| czas wykrycia rozbieżności Core ↔ gra | analiza w modelu Python | uruchomienie `core_porownanie_gra` (< 1 s); błąd testu kroku znaleziony w tym etapie | pomiar |
| przyspieszenie przyszłych badań | – | 1,25–1,4× (średnio) | **szacunek** (`PLAN_REKONSTRUKCJI_TITAN.md` § 4.4) |

## 15. Inwentaryzacja pozostałych mechanizmów

`docs/PLAN_REKONSTRUKCJI_TITAN.md` § 1:
- 32 systemy;
- dla każdego: stan, dowody, niewiadome, trudność 1–5, eksperymenty, potrzebne możliwości MCP, zależności.

Bez procentów ukończenia.

Najtrudniejsze:
- AI strategiczne (5);
- walka i pociski, AI taktyczne, multiplayer, jednostki specjalne (4).

## 16. Prognoza rozpracowania EE/AoC

Model z danych projektu (§ 4 planu):
- jednostka nakładu J = podsystem ruchu lądowego: ok. 17 h pracy agenta + ok. 8 h użytkownika, z historii Git i
  zadań MCP etapów 14–29;
- wagi podsystemów w J [H];
- mnożnik rosnącej złożoności;
- przyspieszenie z udziałów pracy i redukcji zmierzonych w etapie 29, pomniejszone o koszt narzędzi.

Uwzględniono cały warsztat i jego przyszły rozwój:
- REA (Cutter/rizin) i Ghidra – mapy dostępu do pól, wspólny opis struktur, zbiorcza dekompilacja;
- Riverlands_MCP – rejestratory walki i ekonomii, kamera, pełne kolejki, licznik RNG;
- OpenEE Core – testy porównawcze.

Proces REA/Ghidra → algorytm → eksperyment MCP → pomiar → porównanie z Core → regresja działa już dla ruchu.

**Reverse engineering** (składnik nakładu przy realistycznym rozwoju narzędzi):

| Cel | RE | Razem |
|---|---|---|
| A (grywalne) | ok. 66 h | ok. 120 h |
| B (wierne główne) | ok. 165 h | ok. 304 h |
| C (prawie pełne) | ok. 290 h | ok. 536 h |

## 17. Prognoza implementacji OpenEE

Nakład łączny dla celu B – wariant realistyczny, 18 h tygodniowo:

| Model narzędzi | Nakład | Czas kalendarzowy |
|---|---|---|
| bez rozwoju | 380 h | ok. 21 tygodni |
| realistyczny rozwój | 304 h | **ok. 17 tygodni** |
| silna automatyzacja | 271 h | ok. 15 tygodni |

| Cel | Realistyczny rozwój | Zakres ostrożny – optymistyczny |
|---|---|---|
| A | ok. 7 tygodni | 3,5–19 |
| C | ok. 30 tygodni | 15–86 |

Podział B (realistyczny):

| RE | C++ | Godot | Testy zgodności | MCP |
|---|---|---|---|---|
| 165 h | 64 h | 21 h | 30 h | 24 h |

- Przyspieszenie nie przekracza ok. 1,4× średnio (asymptotycznie 1,28–1,43×). Ograniczają je statyka nowych
  systemów, przegląd użytkownika i AI strategiczne.
- Niepewność: B −30% / +80%, C −30% / +120% (waga AI 2–6 J).
- **To nie jest obietnica terminu.**

## 18. Testy i regresja

System testowy: **Ubuntu 22.04 (GCC 11.4, glibc 2.35, maszyna z Godotem 4.7.2) i Ubuntu 24.04 (GCC 13.3)**. Debian 13
nie był dostępny.

| Test | Wynik |
|---|---|
| CTest Release GCC 11.4 (z DLL i danymi lokalnymi) | 16/16 zaliczonych |
| CTest Debug GCC 11.4 | 16/16 zaliczonych |
| CTest GCC 13.3 bez danych lokalnych | 14 zaliczonych, 2 **pominięte** (`astar_gra`, `porownanie_gra`) |
| S1–S7 | bitowo, skrót `c36721320b3595e4` – bez zmian po dodaniu kolizji i testu kroku |
| Debug = Release | skróty S1–S7, scenariuszy i kolizji identyczne (GCC 11 i 13) |
| GDExtension | **18/18** (17 dotychczasowych + rozkaz z A*, objazd ściany i Shift przez Godota) |
| Godot (dotychczasowe) | **324/324** |
| testy Riverlands_MCP | 10/10 plików |
| `git diff --check` | czysto |

## 19. Problemy nierozwiązane

1. 9002 bez pomiaru [N]. Brak narzędzia kamery dla celów poza kadrem.
2. Reguła obrysu w liście kontaktów [H]. Kolejność EE/AoC bez testu AoC [W].
3. Reguła (a): zaliczenie punktu po zatrzymaniu [H].
4. Trasa synchroniczna w Core, a w grze rozłożona na takty [W] – inna chwila startu przy długich trasach.
5. Kary A* za jednostki i duże jednostki bez pomiaru [W/N].
6. Losowania RNG: Core odtwarza ok. 20% kroków LCG na takt – lockstep z oryginałem wymaga AI i pozostałych systemów.
7. Import przejezdności i obiektów z mapy scenariusza do `TerenSiatka` – niewdrożony.
8. Znak drgania ω (EE 500) – bez zmian [N].

## 20. Rekomendacja etapu 30

Etapu 30 nie rozpoczęto. Proponowany zakres:
1. **Narzędzia MCP:**
   - kamera „pokaż punkt”;
   - pełna kolejka celów i trasy;
   - konwerter serii jako funkcja MCP.

   Potem pomiar 9002 (rozkaz przez mur) i grup (szyk) z rejestracją wszystkich jednostek.
2. **Import mapy scenariusza do Core:** wysokości, przejezdność terenu dla typu, obiekty blokujące. Porównanie tras i
   ruchu na mapie kampanii testowej.
3. **REA:** skrypt mapy dostępu do pól i wspólny opis struktury jednostki (EE/AoC).
4. **Początek walki:**
   - rejestrator HP, celu i czasów ataku;
   - analiza statyczna wyboru celu i zadawania obrażeń;
   - pojedynki 1:1 jako pierwsze serie referencyjne.

## Zmiany w repozytorium

- **Nowe pliki:**
  - `cpp/core/include/openee/nawigacja.hpp`, `cpp/core/src/nawigacja.cpp`;
  - `cpp/tests/dane/astar_referencja.json`;
  - `docs/PLAN_REKONSTRUKCJI_TITAN.md`.
- **Zmienione:**
  - Core: teren, jednostka, fizyka, symulacja;
  - testy (16 grup), GDExtension i `godot/testy/testy_gdextension.gd`;
  - `docs/cpp/*`, atlas (`fizyka_terenu`, `kolizje_objazdy`, `walidacja_kolizji`, `astar_wyniki`,
    `testy_referencyjne_ruchu`, `specyfikacja_ruchu_godot`).
- `RAPORT_ETAP_28.md` przeniesiony do `raporty/archiwum/`. Zaktualizowane:
  - `raporty/README.md`, `README.md`;
  - `docs/HISTORIA.md`, `docs/ARCHITEKTURA_OPENEE.md`, `docs/titan/README.md`;
  - `dane/launcher/aktualnosci.json`.
- **Bez zmian:** `godot/project.godot` (lokalna zmiana użytkownika), sceny gry GDScript.
- Riverlands_MCP nie jest częścią repozytorium. Prywatne serie są lokalnie w `Testy_MCP/e29` i
  `Testy_MCP/ee_obserwacja`.

Jeden commit lokalny. Bez `git push`.
