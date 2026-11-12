# Postęp rekonstrukcji silnika Titan

Dokument stały, aktualizowany w każdym etapie (od etapu 49). Opisuje, ile silnika Titan (Empire Earth / The Art of
Conquest) rozpoznano, ile odtworzono w OpenEE i ile potwierdzono pomiarem. Zmiany ocen uzasadnia się w rozdziale
„Historia ocen” na końcu, przyrostowo, bez przeliczania wszystkiego od nowa. Ocena może spaść, jeśli podsystem okaże
się większy, niż zakładano.

## 1. Co znaczy „rozpracowanie silnika”

Rozróżniamy trzy cele i ich nie mieszamy:

- **A. Rozpoznanie Titan** – wiemy, jakie są struktury danych, algorytmy, funkcje i zależności oryginału (kod EXE/DLL,
  pomiar pamięci). Źródła: `docs/titan/*.md`.
- **B. Implementacja OpenEE** – rozpoznany mechanizm jest odtworzony w niezależnym kodzie (Core C++ `cpp/core`,
  GDExtension, moduły Godot).
- **C. Zgodność zachowania** – OpenEE daje takie same wyniki jak oryginał w kontrolowanych eksperymentach (nagrania MCP
  co takt, testy bitowe).

Podsystem może mieć wysokie A i niskie B (wiemy, ale nie napisaliśmy) albo wysokie B i niskie C (napisane, niezmierzone).

## 2. Skala ocen (osobno dla A, B, C)

| Ocena | Znaczenie |
|---|---|
| 0 | niebadany |
| 1 | wstępnie rozpoznany (klasy, adresy, pojedyncze obserwacje) |
| 2 | częściowo rozpoznany lub zaimplementowany |
| 3 | zasadniczy mechanizm działa (w swoim zakresie) |
| 4 | szeroko przetestowany (wiele nagrań / przypadków) |
| 5 | kompletny w jasno zdefiniowanym zakresie i potwierdzony pomiarami |

Żaden podsystem nie ma oceny 5: nawet najlepiej zbadane (ruch, A*) mają znane braki. Ocena 4 nie oznacza
kompletności, tylko szerokie potwierdzenie zakresu, który już zbadano.

## 3. Katalog podsystemów i oceny (stan po etapie 49)

| # | Podsystem | A rozpoznanie | B implementacja | C zgodność | Pewność | Główny dowód |
|---|---|---|---|---|---|---|
| 1 | Wczytywanie plików i baz db*.dat | 4 | 4 | 4 | wysoka | FORMATY*.md, importery Godot, porównania tabel EE/AoC |
| 2 | Format SCN i serializacja | 3 | 3 | 3 | średnia | import_mapy.md, generator czystych map, 4133 rekordów e42 |
| 3 | Mapa i warstwy terenu | 3 | 3 | 3 | wysoka | GetMeshZ bitowo z DLL, klasyfikacja pól 99,6 % |
| 4 | Obiekty mapy i zajętość pól | 3 | 3 | 3 | średnia | listy pól EEMap (zad. 552), 647/650 – budynek na 4 polach |
| 5 | Graf nawigacji (podsektory) | 3 | 3 | 3 | średnia | e35_a zgodna, przebudowa przyrostowa, koszary 2×2 = gra |
| 6 | Pathfinding (A*, Bounded, graf) | 4 | 4 | 4 | wysoka | 18 przypadków bitowo, 648 trasa = gra |
| 7 | Fizyka ruchu (EEPMLand) | 4 | 4 | 4 | wysoka | S1–S7, 644 4148/4148, 648 prorok 3585/3585 |
| 8 | Kolizje (kontakty, odpychanie) | 4 | 3 | 3 | średnia | 0x549179 z gałęzią omijania, budynki w listach (652), 644/648/649 zgodne |
| 9 | Kolejka fizyki i kolejność taktu | 3 | 3 | 3 | średnia | lista 0x918DDC (639), 649 koszary – budynek na liście |
| 10 | Maszyny stanów .tai | 3 | 3 | 3 | średnia | Generic Movement/Attack, Prophet.tai, budynek |
| 11 | System celów i rozkazów | 3 | 3 | 3 | średnia | kolejka celów, Shift, EEUGAttackUnit, EEUGLocation |
| 12 | Walka i obrażenia | 3 | 3 | 3 | średnia | pojedynek 564, 631–634, dom 1v1 / 3v1 do śmierci |
| 13 | Śmierć i usuwanie | 3 | 3 | 3 | średnia | 6000–6003, gruz 361/362, zapadanie budynku |
| 14 | Budynki i budowanie | 2 | 2 | 2 | niska | zniszczenie i graf [P]; postaw_budynek [W] |
| 15 | Jednostki cywilne | 1 | 1 | 1 | niska | ruch i ucieczka obywatela (638) |
| 16 | Zbieranie surowców | 0 | 0 | 0 | – | – |
| 17 | Ekonomia (zasoby, populacja) | 0 | 0 | 0 | – | – |
| 18 | Produkcja jednostek | 0 | 0 | 0 | – | – |
| 19 | Technologie, epoki, ulepszenia | 1 | 1 | 1 | niska | premia prędkości gracza 0x627078 / SetSpeed [W+P] |
| 20 | AI gracza komputerowego | 1 | 0 | 0 | niska | klasy EEComputerPlayer ×5 w każdej grze testowej (652) |
| 21 | Dyplomacja i relacje | 1 | 1 | 1 | niska | tablica gracza +0x9E4 (wrogowie), sojusz 644 |
| 22 | Widoczność i fog of war | 1 | 1 | 1 | niska | CanISeeEnemy pierwszy takt (G etapu 48), widoczny_dla [H] |
| 23 | Świat, zwierzęta, obiekty neutralne | 1 | 0 | 0 | niska | zwierzęta losują RNG (644/646) |
| 24 | Transport lądowy i morski | 0 | 0 | 0 | – | – |
| 25 | Lotnictwo | 0 | 0 | 0 | – | – |
| 26 | Animacja jednostek | 2 | 2 | 1 | średnia | sekwencje dbgraphics, klatki śmierci (Core) |
| 27 | Efekty graficzne i dźwięk | 1 | 1 | 1 | niska | render Godot (RAPORT_ZGODNOSCI_RENDEROWANIA) |
| 28 | Sterowanie gracza i interfejs | 2 | 2 | 1 | średnia | kamera [P], PPM/ramka/Shift w potyczce |
| 29 | Warunki zwycięstwa, scenariusze, wyzwalacze | 0 | 1 | 0 | – | prosty warunek w potyczce |
| 30 | Multiplayer i synchronizacja | 1 | 0 | 0 | niska | lockstep, przydział taktów (DLL) |
| 31 | Zapis i wczytanie stanu gry | 0 | 0 | 0 | – | – |
| 32 | Losowość i deterministyczna symulacja | 3 | 3 | 2 | średnia | LCG, 2 losowania/takt, 646 190 taktów autonomicznie |
| 33 | Zegar symulacji i takt | 4 | 4 | 4 | wysoka | zegar_symulacji.md, przydzial_taktow.md |
| 34 | Efekty obszarowe i morale | 3 | 3 | 2 | średnia | EEAEMoraleFromBuildings, przebieg 2000 ms [P: kod] |
| 35 | Bohaterowie i leczenie | 2 | 2 | 2 | średnia | EEUGHeal (644 sojusz) |
| 36 | Kalamity (prorok, kapłan) | 1 | 0 | 0 | niska | Prophet.tai, klasy EEPCalamity* |
| 37 | Grupy i szyk (formacje) | 2 | 0 | 0 | niska | grupy_ruchu.md, parametry szyku [P] |
| 38 | Edytor scenariuszy | 0 | 0 | 0 | – | – |

Katalog ma 38 pozycji: 32 z listy zadania etapu 49 i 6 dodanych po przeglądzie klas RTTI (zegar symulacji, efekty
obszarowe i morale, bohaterowie i leczenie, kalamity, grupy i szyk, edytor scenariuszy). Pozycje mają bardzo różną
wielkość – np. „AI gracza komputerowego” (69 klas `EEAI*` i ok. 60 `EECP*`) jest wielokrotnie większa niż „zegar
symulacji”.

## 4. Liczby zbiorcze

**Rozkład ocen** (liczba podsystemów na poziomach 0–5):

| Oś | 0 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|---|
| A | 8 | 9 | 5 | 11 | 5 | 0 |
| B | 12 | 6 | 4 | 12 | 4 | 0 |
| C | 13 | 7 | 4 | 10 | 4 | 0 |

- Podsystemy z zasadniczym mechanizmem (ocena ≥ 3): A 16, B 16, C 14 z 38.
- Podsystemy niebadane albo tylko wstępnie rozpoznane (≤ 1): A 17, B 18, C 20 z 38.
- Niebadane wcale (A = 0): Zbieranie surowców, Ekonomia (zasoby, populacja), Produkcja jednostek, Transport lądowy i morski, Lotnictwo, Warunki zwycięstwa, scenariusze, wyzwalacze, Zapis i wczytanie stanu gry, Edytor scenariuszy.

**Średnia ocen bez wag** (tylko jako wskaźnik kierunku zmian, nie procent silnika): A 1.89, B 1.74,
C 1.61 na 5. Skala jest porządkowa, a podsystemy nie mają równej wielkości, więc średnia **nie jest** procentem
ukończenia. Wag nie przypisujemy, bo nie ma wiarygodnej miary wielkości podsystemów.

**Wskaźniki obiektywne pokrycia kodu oryginału** (EE `Empire Earth.exe`, e352d7ae…) [P: narzędzia]:

| Wskaźnik | Wartość | Uwagi |
|---|---|---|
| procedury w analizie Ghidra | 25 928 | razem z CRT, bibliotekami i UI |
| różne adresy EE (0x401000–0x6FFFFF) cytowane w `docs/titan` | 880 | górne oszacowanie funkcji rozpoznanych; część to adresy wewnątrz funkcji lub dane – ok. 3 % procedur |
| adresy EE cytowane w kodzie Core | 313 | mechanizmy z odwołaniem do oryginału w `cpp/core/src` |
| klasy RTTI w EXE | 1243 | w tym 356 `EEUI*` (interfejs), 69 `EEAI*`, ok. 120 `EEC*` (AI komputera) |
| klasy RTTI wymienione w dokumentacji / Core | 88 | ok. 7 %; wymienienie ≠ rozpoznanie |
| kod Core | ok. 4 800 wierszy C++ | `cpp/core/src` |

Wniosek: rozpoznana i odtworzona jest głównie **warstwa symulacji ruchu i walki pojedynczych jednostek lądowych**
(ruch, trasy, kolizje, stany `.tai`, walka wręcz, śmierć, budynki jako cele i przeszkody). To rdzeń, od którego
zależy reszta, ale w liczbie funkcji to kilka procent programu. Gospodarka, produkcja, technologie, AI komputera,
transport, lotnictwo, zapis gry i multiplayer są prawie nietknięte.

## 5. Pozostałe prace do pełnej rekonstrukcji

| # | Podsystem | Brakuje | Brak dotyczy | Zależności | Trudność | Następny kamień milowy |
|---|---|---|---|---|---|---|
| 1 | Wczytywanie plików i baz db*.dat | pola „Unknown” baz, część znaczeń kolumn | wiedza | – | niska | opis wszystkich kolumn dbobjects używanych przez Core |
| 2 | Format SCN i serializacja | dane cywilizacji graczy, wyzwalacze, zapis SCN z Core | wiedza+kod | 1 | średnia | odczyt cywilizacji gracza z SCN (premie atrybutów) |
| 3 | Mapa i warstwy terenu | klify [N], woda, zmiany terenu | wiedza | 1, 2 | średnia | klify i woda w klasyfikacji pól |
| 4 | Obiekty mapy i zajętość pól | obrót budynków, obiekty Świata (drzewa) jako kontakty [N] | wiedza+weryfikacja | 2, 3 | średnia | pomiar drzew i obiektów Świata w listach kontaktów |
| 5 | Graf nawigacji (podsektory) | obszary +0xF4 – model z pomiaru, dodanie budynku w grze niezmierzone | weryfikacja | 3, 4 | średnia | pomiar grafu po postawieniu budynku |
| 6 | Pathfinding (A*, Bounded, graf) | gałęzie 0x4A2214 i n < 5 w 0x4A2B29, objazd 9002 bez pomiaru | weryfikacja | 5 | średnia | wymuszenie RepathAroundObstacle w grze |
| 7 | Fizyka ruchu (EEPMLand) | końcowy obrót przy kursie ≈ docelowemu (koszary 650), inne tryby fizyki (morze, powietrze) | weryfikacja | 3, 9 | niska | obrót końcowy proroka w 650 |
| 8 | Kolizje (kontakty, odpychanie) | duże jednostki 0x548A3C [H], brama, drzewa, obiekty Świata | kod+weryfikacja | 4, 7 | średnia | kolizja dużych jednostek (≥ 1,0) – pomiar |
| 9 | Kolejka fizyki i kolejność taktu | kiedy budynek wchodzi na listę fizyki przed śmiercią (649: na liście żywy) | wiedza | 7 | średnia | odczyt chwili dodania budynku do listy |
| 10 | Maszyny stanów .tai | zdarzenia klątw, transportu, budowy, zbierania | kod | 11 | średnia | zdarzenia cywilne (Gather/Build) |
| 11 | System celów i rozkazów | EEUGGather, EEUGBuildRepair, Patrol, Load/Unload, HealUnit tylko częściowo | kod+wiedza | 10 | średnia | EEUGBuildRepair (budowa) |
| 12 | Walka i obrażenia | pociski, obszar, łucznicy, oblężenie, morale w walce | kod+weryfikacja | 11 | średnia | jednostka dystansowa z pociskiem |
| 13 | Śmierć i usuwanie | zwłoki jednostek, Spawn on death, efekty śmierci | kod | 12 | niska | zwłoki i Spawn on death |
| 14 | Budynki i budowanie | cały proces budowy (fundament, postęp, koszt) – brak pomiaru | wiedza+kod+weryfikacja | 11, 17 | wysoka | pierwsza budowa rozkazem obywatela zmierzona w grze |
| 15 | Jednostki cywilne | zbieranie, budowa, naprawa, garnizon | wiedza | 14, 16 | wysoka | obywatel z rozkazem zbierania |
| 16 | Zbieranie surowców | całość | wiedza | 15, 17 | wysoka | analiza EEUGGather |
| 17 | Ekonomia (zasoby, populacja) | całość | wiedza | 16 | średnia | stan zasobów gracza w pamięci |
| 18 | Produkcja jednostek | kolejki budynków, punkty zbiórki | wiedza | 14, 17 | średnia | EEMBuildUnit – analiza |
| 19 | Technologie, epoki, ulepszenia | drzewo technologii, epoki, pozostałe atrybuty cywilizacji | wiedza+kod | 2, 17 | wysoka | odczyt poziomów atrybutów cywilizacji z SCN |
| 20 | AI gracza komputerowego | całość; losowania RNG AI [N] | wiedza | 32 | bardzo wysoka | funkcja planująca AI i jej losowania |
| 21 | Dyplomacja i relacje | zmiana relacji, edykty, głosowanie | wiedza | – | średnia | pomiar zmiany relacji |
| 22 | Widoczność i fog of war | mapa widoczności, odkrywanie, ukrycie | wiedza | 3 | średnia | odczyt mapy widoczności EEMap |
| 23 | Świat, zwierzęta, obiekty neutralne | zachowanie zwierząt, stada, polowanie | wiedza | 32 | średnia | stado w odtworzeniu |
| 24 | Transport lądowy i morski | całość | wiedza | 7, 11 | wysoka | EEUGLoadTransport |
| 25 | Lotnictwo | całość | wiedza | 7 | wysoka | EEUCAir* – rozpoznanie |
| 26 | Animacja jednostek | zgodność czasów animacji z grą | weryfikacja | 13 | średnia | pomiar klatek animacji ataku |
| 27 | Efekty graficzne i dźwięk | efekty EEEffect, dźwięki, muzyka | wiedza+kod | 26 | średnia | efekty śmierci |
| 28 | Sterowanie gracza i interfejs | panele, przyciski, budowa z interfejsu, skróty | kod | 11 | wysoka | przycisk budowy w interfejsie |
| 29 | Warunki zwycięstwa, scenariusze, wyzwalacze | wyzwalacze, kampanie, cele scenariusza | wiedza | 2 | wysoka | EEVictoryCondition – rozpoznanie |
| 30 | Multiplayer i synchronizacja | całość | wiedza | 32 | bardzo wysoka | – |
| 31 | Zapis i wczytanie stanu gry | całość | wiedza | wszystkie | wysoka | format zapisu gry |
| 32 | Losowość i deterministyczna symulacja | losowania AI i świata, zapadanie budynków | wiedza | 20, 23 | wysoka | pełny takt RNG bez stanu z nagrania |
| 34 | Efekty obszarowe i morale | leczenie z budynków, bohaterowie strategów | weryfikacja | 13 | średnia | pomiar morale przy domach |
| 35 | Bohaterowie i leczenie | zdolności bohaterów, okrzyk | kod | 34 | średnia | bohater strateg |
| 36 | Kalamity (prorok, kapłan) | całość | wiedza | 10, 12 | wysoka | pierwsza klątwa w pomiarze |
| 37 | Grupy i szyk (formacje) | całość w Core (status niewdrożony) | kod | 7 | średnia | ruch grupy w Core |
| 38 | Edytor scenariuszy | całość (klasy EESE*) | wiedza | 2 | średnia | – |

Terminu ukończenia całego silnika nie podajemy: tempo etapów dotyczy głównie ruchu i walki, a dla gospodarki, AI i
interfejsu nie ma jeszcze danych o tempie. Realistyczna kolejność: (1) domknięcie ruchu i kolizji (duże jednostki,
grupy), (2) obywatel: budowa i zbieranie, (3) ekonomia i produkcja, (4) technologie i epoki, (5) AI komputera.
Bez (2)–(4) nie da się uruchomić pełnej rozgrywki Empire Earth.

## 6. Jak aktualizować

1. Zmieniaj tylko oceny podsystemów, których dotyczył etap, i dopisz uzasadnienie w § 7 (co, dlaczego, dowód).
2. Nowy podsystem dopisz na końcu katalogu (nowy numer), nie zmieniaj numeracji.
3. Jeśli podsystem okazał się większy, obniż ocenę i zapisz powód.
4. Przelicz § 4 skryptem albo ręcznie z tabeli § 3; wskaźniki obiektywne odśwież narzędziami (`rtti_titan.py lista`,
   zliczenie adresów w `docs/titan`).
5. Raport etapu zawiera rozdział „Postęp rekonstrukcji Titan – ile zostało do końca?” (zasada w `CLAUDE.md`).

## 7. Historia ocen

**Etap 49 (pierwsza wersja, stan wyjściowy).** Oceny ustalone na podstawie dokumentacji etapów 14–49 i nagrań MCP.
Zmiany w samym etapie 49 (wliczone w tabelę):
- 8 Kolizje: A 3 → 4 – budynki z +0x2D8 na listach kontaktów [P: 648, 652], gałąź omijania przeładowującego
  sojusznika w 0x549179 [P: 649 dom 3v1]; B/C 3 – duże jednostki nadal [H].
- 7 Fizyka ruchu: C 4 – prorok 648 do końca (3585/3585).
- 19 Technologie i ulepszenia: 0 → 1 (A, B, C) – premia prędkości cywilizacji (0x627078, SetSpeed) [W + P].
- 12 Walka: C 3 – dom 3v1 i koszary 3v1 zgodne co takt do śmierci budynku.
